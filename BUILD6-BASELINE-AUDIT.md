# Build 6 baseline audit

Baseline source imported at `365685c674464e5f6426b4ce38232b144b90f5f0`. The audit protects existing licensing, POS, printing, barcode, data and branding behavior.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| B6-LIC-01 | Trial starts only once and repeated requests do not extend expiry | COMPLETE | lib/licensing/license_service.dart | test/license_service_test.dart: never extends expiry | Configured in windows-build.yml | Runtime execution BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B6-LIC-02 | Paid activation replaces trial state and hides activation entry | COMPLETE | lib/licensing/license_controller.dart; lib/screens/license_screen.dart | test/license_service_test.dart; test/license_screen_test.dart | flutter test step | Runtime execution BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B6-LIC-03 | Suspended and revoked licences persist offline | COMPLETE | lib/licensing/license_service.dart | test/license_service_test.dart | flutter test step | Runtime execution BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B6-LIC-04 | Stable Windows device fingerprint and activated-user compatibility | COMPLETE | lib/licensing/device_fingerprint_service.dart | test/license_service_test.dart | flutter test step | Physical device migration test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B6-DATA-01 | Existing products, contacts, sales, expenses and settings preserved | COMPLETE | lib/services/database_service.dart additive migrations | tool/local_release_validation.py migration simulation | source validation step | Windows upgrade installation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B6-POS-01 | POS, receipt/PDF printing, saved-sale reprint and barcode search preserved | COMPLETE | lib/screens/pos_screen.dart; lib/services/report_service.dart | test/build5_features_test.dart; test/database_service_test.dart | flutter test and Windows build steps | Physical printer/scanner validation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
