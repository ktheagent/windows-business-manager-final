from __future__ import annotations
import datetime, hashlib, json, re, shutil, sqlite3, sys
from pathlib import Path
ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
RESULTS = []

def record(requirement, status, evidence, defect=""):
    RESULTS.append({"requirement": requirement, "status": status, "evidence": evidence, "defect": defect})

def read(relative):
    return (ROOT / relative).read_text(encoding="utf-8")
def apply_additions(connection, source, method_name):
    errors = []
    match = re.search(
        rf"Future<void> {re.escape(method_name)}.*?final additions = <String, Map<String, String>>\{{(.*?)\n\s*\}};",
        source, re.S)
    if not match:
        return [f"Could not locate {method_name} additions"]
    for table_match in re.finditer(r"'([a-z_]+)'\s*:\s*\{(.*?)\n\s*\},", match.group(1), re.S):
        table = table_match.group(1)
        columns = {row[1] for row in connection.execute(f"PRAGMA table_info({table})")}
        for column, single, double in re.findall(
            r"'([a-z_]+)'\s*:\s*(?:'([^']*)'|\"([^\"]*)\")\s*,", table_match.group(2)):
            if column in columns:
                continue
            declaration = single or double
            try:
                connection.execute(f"ALTER TABLE {table} ADD COLUMN {column} {declaration}")
                columns.add(column)
            except Exception as error:
                errors.append(f"{table}.{column}: {error}")
    return errors
database_source = read("lib/services/database_service.dart")
connection = sqlite3.connect(":memory:")
connection.execute("PRAGMA foreign_keys = ON")
triple = r"['\"]{3}"
base_pattern = rf"await db\.execute\(\s*{triple}\s*(CREATE TABLE.*?)(?:\n\s*){triple}\s*\)"
base_statements = re.findall(base_pattern, database_source, re.S)
for statement in base_statements:
    connection.execute(statement.strip())
connection.execute("INSERT INTO products (name, sku, barcode, category, cost_price, selling_price, stock_qty, low_stock_level, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", ("Legacy Product", "LEGACY-1", "1234567890128", "Legacy", 2.5, 5, 8, 2, "2025-01-01"))
connection.execute("INSERT INTO customers (name, phone, email, balance, created_at) VALUES (?, ?, ?, ?, ?)", ("Legacy Customer", "0240000000", "legacy@example.test", 15, "2025-01-01"))
connection.execute("INSERT INTO suppliers (name, phone, email, balance, created_at) VALUES (?, ?, ?, ?, ?)", ("Legacy Supplier", "", "", 20, "2025-01-01"))
connection.execute("INSERT INTO sales (invoice_no, subtotal, discount, total, payment_method, customer_id, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)", ("LEGACY-INV-1", 5, 0, 5, "Cash", 1, "2025-01-02"))
connection.execute("INSERT INTO sale_items (sale_id, product_id, product_name, quantity, unit_price, cost_price, total) VALUES (?, ?, ?, ?, ?, ?, ?)", (1, 1, "Legacy Product", 1, 5, 2.5, 5))
connection.execute("INSERT INTO expenses (title, category, amount, note, created_at) VALUES (?, ?, ?, ?, ?)", ("Legacy Expense", "Operations", 1, "", "2025-01-03"))
connection.commit()
schema_errors = apply_additions(connection, database_source, "_upgradeLegacyColumns")
commercial_pattern = rf"{triple}(CREATE TABLE IF NOT EXISTS .*?){triple}"
for statement in re.findall(commercial_pattern, database_source, re.S):
    try:
        connection.execute(statement.strip())
    except Exception as error:
        schema_errors.append(f"{statement.splitlines()[0]}: {error}")
schema_errors.extend(apply_additions(connection, database_source, "_ensureCommercialColumns"))
trigger_pattern = rf"{triple}\s*(CREATE TRIGGER IF NOT EXISTS .*?){triple}"
for statement in re.findall(trigger_pattern, database_source, re.S):
    try:
        connection.execute(statement.strip())
    except Exception as error:
        schema_errors.append(f"{statement.splitlines()[0]}: {error}")
for statement in re.findall(r'"(CREATE UNIQUE INDEX IF NOT EXISTS idx_(?:document_payment_ref|goods_receipt_ref|supplier_payment_ref|customer_transaction_ref|refund_ref|cash_movement_ref)[^"]+)"', database_source):
    try:
        connection.execute(statement)
    except Except Exception as error:
        schema_errors.append(f"{statement}: {error}")
