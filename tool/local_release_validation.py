from __future__ import annotations

import datetime
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
RESULTS: list[dict[str, str]] = []


def record(name: str, ok: bool, evidence: str) -> None:
    RESULTS.append(
        {
            "requirement": name,
            "status": "COMPLETE" if ok else "INCOMPLETE",
            "evidence": evidence,
            "defect": "" if ok else evidence,
        }
    )


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


checkpoint_path = ROOT / "source-checkpoint-report.txt"
checkpoint = checkpoint_path.read_text(encoding="utf-8") if checkpoint_path.exists() else ""
checkpoint_ok = all(
    token in checkpoint
    for token in [
        '"complete": 22',
        '"incomplete": 0',
        '"blocked": 0',
        '"missing": 0',
        '"checks": 22',
    ]
)
record(
    "SOURCE-CHECKPOINT",
    checkpoint_ok,
    "22/22 source checkpoint checks complete" if checkpoint_ok else "source-checkpoint-report.txt is missing or not fully green",
)

pubspec = read("pubspec.yaml")
database = read("lib/services/database_service.dart")
commercial = read("lib/commercial/services/commercial_service.dart")
workflow = read(".github/workflows/windows-build.yml")

record(
    "BUILD9-IDENTITY",
    bool(re.search(r"(?m)^version:\s*1\.3\.0\+9\s*$", pubspec)),
    "pubspec version must be 1.3.0+9",
)

migration_tokens = [
    "schemaVersion = 8",
    "_upgradeLegacyColumns",
    "_ensureCommercialColumns",
    "PRAGMA",
    "audit_logs",
]
record(
    "MIGRATION-SOURCE",
    all(token in database for token in migration_tokens),
    f"{sum(token in database for token in migration_tokens)}/{len(migration_tokens)} migration tokens present",
)

premium_tokens = [
    "approveStockTransfer",
    "dispatchStockTransfer",
    "receiveStockTransfer",
    "reverseStockTransfer",
    "documentStatusHistory",
    "createStaff",
    "assignStaffBranches",
]
record(
    "PREMIUM-COMMEICIAL-SOURCE",
    all(token in commercial for token in premium_tokens),
    f"{sum(token in commercial for token in premium_tokens)}/{len(premium_tokens)} premium service tokens present",
)

workflow_tokens = [
    "flutter clean",
    "flutter pub get",
    "flutter analyze",
    "flutter test",
    "flutter build windows --release",
    "Build9-Setup.exe",
    "Build9-Portable.zip",
    "Build9-Full-Source.zip",
    "Build9-SHA256SUMS.txt",
    "Get-FileHash",
    "if-no-files-found: error",
]
record(
    "WINDOWS-WORKFLOW",
    all(token in workflow for token in workflow_tokens),
    f"{sum(token in workflow for token in workflow_tokens)}/{len(workflow_tokens)} release workflow tokens present",
)

flutter_path = shutil.which("flutter") or ""
dart_path = shutil.which("dart") or ""
record(
    "FLUTTER-RUNTIME",
    bool(flutter_path and dart_path),
    json.dumps({"flutter": flutter_path, "dart": dart_path}, sort_keys=True),
)
record(
    "WINDOWS-RUNTIME",
    sys.platform == "win32",
    f"host_platform={sys.platform}",
)

summary = {
    status.lower(): sum(item["status"] == status for item in RESULTS)
    for status in ["COMPLETE", "INCOMPLETE"]
}
summary["checks"] = len(RESULTS)
payload = {
    "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source_root": str(ROOT),
    "pubspec_sha256": hashlib.sha256(pubspec.encode("utf-8")).hexdigest(),
    "summary": summary,
    "results": RESULTS,
}
(ROOT / "BUILD9-LOCAL-VALIDATION.json").write_text(
    json.dumps(payload, indent=2) + "\n",
    encoding="utf-8",
)

for item in RESULTS:
    print(f"{item['status']} | {item['requirement']} | {item['evidence']}")
print("SUMMARY | " + json.dumps(summary, sort_keys=True))
sys.exit(1 if summary["incomplete"] else 0)
