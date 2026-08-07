from pathlib import Path

path = Path("lib/commercial/services/commercial_service.dart")
text = path.read_text(encoding="utf-8")

replacements = [
    (
        "          'items': quantitiesByProductId,\n",
        "          'items': quantitiesByProductId.map((key, value) => MapEntry(key.toString(), value)),\n",
    ),
    (
        "        newValues: {'dispatched_quantities': dispatch},\n",
        "        newValues: {'dispatched_quantities': dispatch.map((key, value) => MapEntry(key.toString(), value))},\n",
    ),
    (
        "        newValues: {'receipt': receivedSummary},\n",
        "        newValues: {'receipt': receivedSummary.map((key, value) => MapEntry(key.toString(), value))},\n",
    ),
]

for old, new in replacements:
    if new in text:
        continue
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected exactly one verified pattern; found {count}: {old.strip()}")
    text = text.replace(old, new, 1)

for forbidden in [
    "'items': quantitiesByProductId,",
    "newValues: {'dispatched_quantities': dispatch},",
    "newValues: {'receipt': receivedSummary},",
]:
    if forbidden in text:
        raise SystemExit(f"unsafe stock-transfer audit payload still present: {forbidden}")

path.write_text(text, encoding="utf-8", newline="\n")
print("applied verified string-key conversion to all stock-transfer audit payloads")
