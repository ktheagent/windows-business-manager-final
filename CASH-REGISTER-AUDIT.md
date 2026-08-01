# Cash register audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| CASH-01 | Register creation/activation and open shift requirement | COMPLETE | commercial_service.dart | commercial_service_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| CASH-02 | Cash in/out/expenses/refunds and expected cash | COMPLETE | cash_movements and cash session methods | source inspection | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| CASH-03 | Variance, manager approval, history and export source | COMPLETE | approveCashVariance; advanced reports | source validator | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
