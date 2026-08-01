# Purchasing audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| PUR-01 | Purchase orders and multi-item partial receipts | COMPLETE | commercial_service.dart; goods_receipt_items schema | commercial_service_test.dart; build8_regression_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| PUR-02 | Supplier deposits/payments and liability after receipt | COMPLETE | commercial_service.dart | commercial_service_test.dart source | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| PUR-03 | Duplicate receipt reference protection | COMPLETE | idx_goods_receipt_ref | build8_regression_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
