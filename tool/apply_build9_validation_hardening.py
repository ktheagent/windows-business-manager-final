from pathlib import Path
import re

def read(path: str) -> str:
    return Path(path).read_text(encoding="utf-8")

def write(path: str, text: str) -> None:
    Path(path).write_text(text, encoding="utf-8")

def sub_once(text: str, pattern: str, repl: str, path: str, label: str, flags: int = 0) -> str:
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f"{path}: expected one {label} match, found {count}")
    return updated

path = "lib/commercial/screens/document_editor_dialog.dart"
text = read(path)

# Make the dialog body scrollable rather than forcing all content into the available height.
text = sub_once(
    text,
    r'(?m)^(\s*)child: Column\(\n(\s*)children: \[\n',
    r'\1child: ListView(\n\2children: [\n',
    path,
    'dialog Column',
)

# Give the line-item area a bounded height so compact windows can scroll the overall dialog.
text = sub_once(
    text,
    r'(?m)^(\s*)Expanded\(\n(^\n]*child: _lines\.isEmpty\n!',
    r'',
    path,
    'line-item Expanded',
)
