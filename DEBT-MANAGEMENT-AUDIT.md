# Debt management audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| DEBT-01 | Customer debt, limits, payments and ageing | COMPLETE | commercial_service.dart; advanced_report_service.dart | commercial_service_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DEBT-02 | Supplier balance, receipts and payments | COMPLETE | commercial_service.dart; advanced_report_service.dart | commercial_service_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| DEBT-03 | Branch-scoped debt ledgers | COMPLETE | branch_id filters in service queries | build8 regression branch isolation | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
