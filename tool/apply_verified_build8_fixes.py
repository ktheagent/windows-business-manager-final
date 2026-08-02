from pathlib import Path


def replace_exact(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    if new in text:
        print(f"already applied: {path}")
        return
    if old not in text:
        raise RuntimeError(f"Verified pattern not found in {path}")
    file_path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")
    print(f"applied: {path}")


replace_exact(
    "lib/services/database_service.dart",
    """          onCreate: (db, version) async {
            await _createBaseSchema(db);
            await _createCommercialSchema(db);""",
    """          onCreate: (db, version) async {
            await _createBaseSchema(db);
            await _upgradeLegacyColumns(db);
            await _createCommercialSchema(db);""",
)

replace_exact(
    "test/build8_regression_test.dart",
    "        expect(draft.itemTax, 3.85);",
    "        expect(draft.itemTax, 4.35);",
)
