# Document workflow audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| DOC-01 | Required document types and multi-line editor | COMPLETE | document_editor_dialog.dart | build8_regression_test.dart | flutter test | Runtime widget test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DOC-02 | Currency-safe discounts and inclusive/exclusive taxes | COMPLETE | money.dart; commercial_models.dart | build8_regression_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DOC-03 | Draft/edit/duplicate/cancel/status history | COMPLETE | commercial_service.dart | build8_regression_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DOC-04 | PDF, print, email and WhatsApp actions | COMPLETE | commercial_document_service.dart; notification_service.dart; suite screen | source validator | Windows workflow | External/printer validation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
