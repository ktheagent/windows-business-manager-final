# Build 8 completion audit

Premium commercial source implementation is present on `feature/build8-commercial-suite-complete`. Runtime release approval is withheld.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| B8-BRANCH | Multi-branch records, inventory, users, documents, cash and permission-based visibility | COMPLETE | database_service.dart; CommercialService branch-scoped queries | build8_regression_test.dart branch isolation | flutter test | Runtime test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-DOC | Multi-line documents with products/services, discounts, tax, dates, draft lifecycle and delivery actions | COMPLETE | document_editor_dialog.dart; commercial_service.dart; commercial_document_service.dart | build8_regression_test.dart document calculations/lifecycle | flutter test | Printer/email live validation BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-TRANSFER | Draft/approve/dispatch/partial receive/discrepancy/complete/reject/cancel/reverse | COMPLETE | stock_transfer_dialog.dart; commercial_service.dart | build8_regression_test.dart partial transfer/reversal | flutter test | Runtime test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-BACKUP | Encrypted backup, schedules, retention, preview, verification, rollback/recovery and WebDAV | COMPLETE | backup_service.dart; secure_config_service.dart | source validator | flutter test and Windows workflow | Live WebDAV and restore test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-REMOTE | Read-only token-protected branch-scoped dashboard with access logs | COMPLETE | remote_dashboard_service.dart | source validator | flutter test | Live network/security test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-NOTIFY | SMTP, WhatsApp Web and WhatsApp Business API configuration/delivery logging | COMPLETE | notification_service.dart; secure_config_service.dart | source validator | flutter test | Credentials/provider tests BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-RECUR | Recurring expenses with month-end handling and duplicate-run protection | COMPLETE | commercial_service.dart recurring methods | build8_regression_test.dart | flutter test | Runtime test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-IMPORT | CSV/XLSX products, contacts and opening-stock import with rollback/history | COMPLETE | import_service.dart; commercial_suite_screen.dart | source validator | flutter test | Large-file and mapping UI tests BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-UPDATE | HTTPS manifest/download, SHA-256, Ed25519 signatures, resume/retry/cancel and safe launch | COMPLETE | update_service.dart; release_signing_key.dart; tool/sign_update_release.py | source validator | flutter test/Windows smoke tests | Live signed installer test BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-HEALTH | Actual-data revenue/profit/debt/stock/refund/variance insights and guarded recommendations | COMPLETE | CommercialService.businessHealth; advanced_report_service.dart | source validator | flutter test | Runtime dataset validation BLOCKED | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |
| B8-WIN | Windows compilation, installer, portable package and source package | BLOCKED | .github/workflows/windows-build.yml | NOT RUN | Workflow configured | No Windows/Flutter toolchain locally | 60cc04c8ec220902cc5223aaf6b6cc165f8872d3 |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
