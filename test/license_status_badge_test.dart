import 'package:airmonlink_business_manager/licensing/license_status.dart';
import 'package:airmonlink_business_manager/widgets/license_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('top badge uses the real licence state', (tester) async {
    const trial = LicenseStatus(
      state: LicenseState.trial,
      plan: 'trial',
      message: 'Trial is active.',
      isRestricted: false,
    );
    const active = LicenseStatus(
      state: LicenseState.active,
      plan: 'lifetime',
      message: 'Licence is active.',
      isRestricted: false,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              LicenseStatusBadge(status: trial, isLoading: false),
              LicenseStatusBadge(status: active, isLoading: false),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Licensed'), findsOneWidget);
  });
}
