# Update security audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| UPD-01 | HTTPS manifest/download with version/build/minimum/mandatory metadata | COMPLETE | update_service.dart | source validator | flutter test | Live HTTPS test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| UPD-02 | SHA-256 and Ed25519 manifest/file signatures | COMPLETE | update_service.dart; release_signing_key.dart | tool/sign_update_release.py source | flutter test | Runtime signature tests BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| UPD-03 | Private signing key excluded and signing process documented | COMPLETE | docs/UPDATE_SIGNING.md; source private-key scan | validate_source_checkpoint.py | source validator | Private key distributed separately | d204898e309a1a361772c05cbba5d50dc6c8831a |
| UPD-04 | Resume/retry/cancel/size checks and safe Windows launch | COMPLETE | update_service.dart | source inspection | Windows workflow | Runtime installer launch BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