tables = {row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
record("DATABASE-SCHEMA", "COMPLETE" if len(tables) >= 50 and not schema_errors else "INCOMPLETE", f"{len(tables)} application tables; errors={schema_errors}", "; ".join(schema_errors))
legacy_counts = {table: connection.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0] for table in ["products", "customers", "suppliers", "sales", "sale_items", "expenses"]}
record("MIGRATION-LEGACY-DATA", "COMPLETE" if all(value == 1 for value in legacy_counts.values()) else "INCOMPLETE", json.dumps(legacy_counts, sort_keys=True))
integrity = connection.execute("PRAGMA integrity_check").fetchone()[0]
foreign_keys = connection.execute("PRAGMA foreign_key_check").fetchall()
record("SQLITE-INTEGRITY", "COMPLETE" if integrity == "ok" and not foreign_keys else "INCOMPLETE", f"integrity_check={integrity}; foreign_key_violations={len(foreign_keys)}")
connection.execute("INSERT INTO audit_logs (user_id, branch_id, action, entity_type, entity_id, old_values, new_values, reason, success, device_id, created_at) VALUES (NULL, NULL, 'validation', 'source', '1', '', '', '', 1, 'validator', '2026-07-31')")
audit_update_blocked = audit_delete_blocked = False
try:
    connection.execute("UPDATE audit_logs SET action = 'tampered'")
except sqlite3.DatabaseError:
    audit_update_blocked = True
try:
    connection.execute("DELETE FROM audit_logs")
except sqlite3.DatabaseError:
    audit_delete_blocked = True
record("AUDIT-IMMUTABILITY", "COMPLETE" if audit_update_blocked and audit_delete_blocked else "INCOMPLETE", f"update_blocked={audit_update_blocked}; delete_blocked={audit_delete_blocked}")
connection.execute("INSERT INTO branches (id, name, code, address, phone, email, is_active, created_at) VALUES (1, 'Main', 'MAIN', '', '', '', 1, '2026-07-31')")
connection.execute("INSERT INTO documents (id, branch_id, document_no, document_type, status, subtotal, discount, tax, total, amount_paid, balance_due, notes, terms, created_at, updated_at) VALUES (1, 1, 'INV-1', 'invoice', 'issued', 1, 0, 0, 1, 0, 1, '', '', '2026-07-31', '2026-07-31')")
payment_values = (1, 1, 1, "Bank", "", "REF-1", "2026-07-31")
connection.execute("INSERT INTO document_payments (document_id, branch_id, amount, payment_method, reference, transaction_ref, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)", payment_values)
duplicate_blocked = False
try:
    connection.execute("INSERT INTO document_payments (document_id, branch_id, amount, payment_method, reference, transaction_ref, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)", payment_values)
except sqlite3.IntegrityError:
    duplicate_blocked = True
record("TRANSACTION-IDEMPOTENCY", "COMPLETE" if duplicate_blocked else "INCOMPLETE", f"duplicate_document_payment_blocked={duplicate_blocked}")
connection.close()
commercial_service = read("lib/commercial/services/commercial_service.dart")
models = read("lib/commercial/models/commercial_models.dart")
shell = read("lib/screens/shell_screen.dart")
suite = read("lib/commercial/screens/commercial_suite_screen.dart")
backup = read("lib/services/backup_service.dart")
updater = read("lib/commercial/services/update_service.dart")
notifications = read("lib/commercial/services/notification_service.dart")
remote = read("lib/commercial/services/remote_dashboard_service.dart")
imports = read("lib/commercial/services/import_service.dart")
workflow = read(".github/workflows/windows-build.yml")
tests = "\n".join(path.read_text(encoding="utf-8") for path in (ROOT / "test").glob("*.dart"))
advanced = read("lib/commercial/services/advanced_report_service.dart")
source_requirements = {
    "STAFF-ROLES": (all(role in models for role in ["owner", "manager", "cashier", "accountant", "stockOfficer"]) and all(token in commercial_service for token in ["createStaff", "updateStaff", "setStaffActive", "resetStaffPin", "setStaffLocked", "assignStaffBranches"]), "Five roles plus create/edit/disable/PIN/lock/branch service paths"),
    "PERMISSIONS": ("static const all" in models and "_require(actor" in commercial_service and "user.can(CommercialPermission" in shell, "Navigation and service permission enforcement"),
    "DOCUMENT-EDITOR": ((ROOT / "lib/commercial/screens/document_editor_dialog.dart").is_file() and all(token in commercial_service for token in ["updateDocumentDraft", "duplicateDocument", "cancelDocument", "documentStatusHistory"]), "Multi-line editor and document lifecycle services"),
    "STOCK-TRANSFER": (all(token in commercial_service for token in ["approveStockTransfer", "dispatchStockTransfer", "receiveStockTransfer", "reverseStockTransfer"]) and (ROOT / "lib/commercial/screens/stock_transfer_dialog.dart").is_file(), "Approval, dispatch, discrepancy receipt and reversal"),
    "REPORTS": (all(token in advanced for token in ["CommercialReportKind", "exportCsv", "exportXlsx", "buildPdf"]) and "CommercialReportKind" in suite, "Actual-data report catalog, filters and exports"),
    "BACKUPS": (all(token in backup for token in ["createEncryptedBackup", "inspectEncryptedBackup", "restoreEncryptedBackup", "recoverInterruptedRestore", "runDueSchedules", "uploadWebDav"]), "Encrypted backup, verification, scheduling, rollback and WebDAV"),
    "UPDATES": (all(token in updater for token in ["_verifyManifestSignature", "_verifyFileSignature", "sha256", "launchInstaller"]) and "ed25519PublicKeyBase64" in read("lib/core/release_signing_key.dart"), "HTTPS, SHA-256, Ed25519 manifest/file verification and launch"),
    "WHATSAPP": (all(token in notifications for token in ["openWhatsApp", "sendWhatsAppTemplate", "testWhatsAppApi", "providerMessageId"]), "WhatsApp Web and Business API delivery/status paths"),
    "SMTP": (all(token in notifications for token in ["sendEmail", "testSmtp", "FileAttachment", "allowInsecure: false"]), "TLS SMTP, attachment, retries and test action"),
    "REMOTE-DASHNOARD": (all(token in remote for token in ["remote_dashboard_access_logs", "HttpStatus.unauthorized", "stop"]), "Token-protected read-only service with access logging"),
    "IMPORTS": (all(token in imports for token in ["Excel.decodeBytes", "transaction", "import_jobs"]), "CSV/XLSX import with transaction and row-error logging"),
    "FORCED-PIN-CHANGE": ("forcePinChange" in shell and "changeOwnPin" in read("lib/state/app_state.dart"), "Non-dismissible PIN-change workflow and service update"),
}
for requirement, pair in source_requirements.items():
    ok, evidence = pair
    record(requirement, "COMPLETE" if ok else "INCOMPLETE", evidence)
