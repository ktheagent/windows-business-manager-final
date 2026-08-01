# Windows packaging audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| WIN-01 | Exact Build 8 installer and portable names | COMPLETE | installer ISS; package_windows.ps1; windows-build.yml | source validator | workflow configured | Compilation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| WIN-02 | Full-source ZIP and SHA-256 artifact generation | COMPLETE | package_source.ps1; windows-build.yml | local source packaging planned | workflow configured | Workflow execution BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| WIN-03 | Executable/DLL/assets verification and smoke launches | COMPLETE | windows-build.yml verification/smoke steps | NOT RUN | workflow configured | Windows host BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
