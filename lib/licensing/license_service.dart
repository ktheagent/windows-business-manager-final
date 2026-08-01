import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'device_identity_service.dart';
import 'license_api_client.dart';
import 'license_model.dart';
import 'license_status.dart';
import 'license_storage.dart';

class LicenseService {
  LicenseService({
    LicenseStorage? storage,
    LicenseApiClient? apiClient,
    DeviceIdentityService? deviceIdentityService,
    PackageInfo? packageInfo,
    String? appVersion,
    DateTime Function()? now,
  }) : _storage = storage ?? LicenseStorage(),
       _apiClient = apiClient ?? LicenseApiClient(),
       _deviceIdentityService =
           deviceIdentityService ?? DeviceIdentityService(),
       _packageInfo = packageInfo,
       _appVersion = appVersion,
       _now = now ?? DateTime.now;

  final LicenseStorage _storage;
  final LicenseApiClient _apiClient;
  final DeviceIdentityService _deviceIdentityService;
  final PackageInfo? _packageInfo;
  final String? _appVersion;
  final DateTime Function() _now;

  LicenseModel? _cachedLicense;

  LicenseModel? get currentLicense => _cachedLicense;

  Future<LicenseStatus> initialize({
    required String businessName,
    bool validateOnline = true,
  }) async {
    await _deviceIdentityService.getDeviceIdentifier();
    await _loadCachedLicense();

    if (_cachedLicense == null) {
      return const LicenseStatus(
        state: LicenseState.activationRequired,
        plan: 'none',
        message: 'Activate a licence or start your one-time 14-day trial.',
        isRestricted: false,
      );
    }

    if (_cachedLicense!.status == 'trial') {
      if (validateOnline) {
        try {
          await registerTrial(businessName: businessName);
        } catch (_) {
          // The saved server-issued trial remains valid offline until its
          // original expiry date. A retry never creates a new trial period.
        }
      }
      return _statusFor(_cachedLicense!);
    }

    if (validateOnline && _cachedLicense!.token.isNotEmpty) {
      try {
        await validateLicense();
      } on LicenseApiException catch (error) {
        final remoteStatus = error.remoteStatus;
        if (remoteStatus != null && remoteStatus.isNotEmpty) {
          final current = _cachedLicense!;
          final updated = current.copyWith(
            status: remoteStatus,
            message: error.message,
          );
          _cachedLicense = updated;
          await _storage.saveCachedLicense(jsonEncode(updated.toJson()));
          return _statusFor(updated);
        }
        return _statusFor(_cachedLicense!, offline: true);
      } catch (_) {
        return _statusFor(_cachedLicense!, offline: true);
      }
    }

    return _statusFor(_cachedLicense!);
  }

  Future<LicenseModel> registerTrial({required String businessName}) async {
    final appVersion = await _resolveAppVersion();
    final deviceId = await _deviceIdentityService.getDeviceIdentifier();
    final response = await _apiClient.registerTrial(
      deviceIdentifier: deviceId,
      appVersion: appVersion,
      platform: Platform.operatingSystem,
      businessName: businessName,
    );
    final model = LicenseModel.fromJson(response);
    if (model.status != 'trial' && model.status != 'expired') {
      throw const LicenseApiException(
        message: 'The trial server returned an invalid trial state.',
      );
    }
    await _save(model, response);
    return model;
  }

  Future<LicenseModel> activateLicense({
    required String licenseKey,
    required String businessName,
  }) async {
    final appVersion = await _resolveAppVersion();
    final deviceId = await _deviceIdentityService.getDeviceIdentifier();
    final response = await _apiClient.activate(
      licenseKey: licenseKey,
      deviceIdentifier: deviceId,
      appVersion: appVersion,
      platform: Platform.operatingSystem,
      businessName: businessName,
    );
    final model = LicenseModel.fromJson(response);
    if (model.status != 'active') {
      throw LicenseApiException(
        message: model.message.isNotEmpty
            ? model.message
            : 'The licence did not become active.',
        remoteStatus: model.status,
      );
    }
    await _save(model, response);
    return model;
  }

  Future<void> deactivateLicense() async {
    final license = _cachedLicense;
    if (license == null || license.token.isEmpty) {
      await _storage.clearCachedLicense();
      _cachedLicense = null;
      return;
    }
    await _apiClient.deactivate(token: license.token);
    await _storage.clearCachedLicense();
    _cachedLicense = null;
  }

