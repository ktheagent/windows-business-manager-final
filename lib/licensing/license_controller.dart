import 'package:flutter/foundation.dart';

import 'license_api_client.dart';
import 'license_model.dart';
import 'license_service.dart';
import 'license_status.dart';

class LicenseController extends ChangeNotifier {
  LicenseController({LicenseService? service})
    : _service = service ?? LicenseService();

  final LicenseService _service;

  LicenseStatus _status = const LicenseStatus(
    state: LicenseState.activationRequired,
    plan: 'none',
    message: 'Checking licence status...',
    isRestricted: false,
  );
  bool _isLoading = false;
  String? _errorMessage;
  String _businessName = 'Airmonlink Business Manager';

  LicenseStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  LicenseModel? get license => _service.currentLicense;

  Future<void> initialize({String? businessName}) async {
    if (businessName != null && businessName.trim().isNotEmpty) {
      _businessName = businessName.trim();
    }
    await _setLoading(() async {
      _status = await _service.initialize(businessName: _businessName);
    });
  }

  Future<bool> activate({
    required String licenseKey,
    required String businessName,
  }) async {
    final cleanKey = licenseKey.trim();
    final cleanBusinessName = businessName.trim();
    if (cleanKey.isEmpty) {
      _errorMessage = 'Enter a licence key to activate the app.';
      notifyListeners();
      return false;
    }
    if (cleanBusinessName.isEmpty) {
      _errorMessage = 'Enter the business or organisation name.';
      notifyListeners();
      return false;
    }

    _businessName = cleanBusinessName;
    return _setLoadingResult(() async {
      await _service.activateLicense(
        licenseKey: cleanKey,
        businessName: cleanBusinessName,
      );
      _status = await _service.initialize(
        businessName: cleanBusinessName,
        validateOnline: false,
      );
    });
  }

  Future<bool> startTrial({required String businessName}) async {
    final cleanBusinessName = businessName.trim().isEmpty
        ? _businessName
        : businessName.trim();
    _businessName = cleanBusinessName;
    return _setLoadingResult(() async {
      await _service.registerTrial(businessName: cleanBusinessName);
      _status = await _service.initialize(
        businessName: cleanBusinessName,
        validateOnline: false,
      );
    });
  }

  Future<bool> deactivate() async {
    return _setLoadingResult(() async {
      await _service.deactivateLicense();
      _status = await _service.initialize(
        businessName: _businessName,
        validateOnline: false,
      );
    });
  }

  Future<void> refresh() => initialize(businessName: _businessName);

  Future<void> _setLoading(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = _messageFor(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> _setLoadingResult(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      _errorMessage = _messageFor(error);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  static String _messageFor(Object error) {
    if (error is LicenseApiException) return error.message;
    return 'The licence operation could not be completed. Check your internet connection and try again.';
  }
}
