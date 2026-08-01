# Build 7 completion audit

Build 7 professional-controls source checkpoint: `d204898e309a1a361772c05cbba5d50dc6c8831a`.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| B7-STAFF | Staff creation, editing, disabling/reactivation, PIN reset/change, lock/unlock, branch assignment and sessions | COMPLETE | lib/commercial/services/commercial_service.dart; lib/commercial/screens/commercial_suite_screen.dart; lib/screens/shell_screen.dart | test/commercial_service_test.dart; test/build8_regression_test.dart | flutter test step | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-PERM | Owner, manager, cashier, accountant and stock-officer permission enforcement | COMPLETE | lib/commercial/models/commercial_models.dart; CommercialService._require; ShellScreen navigation | test/commercial_service_test.dart | analyze/test steps | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-AUDIT | Immutable audit trail with user, branch, action, values, reason, success and device | COMPLETE | database_service.dart audit_logs and immutable triggers; commercial_service.dart | build8_regression_test.dart; local SQLite trigger test | source validator and flutter test | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-RETURN | Full/partial return, quantity limit, refund method, stock/debt/cash correction | COMPLETE | CommercialService.createReturn | commercial_service_test.dart; database_service_test.dart | flutter test | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-CASH | Registers, open/close shift, cash movements, expected/actual/variance and approval | COMPLETE | CommercialService cash register/session methods; Commercial Suite cash panel | commercial_service_test.dart | flutter test | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-PROFIT | Revenue, COGS, gross/net profit and filtered export reporting | COMPLETE | advanced_report_service.dart | build8_regression_test.dart branch isolation | flutter analyze/test | Runtime chart/export test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| B7-ALERT | Low/out/overstock, expiry, slow/dead stock and purchasing suggestions | COMPLETE | advanced_report_service.dart; CommercialService.lowStockSuggestions/businessHealth | commercial_service_test.dart source | flutter test | Runtime data-volume validation BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