  Future<LicenseModel> validateLicense() async {
    final license = _cachedLicense;
    if (license == null || license.token.isEmpty) {
      throw const LicenseApiException(
        message: 'No saved licence is available for validation.',
      );
    }
    final deviceId = await _deviceIdentityService.getDeviceIdentifier();
    final response = await _apiClient.validate(
      token: license.token,
      deviceIdentifier: deviceId,
    );
    final mergedResponse = <String, dynamic>{...license.toJson(), ...response};
    final model = LicenseModel.fromJson(mergedResponse);
    await _save(model, mergedResponse);
    return model;
  }

  Future<String> _resolveAppVersion() async {
    final override = _appVersion?.trim();
    if (override != null && override.isNotEmpty) return override;
    final info = _packageInfo ?? await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<void> _loadCachedLicense() async {
    final cachedJson = await _storage.loadCachedLicense();
    if (cachedJson == null || cachedJson.trim().isEmpty) {
      _cachedLicense = null;
      return;
    }

    try {
      final parsed = jsonDecode(cachedJson);
      if (parsed is! Map<String, dynamic>) {
        throw const FormatException('Invalid licence cache.');
      }
      _cachedLicense = LicenseModel.fromJson(parsed);
    } catch (_) {
      await _storage.clearCachedLicense();
      _cachedLicense = null;
    }
  }

  Future<void> _save(LicenseModel model, Map<String, dynamic> response) async {
    _cachedLicense = model;
    await _storage.saveCachedLicense(jsonEncode(response));
  }

  LicenseStatus _statusFor(LicenseModel license, {bool offline = false}) {
    final now = _now().toUtc();
    final status = license.status.toLowerCase();

    if (status == 'trial') {
      final active = !now.isAfter(license.expiryAt);
      return LicenseStatus(
        state: active ? LicenseState.trial : LicenseState.expired,
        plan: 'trial',
        message: active
            ? 'Your one-time trial is active until ${_date(license.expiryAt)}.'
            : 'Your one-time trial ended on ${_date(license.expiryAt)}.',
        isRestricted: !active,
        expiresAt: license.expiryAt,
        customer: license.customer,
        businessName: license.businessName,
      );
    }

    if (status == 'expired' && license.plan == 'trial') {
      return LicenseStatus(
        state: LicenseState.expired,
        plan: 'trial',
        message: 'Your one-time trial ended on ${_date(license.expiryAt)}.',
        isRestricted: true,
        expiresAt: license.expiryAt,
        customer: license.customer,
        businessName: license.businessName,
      );
    }

    if (status == 'active') {
      if (!now.isAfter(license.expiryAt)) {
        return LicenseStatus(
          state: LicenseState.active,
          plan: license.plan,
          message: offline
              ? 'Licence is active. Online validation will retry automatically.'
              : 'Licence is active.',
          isRestricted: false,
          expiresAt: license.expiryAt,
          customer: license.customer,
          businessName: license.businessName,
        );
      }
      if (!now.isAfter(license.offlineGraceDeadline)) {
        return LicenseStatus(
          state: LicenseState.gracePeriod,
          plan: license.plan,
          message:
              'The subscription is in its offline grace period until ${_date(license.offlineGraceDeadline)}.',
          isRestricted: false,
          expiresAt: license.offlineGraceDeadline,
          customer: license.customer,
          businessName: license.businessName,
        );
      }
      return LicenseStatus(
        state: LicenseState.expired,
        plan: license.plan,
        message: 'The licence expired on ${_date(license.expiryAt)}.',
        isRestricted: true,
        expiresAt: license.expiryAt,
        customer: license.customer,
        businessName: license.businessName,
      );
    }

    return _remoteFailureStatus(
      status,
      license.message.isNotEmpty
          ? license.message
          : 'The licence is not currently active.',
      license: license,
    );
  }

  LicenseStatus _remoteFailureStatus(
    String remoteStatus,
    String message, {
    LicenseModel? license,
  }) {
    final normalized = remoteStatus.toLowerCase();
    final state = switch (normalized) {
      'expired' => LicenseState.expired,
      'suspended' => LicenseState.suspended,
      'revoked' => LicenseState.revoked,
      'deactivated' => LicenseState.deactivated,
      _ => LicenseState.invalid,
    };
    final current = license ?? _cachedLicense;
    return LicenseStatus(
      state: state,
      plan: current?.plan ?? 'none',
      message: message,
      isRestricted: true,
      expiresAt: current?.expiryAt,
      customer: current?.customer,
      businessName: current?.businessName,
    );
  }

  static String _date(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
