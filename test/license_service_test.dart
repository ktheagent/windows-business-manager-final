import 'dart:convert';

import 'package:airmonlink_business_manager/licensing/device_identity_service.dart';
import 'package:airmonlink_business_manager/licensing/license_api_client.dart';
import 'package:airmonlink_business_manager/licensing/license_service.dart';
import 'package:airmonlink_business_manager/licensing/license_status.dart';
import 'package:airmonlink_business_manager/licensing/license_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryLicenseStorage extends LicenseStorage {
  String? value;

  @override
  Future<void> saveCachedLicense(String value) async {
    this.value = value;
  }

  @override
  Future<String?> loadCachedLicense() async => value;

  @override
  Future<void> clearCachedLicense() async {
    value = null;
  }
}

class FakeDeviceIdentityService extends DeviceIdentityService {
  @override
  Future<String> getDeviceIdentifier() async => 'TEST-DEVICE-001';
}

class MutableClock {
  MutableClock(this.value);

  DateTime value;

  DateTime call() => value;
}

class FakeLicenseApiClient extends LicenseApiClient {
  FakeLicenseApiClient({required this.trialStart, required this.trialExpiry});

  final DateTime trialStart;
  final DateTime trialExpiry;
  int trialCalls = 0;
  int activationCalls = 0;
  String? validationFailureStatus;

  @override
  Future<Map<String, dynamic>> registerTrial({
    required String deviceIdentifier,
    required String appVersion,
    required String platform,
    required String businessName,
  }) async {
    trialCalls += 1;
    return {
      'success': true,
      'token': 'trial-token-$trialCalls',
      'status': 'trial',
      'plan': 'trial',
      'startsAt': trialStart.toIso8601String(),
      'expiresAt': trialExpiry.toIso8601String(),
      'offlineGraceDeadline': trialExpiry.toIso8601String(),
      'deviceIdentifier': deviceIdentifier,
      'deviceLimit': 0,
      'businessName': businessName,
      'message': trialCalls == 1
          ? 'Your 14-day trial is active.'
          : 'Trial already registered on this device.',
    };
  }

  @override
  Future<Map<String, dynamic>> activate({
    required String licenseKey,
    required String deviceIdentifier,
    required String appVersion,
    required String platform,
    required String? businessName,
  }) async {
    activationCalls += 1;
    return {
      'success': true,
      'licenseId': 101,
      'token': 'paid-token',
      'status': 'active',
      'plan': 'lifetime',
      'startsAt': '2026-07-31T00:00:00Z',
      'expiresAt': '2099-12-31T23:59:59Z',
      'offlineGraceDeadline': '2100-01-07T23:59:59Z',
      'deviceIdentifier': deviceIdentifier,
      'deviceLimit': 1,
      'businessName': businessName,
      'message': 'Licence activated successfully.',
    };
  }

  @override
  Future<Map<String, dynamic>> validate({
    required String token,
    required String deviceIdentifier,
  }) async {
    final failure = validationFailureStatus;
    if (failure != null) {
      throw LicenseApiException(
        message: 'This licence is $failure.',
        code: 'license_$failure',
        statusCode: 403,
        remoteStatus: failure,
      );
    }
    return {
      'success': true,
      'licenseId': 101,
      'token': token,
      'status': 'active',
      'plan': 'lifetime',
      'startsAt': '2026-07-31T00:00:00Z',
      'expiresAt': '2099-12-31T23:59:59Z',
      'offlineGraceDeadline': '2100-01-07T23:59:59Z',
      'deviceIdentifier': deviceIdentifier,
      'deviceLimit': 1,
      'businessName': 'Airmonlink',
      'message': 'Licence is active.',
    };
  }
}

