import 'package:airmonlink_business_manager/licensing/license_controller.dart';
import 'package:airmonlink_business_manager/licensing/license_model.dart';
import 'package:airmonlink_business_manager/licensing/license_service.dart';
import 'package:airmonlink_business_manager/licensing/license_status.dart';
import 'package:airmonlink_business_manager/screens/license_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLicenseService extends LicenseService {
  FakeLicenseService({required this.fakeStatus, this.fakeLicense});

  LicenseStatus fakeStatus;
  LicenseModel? fakeLicense;

  @override
  LicenseModel? get currentLicense => fakeLicense;

  @override
  Future<LicenseStatus> initialize({
    required String businessName,
    bool validateOnline = true,
  }) async => fakeStatus;

  @override
  Future<LicenseModel> activateLicense({
    required String licenseKey,
    required String businessName,
  }) async {
    fakeLicense = _activeLicense(businessName);
    fakeStatus = _activeStatus(businessName);
    return fakeLicense!;
  }

  @override
  Future<LicenseModel> registerTrial({required String businessName}) async {
    fakeLicense = _trialLicense(businessName);
    fakeStatus = _trialStatus(businessName);
    return fakeLicense!;
  }

  @override
  Future<void> deactivateLicense() async {
    fakeLicense = null;
    fakeStatus = const LicenseStatus(
      state: LicenseState.activationRequired,
      plan: 'none',
      message: 'Activate a licence or start your one-time 14-day trial.',
      isRestricted: false,
    );
  }
}

LicenseModel _activeLicense(String businessName) => LicenseModel(
  licenseId: '101',
  customer: 'Test Customer',
  businessName: businessName,
  plan: 'lifetime',
  status: 'active',
  issuedAt: DateTime.utc(2026, 7, 31),
  expiryAt: DateTime.utc(2099, 12, 31),
  deviceLimit: 1,
  activatedDevice: 'TEST-DEVICE',
  offlineGraceDeadline: DateTime.utc(2100, 1, 7),
  signature: 'signature',
  token: 'token',
  message: 'Licence is active.',
);

LicenseModel _trialLicense(String businessName) => LicenseModel(
  licenseId: 'trial',
  customer: businessName,
  businessName: businessName,
  plan: 'trial',
  status: 'trial',
  issuedAt: DateTime.utc(2026, 7, 31),
  expiryAt: DateTime.utc(2026, 8, 14),
  deviceLimit: 0,
  activatedDevice: 'TEST-DEVICE',
  offlineGraceDeadline: DateTime.utc(2026, 8, 14),
  signature: 'signature',
  token: 'trial-token',
  message: 'Trial is active.',
);

LicenseStatus _activeStatus(String businessName) => LicenseStatus(
  state: LicenseState.active,
  plan: 'lifetime',
  message: 'Licence is active.',
  isRestricted: false,
  expiresAt: DateTime.utc(2099, 12, 31),
  customer: 'Test Customer',
  businessName: businessName,
);

LicenseStatus _trialStatus(String businessName) => LicenseStatus(
  state: LicenseState.trial,
  plan: 'trial',
  message: 'Your one-time trial is active until 2026-08-14.',
  isRestricted: false,
  expiresAt: DateTime.utc(2026, 8, 14),
  customer: businessName,
  businessName: businessName,
);

Future<LicenseController> _controller(FakeLicenseService service) async {
  final controller = LicenseController(service: service);
  await controller.initialize(businessName: 'Test Business');
  return controller;
}

void main() {
  testWidgets('active licence hides key inputs and trial action', (tester) async {
    final service = FakeLicenseService(
      fakeStatus: _activeStatus('Test Business'),
      fakeLicense: _activeLicense('Test Business'),
    );
    final controller = await _controller(service);

    await tester.pumpWidget(
      MaterialApp(home: LicenseScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('Licensed'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Change licence'), findsOneWidget);
    expect(find.text('Deactivate licence'), findsOneWidget);
    expect(find.text('Start one-time 14-day trial'), findsNothing);
    expect(find.textContaining('continue with the 14-day trial'), findsNothing);
  });

  testWidgets('trial state cannot start or extend another trial', (tester) async {
    final service = FakeLicenseService(
      fakeStatus: _trialStatus('Test Business'),
      fakeLicense: _trialLicense('Test Business'),
    );
    final controller = await _controller(service);

    await tester.pumpWidget(
      MaterialApp(home: LicenseScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Start one-time 14-day trial'), findsNothing);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Activate licence'), findsOneWidget);
  });

  testWidgets('new installation offers one explicit trial action', (tester) async {
    final service = FakeLicenseService(
      fakeStatus: const LicenseStatus(
        state: LicenseState.activationRequired,
        plan: 'none',
        message: 'Activate a licence or start your one-time 14-day trial.',
        isRestricted: false,
      ),
    );
    final controller = await _controller(service);

    await tester.pumpWidget(
      MaterialApp(home: LicenseScreen(controller: controller)),
    );
    await tester.pump();

    expect(find.text('Activation required'), findsOneWidget);
    expect(find.text('Start one-time 14-day trial'), findsOneWidget);
  });

  testWidgets('change licence opens the activation form only on request', (
    tester,
  ) async {
    final service = FakeLicenseService(
      fakeStatus: _activeStatus('Test Business'),
      fakeLicense: _activeLicense('Test Business'),
    );
    final controller = await _controller(service);

    await tester.pumpWidget(
      MaterialApp(home: LicenseScreen(controller: controller)),
    );
    await tester.tap(find.text('Change licence'));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Replace the current licence'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
