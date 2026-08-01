# Licensing regression audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| LIC-01 | One-time trial and non-extension | COMPLETE | license_service.dart | license_service_test.dart | flutter test | NOT RUN locally | 365685c674464e5f6426b4ce38232b144b90f5f0 |
| LIC-02 | Paid activation immediately removes trial UI/state | COMPLETE | license_controller.dart; license_screen.dart | license_service_test.dart; license_screen_test.dart | flutter test | NOT RUN locally | 365685c674464e5f6426b4ce38232b144b90f5f0 |
| LIC-03 | Suspended/revoked remain offline | COMPLETE | license_service.dart | license_service_test.dart | flutter test | NOT RUN locally | 365685c674464e5f6426b4ce38232b144b90f5f0 |
| LIC-04 | Device fingerprint remains stable | COMPLETE | device_fingerprint_service.dart with device_info_plus-compatible API | license_service_test.dart source | flutter test | Physical Windows migration test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
