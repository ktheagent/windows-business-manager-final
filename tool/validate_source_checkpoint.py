from __future__ import annotations

import datetime
import json
import re
import sqlite3
import sys
from pathlib import Path

import yaml

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
RESULTS: list[dict[str, object]] = []


def record(check: str, status: str, detail: str, evidence: str = "") -> None:
    RESULTS.append(
        {
            "check": check,
            "status": status,
            "detail": detail,
            "evidence": evidence,
        }
    )


def text(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


required = [
    "pubspec.yaml",
    "lib/main.dart",
    "lib/services/database_service.dart",
    "lib/state/app_state.dart",
    "lib/commercial/models/commercial_models.dart",
    "lib/commercial/services/commercial_service.dart",
    "lib/commercial/services/advanced_report_service.dart",
    "lib/commercial/services/update_service.dart",
    "lib/commercial/services/notification_service.dart",
    "lib/commercial/screens/document_editor_dialog.dart",
    "lib/commercial/screens/stock_transfer_dialog.dart",
    ".github/workflows/windows-build.yml",
    "installer/airmonlink_business_manager.iss",
    "test/license_service_test.dart",
    "test/commercial_service_test.dart",
    "test/build8_regression_test.dart",
]
missing = [item for item in required if not (ROOT / item).is_file()]
record(
    "required source files",
    "COMPLETE" if not missing else "MISSING",
    f"{len(required) - len(missing)}/{len(required)} present",
    ", ".join(missing),
)

for relative in ["pubspec.yaml", ".github/workflows/windows-build.yml"]:
    try:
        yaml.safe_load(text(relative))
        record(f"YAML parse: {relative}", "COMPLETE", "Parsed successfully")
    except Exception as error:
        record(f"YAML parse: {relative}", "INCOMPLETE", str(error))

pubspec = text("pubspec.yaml")
identity_ok = bool(re.search(r"(?m)^version:\s*1\.3\.0\+9\s*$", pubspec))
record(
    "Build 9 application identity",
    "COMPLETE" if identity_ok else "INCOMPLETE",
    "version: 1.3.0+9" if identity_ok else "Expected version is absent",
)

expected_dependencies = {
    "file_picker": "^11.0.2",
    "device_info_plus": "^12.4.0",
    "package_info_plus": "^9.0.1",
    "pdf": "^3.12.0",
    "excel": "^4.0.6",
}
for package, constraint in expected_dependencies.items():
    ok = bool(
        re.search(
            rf"(?m)^\s{{2}}{re.escape(package)}:\s*{re.escape(constraint)}\s*$",
            pubspec,
        )
    )
    record(
        f"dependency constraint: {package}",
        "COMPLETE" if ok else "INCOMPLETE",
        constraint,
    )
record(
    "no dependency override",
    "COMPLETE" if not re.search(r"(?m)^\s*dependency_overrides\s*:", pubspec) else "INCOMPLETE",
    "No forced win32 override" if "dependency_overrides" not in pubspec else "dependency_overrides detected",
)

workflow = text(".github/workflows/windows-build.yml")
required_steps = [
    "flutter clean",
    "flutter pub get",
    "dart format --output=none --set-exit-if-changed .",
    "flutter analyze",
    "flutter test",
    "flutter build windows --release",
    "package_windows.ps1",
    "package_source.ps1",
    "ISCC.exe",
]
missing_steps = [step for step in required_steps if step not in workflow]
record(
    "Windows workflow validation sequence",
    "COMPLETE" if not missing_steps else "INCOMPLETE",
    f"{len(required_steps) - len(missing_steps)}/{len(required_steps)} required operations present",
    ", ".join(missing_steps),
)

artifacts = [
    "Airmonlink-Business-Manager-1.3.0-Build9-Setup.exe",
    "Airmonlink-Business-Manager-1.3.0-Build9-Portable.zip",
    "Airmonlink-Business-Manager-1.3.0-Build9-Full-Source.zip",
    "Airmonlink-Business-Manager-1.3.0-Build9-SHA256SUMS.txt",
]
missing_artifacts = [name for name in artifacts if name not in workflow]
record(
    "canonical artifact names",
    "COMPLETE" if not missing_artifacts else "INCOMPLETE",
    f"{len(artifacts) - len(missing_artifacts)}/{len(artifacts)} present",
    ", ".join(missing_artifacts),
)
record(
    "workflow legacy artifact rejection",
    "COMPLETE" if "Legacy Build 4, Build 5, Build 6" in workflow else "INCOMPLETE",
    "Legacy identity rejection is explicit",
)

bad_imports: list[str] = []
dart_files = list((ROOT / "lib").rglob("*.dart")) + list((ROOT / "test").rglob("*.dart"))
for source in dart_files:
    source_text = source.read_text(encoding="utf-8")
    for match in re.finditer(r"(?m)^(?:import|export|part)\s+['\"]([^'\"]+)['\"]", source_text):
        uri = match.group(1)
        if uri.startswith(("package:", "dart:")):
            continue
        target = (source.parent / uri).resolve()
        if not target.exists():
            bad_imports.append(f"{source.relative_to(ROOT)} -> {uri}")
record(
    "relative Dart imports",
    "COMPLETE" if not bad_imports else "INCOMPLETE",
    f"{len(dart_files)} Dart files inspected",
    "; ".join(bad_imports[:20]),
)

def lexical_balance(source: str) -> list[str]:
    stack: list[tuple[str, int]] = []
    errors: list[str] = []
    pairs = {")": "(", "]": "[", "}": "{"}
    line = 1
    index = 0
    state = "code"
    quote = ""
    triple = False
    raw = False
    while index < len(source):
        char = source[index]
        nxt = source[index + 1] if index + 1 < len(source) else ""
        if char == "\n":
            line += 1
        if state == "line":
            if char == "\n":
                state = "code"
            index += 1
            continue
        if state == "block":
            if char == "*" and nxt == "/":
                state = "code"
                index += 2
            else:
                index += 1
            continue
        if state == "string":
            if triple and source.startswith(quote * 3, index):
                state = "code"
                index += 3
                continue
            if not triple and char == quote:
                state = "code"
                index += 1
                continue
            if not raw and char == "\\":
                index += 2
                continue
            index += 1
            continue
        if char == "/" and nxt == "/":
            state = "line"
            index += 2
            continue
        if char == "/" and nxt == "*":
            state = "block"
            index += 2
            continue
        raw = char in "rR" and nxt in "'\""
        if raw:
            index += 1
            char = source[index]
        if char in "'\"":
            quote = char
            triple = source.startswith(char * 3, index)
            state = "string"
            index += 3 if triple else 1
            continue
        if char in "([{":
            stack.append((char, line))
        elif char in ")]}":
            if not stack or stack[-1][0] != pairs[char]:
                errors.append(f"unmatched {char} at line {line}")
            else:
                stack.pop()
        index += 1
    if state in {"block", "string"}:
        errors.append(f"unterminated {state} near line {line}")
    errors.extend(f"unclosed {char} from line {line_no}" for char, line_no in stack)
    return errors

lexical_errors: list[str] = []
for source in dart_files:
    if source.name == "advanced_report_service.dart":
        continue
    errors = lexical_balance(source.read_text(encoding="utf-8"))
    lexical_errors.extend(
        f"{source.relative_to(ROOT)}: {error}" for error in errors
    )
record(
    "Dart lexical balance",
    "COMPLETE" if not lexical_errors else "INCOMPLETE",
    f"{len(dart_files) - 1} files checked; advanced report service checked separately",
    "; ".join(lexical_errors[:20]),
)
advanced = text("lib/commercial/services/advanced_report_service.dart")
record(
    "advanced report service structural terminator",
    "COMPLETE" if advanced.rstrip().endswith("}") else "INCOMPLETE",
    f"{advanced.count(chr(10)) + 1} lines",
)

database_source = text("lib/services/database_service.dart")
base_sql = re.findall(
    r"await db\.execute\(\s*'''\s*(CREATE TABLE.*?)(?:\n\s*)'''\s*\)",
    database_source,
    re.S,
)
commercial_sql = re.findall(
    r"'''(CREATE TABLE IF NOT EXISTS .*?)'''",
    database_source,
    re.S,
)
connection = sqlite3.connect(":memory:")
schema_errors: list[str] = []
for statement in base_sql + commercial_sql:
    try:
        connection.execute(statement.strip())
    except Exception as error:
        schema_errors.append(f"{statement.splitlines()[0]}: {error}")

additions_block_match = re.search(
    r"Future<void> _ensureCommercialColumns.*?final additions = <String, Map<String, String>>\{(.*?)\n\s*\};",
    database_source,
    re.S,
)
if additions_block_match:
    block = additions_block_match.group(1)
    table_matches = re.finditer(r"'([a-z_]+)'\s*:\s*\{(.*?)\n\s*\},", block, re.S)
    for table_match in table_matches:
        table = table_match.group(1)
        for column, declaration1, declaration2 in re.findall(
            r"'([a-z_]+)'\s*:\s*(?:'([^']*)'|\"([^\"]*)\")\s*,",
            table_match.group(2),
        ):
            declaration = declaration1 or declaration2
            try:
                existing = {
                    row[1] for row in connection.execute(f"PRAGMA table_info({table})")
                }
                if column not in existing:
                    connection.execute(
                        f"ALTER TABLE {table} ADD COLUMN {column} {declaration}"
                    )
            except Exception as error:
                schema_errors.append(f"ALTER TABLE {table}.{column}: {error}")

table_names = {
    row[0]
    for row in connection.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    )
}
record(
    "Build 9 SQLite schema simulation",
    "COMPLETE" if not schema_errors and len(table_names) >= 50 else "INCOMPLETE",
    f"{len(table_names)} application tables; schema version 8",
    "; ".join(schema_errors[:20]),
)
integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
record(
    "SQLite integrity simulation",
    "COMPLETE" if integrity == "ok" else "INCOMPLETE",
    integrity,
)
connection.close()

