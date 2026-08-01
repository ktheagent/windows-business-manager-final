class LicenseModel {
  const LicenseModel({
    required this.licenseId,
    required this.customer,
    required this.businessName,
    required this.plan,
    required this.status,
    required this.issuedAt,
    required this.expiryAt,
    required this.deviceLimit,
    required this.activatedDevice,
    required this.offlineGraceDeadline,
    required this.signature,
    required this.token,
    required this.message,
  });

  final String licenseId;
  final String customer;
  final String businessName;
  final String plan;
  final String status;
  final DateTime issuedAt;
  final DateTime expiryAt;
  final int deviceLimit;
  final String activatedDevice;
  final DateTime offlineGraceDeadline;
  final String signature;
  final String token;
  final String message;

  factory LicenseModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    final status = _string(json, const ['status'], fallback: 'invalid')
        .toLowerCase();
    final businessName = _string(
      json,
      const ['businessName', 'business_name'],
    );
    final customer = _string(
      json,
      const ['customer', 'customerName', 'customer_name'],
      fallback: businessName,
    );
    final expiryAt = _date(
      json,
      const [
        'expiryDate',
        'expiryAt',
        'expiry_at',
        'expiresAt',
        'expires_at',
      ],
      fallback: now,
    );

    return LicenseModel(
      licenseId: _string(
        json,
        const ['licenseId', 'license_id'],
        fallback: status == 'trial' ? 'trial' : '',
      ),
      customer: customer,
      businessName: businessName.isNotEmpty ? businessName : customer,
      plan: _string(json, const ['plan'], fallback: 'trial').toLowerCase(),
      status: status,
      issuedAt: _date(
        json,
        const ['issuedDate', 'issuedAt', 'issued_at', 'startsAt', 'starts_at'],
        fallback: now,
      ),
      expiryAt: expiryAt,
      deviceLimit:
          int.tryParse(
            _string(json, const ['deviceLimit', 'device_limit'], fallback: '1'),
          ) ??
          1,
      activatedDevice: _string(
        json,
        const [
          'activatedDevice',
          'deviceIdentifier',
          'device_identifier',
        ],
      ),
      offlineGraceDeadline: _date(
        json,
        const ['offlineGraceDeadline', 'offline_grace_deadline'],
        fallback: expiryAt,
      ),
      signature: _string(json, const ['signature']),
      token: _string(json, const ['token']),
      message: _string(json, const ['message']),
    );
  }


  LicenseModel copyWith({
    String? licenseId,
    String? customer,
    String? businessName,
    String? plan,
    String? status,
    DateTime? issuedAt,
    DateTime? expiryAt,
    int? deviceLimit,
    String? activatedDevice,
    DateTime? offlineGraceDeadline,
    String? signature,
    String? token,
    String? message,
  }) {
    return LicenseModel(
      licenseId: licenseId ?? this.licenseId,
      customer: customer ?? this.customer,
      businessName: businessName ?? this.businessName,
      plan: plan ?? this.plan,
      status: status ?? this.status,
      issuedAt: issuedAt ?? this.issuedAt,
      expiryAt: expiryAt ?? this.expiryAt,
      deviceLimit: deviceLimit ?? this.deviceLimit,
      activatedDevice: activatedDevice ?? this.activatedDevice,
      offlineGraceDeadline:
          offlineGraceDeadline ?? this.offlineGraceDeadline,
      signature: signature ?? this.signature,
      token: token ?? this.token,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'licenseId': licenseId,
      'customer': customer,
      'businessName': businessName,
      'plan': plan,
      'status': status,
      'startsAt': issuedAt.toUtc().toIso8601String(),
      'expiresAt': expiryAt.toUtc().toIso8601String(),
      'deviceLimit': deviceLimit,
      'deviceIdentifier': activatedDevice,
      'offlineGraceDeadline': offlineGraceDeadline.toUtc().toIso8601String(),
      'signature': signature,
      'token': token,
      'message': message,
    };
  }

  static String _string(
    Map<String, dynamic> json,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return fallback;
  }

  static DateTime _date(
    Map<String, dynamic> json,
    List<String> keys, {
    required DateTime fallback,
  }) {
    for (final key in keys) {
      final value = json[key]?.toString();
      if (value == null || value.trim().isEmpty) continue;
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toUtc();
    }
    return fallback.toUtc();
  }
}
