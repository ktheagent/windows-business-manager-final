from __future__ import annotations

import re
from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")


def write_if_changed(path: str, before: str, after: str) -> None:
    if before != after:
        Path(path).write_text(after, encoding="utf-8", newline="\n")
        print(f"updated {path}")


# file_picker 11 uses static methods directly on FilePicker.
for dart_path in Path("lib").rglob("*.dart"):
    before = dart_path.read_text(encoding="utf-8")
    after = before.replace("FilePicker.platform.", "FilePicker.")
    if after != before:
        dart_path.write_text(after, encoding="utf-8", newline="\n")
        print(f"updated {dart_path.as_posix()}")

# PdfPageFormat.a4.landscape is a getter and cannot appear in a const map.
path = "lib/commercial/screens/commercial_suite_screen.dart"
before = read(path)
after = before.replace(
    "pageFormats: const {\n"
    "            'A4 landscape': PdfPageFormat.a4.landscape,\n"
    "          },",
    "pageFormats: {\n"
    "            'A4 landscape': PdfPageFormat.a4.landscape,\n"
    "          },",
)
write_if_changed(path, before, after)

# sqflite_common exposes firstIntValue as a top-level utility.
for path in (
    "lib/commercial/services/commercial_service.dart",
    "lib/services/database_service.dart",
):
    before = read(path)
    after = before.replace("Sqflite.firstIntValue", "firstIntValue")
    utility_import = "import 'package:sqflite_common/utils/utils.dart';"
    if utility_import not in after:
        anchor = "import 'package:sqflite_common_ffi/sqflite_ffi.dart';"
        if anchor not in after:
            raise SystemExit(f"Missing sqflite import anchor in {path}")
        after = after.replace(anchor, f"{utility_import}\n{anchor}", 1)
    write_if_changed(path, before, after)

# New staff accounts receive temporary PINs and must change them by default.
path = "lib/commercial/services/commercial_service.dart"
before = read(path)
after = before
signature_pattern = re.compile(
    r"(Future<int> createStaff\(\{\n"
    r"(?:.*\n)*?"
    r"\s+required StaffRole role,\n)"
    r"(\s+\}\) async \{)",
)
if "Future<int> createStaff({" not in after:
    raise SystemExit("createStaff method was not found")
if not re.search(
    r"Future<int> createStaff\(\{(?:.|\n)*?bool forcePinChange",
    after,
):
    after, count = signature_pattern.subn(
        r"\1    bool forcePinChange = true,\n\2",
        after,
        count=1,
    )
    if count != 1:
        raise SystemExit("Could not add forcePinChange to createStaff")
create_staff_start = after.index("Future<int> createStaff({")
create_staff_end = after.index("  Future<", create_staff_start + 10)
create_staff = after[create_staff_start:create_staff_end]
if "'force_pin_change': forcePinChange ? 1 : 0," not in create_staff:
    old = "        'role': role.databaseValue,\n        'is_active': 1,"
    new = (
        "        'role': role.databaseValue,\n"
        "        'force_pin_change': forcePinChange ? 1 : 0,\n"
        "        'is_active': 1,"
    )
    if old not in create_staff:
        raise SystemExit("Could not locate createStaff insert map")
    create_staff = create_staff.replace(old, new, 1)
    after = after[:create_staff_start] + create_staff + after[create_staff_end:]
write_if_changed(path, before, after)

# mailer 7 returns one SendReport; a successful return means the server accepted it.
path = "lib/commercial/services/notification_service.dart"
before = read(path)
after, count = re.subn(
    r"final result = await send\(message, server\);\n\s*final sent = result\.isNotEmpty;",
    "await send(message, server);\n        const sent = true;",
    before,
    count=1,
)
if count == 0 and "result.isNotEmpty" in before:
    raise SystemExit("Could not update Mailer SendReport handling")
write_if_changed(path, before, after)

# printing 5.14.3 does not expose windowsModernDialog.
path = "lib/widgets/pdf_preview_dialog.dart"
before = read(path)
after = re.sub(r"^\s*windowsModernDialog:\s*true,\n", "", before, flags=re.MULTILINE)
write_if_changed(path, before, after)

# Excel 4 returns a non-null worksheet from a non-empty tables collection.
path = "lib/commercial/services/import_service.dart"
before = read(path)
after = before.replace("import 'dart:convert';\n", "", 1)
after = after.replace("      if (sheet == null) return const [];\n", "", 1)
write_if_changed(path, before, after)
