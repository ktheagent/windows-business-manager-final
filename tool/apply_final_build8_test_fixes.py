from pathlib import Path
import re

PATH = Path("lib/commercial/services/commercial_service.dart")
HELPER_MARKER = "static Object? _jsonSafeAuditValue(Object? value)"
HELPER = """  static Object? _jsonSafeAuditValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) return value.toIso8601String();
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafeAuditValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_jsonSafeAuditValue).toList(growable: false);
    }
    return value.toString();
  }

  static String _encodeAuditValues(Map<String, Object?> values) =>
      jsonEncode(_jsonSafeAuditValue(values));

"""


def main() -> None:
    text = PATH.read_text(encoding="utf-8")

    if HELPER_MARKER not in text:
        needle = "  static Future<void> _writeAudit(\n"
        if text.count(needle) != 1:
            raise SystemExit("could not locate the unique _writeAudit method")
        text = text.replace(needle, HELPER + needle, 1)

    replacements = [
        (
            r"(?m)^(\s*)'old_values':\+soldValues\+==\s*null\s*\?\s*null\s*:\+jsonEncode\(oldValues\),\s*$",
            r"\1'old_values': oldValues == null ? null : _encodeAuditValues(oldValues),",
            "_encodeAuditValues(oldValues)",
        ),
        (
            r"(?m)^(\s*)'new_values':\snewValues\+==\s*null\s*\?\s*null\s*:\+jsonEncode\(newValues\),\s*$",
            r"\1'new_values': newValues == null ? null : _encodeAuditValues(newValues),",
            "_encodeAuditValues(newValues)",
        ),
    ]

    for pattern, replacement, marker in replacements:
        if marker not in text:
            text, count = re.subn(pattern, replacement, text, count=1)
            if count != 1:
                raise SystemExit(f"could not apply verified audit replacement: {marker}")

    if "jsonEncode(oldValues)" in text or "jsonEncode(newValues)" in text:
        raise SystemExit("unsafe audit JSON encoding still present")
    if text.count("_encodeAuditValues(oldValues)") != 1:
        raise SystemExit("oldValues audit encoder was not applied exactly once")
    if text.count("_encodeAuditValues(newValues)") != 1:
        raise SystemExit("newValues audit encoder was not applied exactly once")

    PATH.write_text(text, encoding="utf-8", newline="\n")
    print("applied and verified nested audit JSON encoding")


if __name__ == "__main__":
    main()
