# -*- coding: utf-8 -*-
from pathlib import Path

path = Path("lib/commercial/screens/commercial_suite_screen.dart")
text = path.read_text(encoding="utf-8")

start = text.find("class _ReportsPanel extends StatefulWidget {")
end = text.find("class _ActualDataBarChart extends StatelessWidget {", start)
if start < 0 or end < 0:
    raise SystemExit("Reports panel boundaries not found")

section = text[start:end]
required = {
    "branch selection": "selectedBranchId",
    "branch access control": "mayChooseBranch",
    "owner consolidated reporting": "mayConsolidate",
    "staff performance": "Staff performance",
    "previous-period comparison": "_previousStaffFilter",
    "most improved summary": "Most improved",
    "profit permission filtering": "canSeeProfit",
    "export permission": "reportsExport",
}
missing = [label for label, token in required.items() if token not in section]
if missing:
    raise SystemExit("Reporting upgrade incomplete: " + ", ".join(missing))

print("Reporting management upgrade already present; verification passed.")