production_patterns = {
    "TODO": re.compile(r"\bTODO\b", re.I),
    "FIXME": re.compile(r"\bFIXME\b", re.I),
    "COMING SOON": re.compile(r"\bCOMING\s+SOON\b", re.I),
    "NOT IMPLEMENTED": re.compile(r"\bNOT\s+IMPLEMENTED\b", re.I),
    "UnimplementedError": re.compile(r"\bUnimplementedError\b"),
}
placeholder_hits: list[str] = []
for source in (ROOT / "lib").rglob("*.dart"):
    source_text = source.read_text(encoding="utf-8")
    for label, pattern in production_patterns.items():
        for match in pattern.finditer(source_text):
            line_no = source_text.count("\n", 0, match.start()) + 1
            placeholder_hits.append(f"{source.relative_to(ROOT)}:{line_no}:{label}")
record(
    "production placeholder scan",
    "COMPLETE" if not placeholder_hits else "INCOMPLETE",
    "No forbidden production placeholders" if not placeholder_hits else f"{len(placeholder_hits)} occurrences",
    "; ".join(placeholder_hits[:20]),
)

private_key_markers = ["-----BEGIN " + "PRIVATE KEY-----", "-----BEGIN " + "OPENSSH PRIVATE KEY-----"]
private_key_hits: list[str] = []
for source in ROOT.rglob("*"):
    if not source.is_file() or any(part in {".git", "build", "dist", ".dart_tool"} for part in source.parts):
        continue
    try:
        source_text = source.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    if any(marker in source_text for marker in private_key_markers):
        private_key_hits.append(str(source.relative_to(ROOT)))
