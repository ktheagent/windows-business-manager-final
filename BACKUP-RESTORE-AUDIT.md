# Backup and restore audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| BKP-01 | AES-GCM encrypted backup with PBKDF2 and post-write verification | COMPLETE | backup_service.dart | source validator | flutter test | Runtime cryptographic test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| BKP-02 | Schedules, retention, history and failure state | COMPLETE | backup_schedules schema; backup_service.dart | source validator | flutter test | Scheduler runtime BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| BKP-03 | Restore preview, safety copy, integrity verification and rollback/recovery | COMPLETE | inspectEncryptedBackup/restoreEncryptedBackup/recoverInterruptedRestore | source inspection | flutter test | Actual DB restore BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| BKP-04 | WebDAV HTTPS upload/test with secure password storage | COMPLETE | backup_service.dart; secure_config_service.dart | source inspection | flutter test | Live credentials BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
