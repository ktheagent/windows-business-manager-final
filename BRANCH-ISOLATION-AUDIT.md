# Branch isolation audit

Source audit generated from the local Build 8 full-source working tree on 2026-07-31.

| Requirement ID | Description | Status | Source evidence | Test evidence | Workflow evidence | Defect / limitation | Corrective commit |
|---|---|---|---|---|---|---|---|
| BR-01 | Branch inventory, documents, contacts, staff, cash and reports scoped | COMPLETE | database_service.dart/commercial_service.dart | build8_regression_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| BR-02 | User branch access and direct service checks | COMPLETE | user_branch_access; canAccessBranch; service filters | commercial_service_test.dart | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |
| BR-03 | Consolidated reporting restricted to owner/authorized role | COMPLETE | advanced_report_service.dart; businessHealth | branch-isolation regression source | flutter test | NOT RUN locally | d204898e309a1a361772c05cbba5d50dc6c8831a |

## Notes

Flutter/Dart and Windows toolchains are unavailable on the local Linux host; executable validation is BLOCKED.