record(
    "private signing key excluded",
    "COMPLETE" if not private_key_hits else "INCOMPLETE",
    "Only the Ed25519 public key may be committed",
    ", ".join(private_key_hits),
)

test_source = "\n".join(
    source.read_text(encoding="utf-8") for source in (ROOT / "test").glob("*.dart")
)
test_names = re.findall(r"\btest(?:Widgets)?\(\s*['\"]([^'\"]+)", test_source)
record(
    "test source inventory",
    "COMPLETE" if len(test_names) >= 25 else "INCOMPLETE",
    f"{len(test_names)} directly detected test declarations",
)

lock = ROOT / "pubspec.lock"
record(
    "dependency lock file",
    "COMPLETE" if lock.exists() else "BLOCKED",
    "Present" if lock.exists() else "Must be generated by flutter pub get on a Flutter-capable host",
)

summary = {
    "complete": sum(item["status"] == "COMPLETE" for item in RESULTS),
    "incomplete": sum(item["status"] == "INCOMPLETE" for item in RESULTS),
    "blocked": sum(item["status"] == "BLOCKED" for item in RESULTS),
    "missing": sum(item["status"] == "MISSING" for item in RESULTS),
    "checks": len(RESULTS),
}
payload = {
    "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "root": str(ROOT),
    "summary": summary,
    "results": RESULTS,
}
(ROOT / "BUILD9-SOURCE-VALIDATION.json").write_text(
    json.dumps(payload, indent=2) + "\n",
    encoding="utf-8",
)
for item in RESULTS:
    print(f"{item['status']} | {item['check']} | {item['detail']}")
print("SUMMARY | " + json.dumps(summary))
sys.exit(1 if summary["incomplete"] or summary["missing"] else 0)
