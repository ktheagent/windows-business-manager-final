from pathlib import Path

path = Path("lib/commercial/services/commercial_service.dart")
text = path.read_text(encoding="utf-8")

def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one occurrence, found {count}: {old[:140]!r}")
    text = text.replace(old, new, 1)

replace_once(
    "'document_no': _number(_documentPrefix(draft.type), now),",
    """'document_no': await _uniqueDocumentNumber(
          txn,
          prefix: _documentPrefix(draft.type),
          at: now,
        ),""",
)

replace_once(
    """'document_no': _number(
          _documentPrefix(source['document_type'] as String),
          now,
        ),""",
    """'document_no': await _uniqueDocumentNumber(
          txn,
          prefix: _documentPrefix(source['document_type'] as String),
          at: now,
        ),""",
)

marker = """  static String _number(String prefix, DateTime dateTime) {
"""
helper = """  static Future<String> _uniqueDocumentNumber(
    DatabaseExecutor db, {
    required String prefix,
    required DateTime at,
  }) async {
    final base = _number(prefix, at);
    var candidate = base;
    var attempt = 0;
    while (true) {
      final existing =
          firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM documents WHERE document_no = ?',
              [candidate],
            ),
          ) ??
          0;
      if (existing == 0) return candidate;
      attempt += 1;
      candidate = '$base-$attempt';
    }
  }

"""
replace_once(marker, helper + marker)

path.write_text(text, encoding="utf-8")
print("Applied collision-safe commercial document numbering.")
