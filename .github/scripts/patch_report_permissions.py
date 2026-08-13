# -*- coding: utf-8 -*-
from pathlib import Path

path = Path("lib/commercial/services/advanced_report_service.dart")
text = path.read_text(encoding="utf-8")

required = {
    "kind-aware authorization": "_authorize(actor, filter, kind);",
    "profit-sensitive guard": "profit-sensitive reports",
    "profit by user protection": "CommercialReportKind.profitByUser",
    "branch access guard": "selected branch is outside your access scope",
}
missing = [label for label, token in required.items() if token not in text]
if missing:
    raise SystemExit("Report permission hardening incomplete: " + ", ".join(missing))

print("Report permission hardening already present; verification passed.")
