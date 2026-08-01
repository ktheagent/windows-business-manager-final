# Integrations audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| INT-01 | SMTP TLS/test/send/logging and secure password | COMPLETE | notification_service.dart; secure_config_service.dart | source inspection | flutter test | Live credentials BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| INT-02 | WhatsApp Web/API/test/retry/status and secure token | COMPLETE | notification_service.dart; secure_config_service.dart | source inspection | flutter test | Provider validation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| INT-03 | WebDAV test/upload and secure password | COMPLETE | backup_service.dart; secure_config_service.dart | source inspection | flutter test | Live server BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| INT-04 | Printer/barcode/update/remote configuration paths | COMPLETE | settings/commercial suite services | source inspection | Windows workflow | Hardware/network validation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
