enum LicenseState {
  activationRequired,
  trial,
  active,
  gracePeriod,
  expired,
  suspended,
  revoked,
  deactivated,
  invalid,
}

class LicenseStatus {
  const LicenseStatus({
    required this.state,
    required this.plan,
    required this.message,
    required this.isRestricted,
    this.expiresAt,
    this.customer,
    this.businessName,
  });

  final LicenseState state;
  final String plan;
  final String message;
  final bool isRestricted;
  final DateTime? expiresAt;
  final String? customer;
  final String? businessName;

  bool get isPaidLicense =>
      state == LicenseState.active || state == LicenseState.gracePeriod;

  bool get canStartTrial => state == LicenseState.activationRequired;

  bool get canActivate => !isPaidLicense;

  String get displayLabel => switch (state) {
    LicenseState.activationRequired => 'Activation required',
    LicenseState.trial => 'Trial',
    LicenseState.active => 'Licensed',
    LicenseState.gracePeriod => 'Grace period',
    LicenseState.expired => 'Expired',
    LicenseState.suspended => 'Suspended',
    LicenseState.revoked => 'Revoked',
    LicenseState.deactivated => 'Deactivated',
    LicenseState.invalid => 'Invalid licence',
  };
}