void main() {
  group('licence state machine', () {
    late MemoryLicenseStorage storage;
    late MutableClock clock;
    late FakeLicenseApiClient api;
    late LicenseService service;

    setUp(() {
      storage = MemoryLicenseStorage();
      clock = MutableClock(DateTime.utc(2026, 7, 31, 12));
      api = FakeLicenseApiClient(
        trialStart: DateTime.utc(2026, 7, 31, 12),
        trialExpiry: DateTime.utc(2026, 8, 14, 12),
      );
      service = LicenseService(
        storage: storage,
        apiClient: api,
        deviceIdentityService: FakeDeviceIdentityService(),
        appVersion: '1.1.1',
        now: clock.call,
      );
    });

    test(
      'a new installation requires activation or an explicit trial',
      () async {
        final status = await service.initialize(
          businessName: 'Test Business',
          validateOnline: false,
        );

        expect(status.state, LicenseState.activationRequired);
        expect(status.canStartTrial, isTrue);
        expect(status.message, contains('one-time 14-day trial'));
      },
    );

    test('restarting or requesting trial again never extends expiry', () async {
      final first = await service.registerTrial(businessName: 'Test Business');
      clock.value = DateTime.utc(2026, 8, 5, 9);
      final second = await service.registerTrial(businessName: 'Test Business');

      expect(first.expiryAt, DateTime.utc(2026, 8, 14, 12));
      expect(second.expiryAt, first.expiryAt);
      expect(api.trialCalls, 2);

      final restarted = LicenseService(
        storage: storage,
        apiClient: api,
        deviceIdentityService: FakeDeviceIdentityService(),
        appVersion: '1.1.1',
        now: clock.call,
      );
      final status = await restarted.initialize(
        businessName: 'Test Business',
        validateOnline: false,
      );

      expect(status.state, LicenseState.trial);
      expect(status.expiresAt, first.expiryAt);
    });

    test('an expired trial remains expired after restart', () async {
      await service.registerTrial(businessName: 'Test Business');
      clock.value = DateTime.utc(2026, 8, 15, 12);

      final status = await service.initialize(
        businessName: 'Test Business',
        validateOnline: false,
      );

      expect(status.state, LicenseState.expired);
      expect(status.plan, 'trial');
      expect(status.isRestricted, isTrue);
      expect(status.canStartTrial, isFalse);
    });

    test('paid activation immediately replaces every trial state', () async {
      await service.registerTrial(businessName: 'Test Business');
      await service.activateLicense(
        licenseKey: 'ABM-TEST-TEST-TEST-TEST',
        businessName: 'Test Business',
      );

      final status = await service.initialize(
        businessName: 'Test Business',
        validateOnline: false,
      );

      expect(status.state, LicenseState.active);
      expect(status.displayLabel, 'Licensed');
      expect(status.plan, 'lifetime');
      expect(status.message.toLowerCase(), isNot(contains('trial')));
      expect(api.activationCalls, 1);
    });

    test(
      'revoked server state is persisted and remains revoked offline',
      () async {
        await service.activateLicense(
          licenseKey: 'ABM-TEST-TEST-TEST-TEST',
          businessName: 'Test Business',
        );
        api.validationFailureStatus = 'revoked';

        final onlineStatus = await service.initialize(
          businessName: 'Test Business',
        );
        expect(onlineStatus.state, LicenseState.revoked);
        expect(onlineStatus.isRestricted, isTrue);

        final offlineService = LicenseService(
          storage: storage,
          apiClient: api,
          deviceIdentityService: FakeDeviceIdentityService(),
          appVersion: '1.1.1',
          now: clock.call,
        );
        final offlineStatus = await offlineService.initialize(
          businessName: 'Test Business',
          validateOnline: false,
        );

        expect(offlineStatus.state, LicenseState.revoked);
        expect(offlineStatus.isRestricted, isTrue);
      },
    );

    test(
      'server response aliases preserve real paid expiry and business',
      () async {
        storage.value = jsonEncode({
          'success': true,
          'licenseId': 55,
          'token': 'saved-token',
          'status': 'active',
          'plan': 'annual',
          'startsAt': '2026-07-31T00:00:00Z',
          'expiresAt': '2027-07-31T00:00:00Z',
          'offlineGraceDeadline': '2027-08-07T00:00:00Z',
          'deviceIdentifier': 'TEST-DEVICE-001',
          'deviceLimit': 1,
          'businessName': 'Airmonlink',
        });

        final status = await service.initialize(
          businessName: 'Airmonlink',
          validateOnline: false,
        );

        expect(status.state, LicenseState.active);
        expect(status.expiresAt, DateTime.utc(2027, 7, 31));
        expect(status.businessName, 'Airmonlink');
        expect(service.currentLicense?.licenseId, '55');
        expect(service.currentLicense?.activatedDevice, 'TEST-DEVICE-001');
      },
    );
  });
}
