import 'dart:convert';

import 'package:http/http.dart' as http;

class LicenseApiException implements Exception {
  const LicenseApiException({
    required this.message,
    this.code = 'license_api_error',
    this.statusCode,
    this.remoteStatus,
  });

  final String message;
  final String code;
  final int? statusCode;
  final String? remoteStatus;

  @override
  String toString() => message;
}

class LicenseApiClient {
  LicenseApiClient({
    http.Client? client,
    String? baseUrl,
    Duration timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? 'https://license.airmonlink.com/api/v1')
           .replaceFirst(RegExp(r'/+$'), ''),
       _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  Future<Map<String, dynamic>> registerTrial({
    required String deviceIdentifier,
    required String appVersion,
    required String platform,
    required String businessName,
  }) {
    return _post('/trial/register', {
      'deviceIdentifier': deviceIdentifier,
      'appVersion': appVersion,
      'platform': platform,
      'businessName': businessName,
    });
  }

  Future<Map<String, dynamic>> activate({
    required String licenseKey,
    required String deviceIdentifier,
    required String appVersion,
    required String platform,
    required String? businessName,
  }) {
    return _post('/activate', {
      'licenseKey': licenseKey,
      'deviceIdentifier': deviceIdentifier,
      'appVersion': appVersion,
      'platform': platform,
      'businessName': businessName,
    });
  }

  Future<Map<String, dynamic>> validate({
    required String token,
    required String deviceIdentifier,
  }) {
    return _post('/validate', {
      'token': token,
      'deviceIdentifier': deviceIdentifier,
    });
  }

  Future<void> deactivate({required String token}) async {
    await _post('/deactivate', {'token': token});
  }

  Future<List<dynamic>> plans() async {
    try {
      final response = await _get('/plans');
      final plans = response['plans'];
      return plans is List<dynamic> ? plans : const [];
    } on LicenseApiException {
      return const [];
    }
  }

  Future<Map<String, dynamic>> status() async {
    try {
      return await _get('/status');
    } on LicenseApiException {
      return const {'status': 'offline'};
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl$path'))
        .timeout(_timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      decoded = value;
    } catch (_) {
      throw LicenseApiException(
        message: 'The licence server returned an unreadable response.',
        statusCode: response.statusCode,
      );
    }

    final failed = response.statusCode >= 400 || decoded['success'] == false;
    if (failed) {
      final code = decoded['code']?.toString() ?? 'license_api_error';
      final status = decoded['status']?.toString() ?? _statusFromCode(code);
      throw LicenseApiException(
        message:
            decoded['message']?.toString() ??
            'The licence server rejected the request.',
        code: code,
        statusCode: response.statusCode,
        remoteStatus: status,
      );
    }

    return decoded;
  }

  static String? _statusFromCode(String code) {
    if (code.startsWith('license_')) {
      return code.substring('license_'.length);
    }
    if (code == 'activation_inactive') return 'deactivated';
    if (code == 'invalid_token' || code == 'device_mismatch') {
      return 'invalid';
    }
    return null;
  }
}
