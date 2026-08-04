from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if new in text:
        print(f"already applied: {path}")
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one pattern in {path}; found {count}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
    print(f"updated: {path}")

path = "lib/commercial/services/commercial_service.dart"

replace_once(
    path,
    """  static Future<void> _writeAudit(
""",
    """  static Object? _jsonSafeAuditValue(Object? value) {
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

  static Future<void> _writeAudit(
""",
)

replace_once(
    path,
    """    'old_values': oldValues == null ? null : jsonEncode(oldValues),
     'new_values': newValues == null ? null : jsonEncode(newValues),""",
    """    'old_values': oldValues == null ? null : _encodeAuditValues(oldValues),
     'new_values': newValues == null ? null : _encodeAuditValues(newValues),""",
)
