# Database migration audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| DB-01 | Schema version is 8 with additive legacy and commercial columns | COMPLETE | database_service.dart schemaVersion/_upgradeLegacyColumns/_ensureCommercialColumns | tool/local_release_validation.py: 50 tables | source validator | Runtime Windows upgrade BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DB-02 | Representative Build 5/6 records survive migration | COMPLETE | additive schema operations | local migration simulation preserved six record groups | source validator | Actual customer DB test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DB-03 | Foreign keys and SQLite integrity are valid after simulation | COMPLETE | database schema | PRAGMA integrity_check=ok; foreign_key_check=0 | source validator | Runtime DB check BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DB-04 | Pre-migration safety backup and rollback | INCOMPLETE | BackupService restore safety exists | NOT RUN | MISSING | Automatic pre-onUpgrade file backup is not independently proven | MISSING |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
