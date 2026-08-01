# Barcode end-to-end audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| BAR-01 | SKU/barcode uniqueness and scanner search | COMPLETE | database_service.dart unique indexes; pos_screen.dart | build5_features_test.dart | flutter test | Physical HID scanner BLOCKED | 365685c674464e5f6426b4ce38232b144b90f5f0 |
| BAR-02 | Code 128/EAN/UPC/internal labels, A4/thermal PDF and quantities | COMPLETE | commercial_document_service.dart; products_screen.dart | source inspection | Windows PDF/printer workflow | Physical printer BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