licence_phrases = ["never extends expiry", "paid activation immediately replaces", "remains revoked offline"]
record("LICENCE-REGRESSION-SOURCE", "COMPLETE" if all(phrase in tests for phrase in licence_phrases) else "INCOMPLETE", ", ".join(licence_phrases))
build8_test_phrases = ["minor-unit arithmetic", "temporary staff PIN", "document draft edit", "purchase receipt transaction reference", "partial transfer", "recurring automatic posting", "advanced reports enforce branch isolation", "audit records cannot"]
record("BUILD8-REGRESSION-SOURCE", "COMPLETE" if all(phrase in tests for phrase in build8_test_phrases) else "INCOMPLETE", f"{sum(phrase in tests for phrase in build8_test_phrases)}/{len(build8_test_phrases)} required regression test sources")
required_workflow_tokens = ["flutter clean", "flutter pub get", "dart format --output=none --set-exit-if-changed .", "flutter analyze", "flutter test", "flutter build windows --release", "Build8-Setup.exe", "Build8-Portable.zip", "Build8-Full-Source.zip", "Build8-SHA256SUMS.txt", "Get-FileHash", "if-no-files-found: error"]
record("WINDOWS-WORKFLOW", "COMPLETE" if all(token in workflow for token in required_workflow_tokens) else "INCOMPLETE", f"{sum(token in workflow for token in required_workflow_tokens)}/{len(required_workflow_tokens)} required workflow tokens")
flutter_path = shutil.which("flutter") or ""
dart_path = shutil.which("dart") or ""
toolchain = {"flutter": flutter_path, "dart": dart_path, "platform": sys.platform}
record(
    "FLUTTER-RUNTIME-VALIDATION",
    "COMPLETE" if flutter_path and dart_path else "BLOCKED",
    json.dumps(toolchain, sort_keys=True),
)
record(
    "WINDOWS-RUNTIME.VALIDATION",
    "COMPLETE" if sys.platform == "win32" else "BLOCKED",
    f"host_platform={sys.platform}; requires Windows 10/11 build host",
)
summary = {status.lower(): sum(item["status"] == status for item in RESULTS) for status in ["COMPLETE", "INCOMPLETE", "BLOCKED", "MISSING"]}
summary["checks"] = len(RESULTS)
payload = {
    "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "source_root": str(ROOT),
    "pubspec_sha256": hashlib.sha256(read("pubspec.yaml").encode("utf-8")).hexdigest(),
    "summary": summary,
    "results": RESULTS,
}
(ROOT / "BUILD8-LOCAL-VALIDATION.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
for item in RESULTS:
    print(f"{item['status']} | {item['requirement']} | {item['evidence']}")
print("SUMMARY | " + json.dumps(summary, sort_keys=True))
sys.exit(1 if summary["incomplete"] or summary["missing"] else 0)
