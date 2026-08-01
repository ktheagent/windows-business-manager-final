# Commercial transaction audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| TX-01 | Money calculations normalize to integer minor units | COMPLETE | lib/core/money.dart; commercial_models.dart | build8_regression_test.dart | flutter test | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| TX-02 | Unique transaction references prevent duplicate postings | COMPLETE | database_service.dart partial unique indexes | local SQLite duplicate-payment test; build8 regression purchase receipt test | source validator/flutter test | Runtime test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |
| TX-03 | Stock/money operations use SQLite transactions | COMPLETE | CommercialService transaction blocks | commercial_service_test.dart | flutter test | Runtime concurrency test BLOCKED | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
