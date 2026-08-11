from pathlib import Path
import re

import sys


def replace_exact(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one occurrence, found {count}")
    return text.replace(old, new, 1)


def normalize_generators() -> None:
    final_path = Path("tool/apply_build9_final_workflow_fixes.py")
    final_text = final_path.read_text(encoding="utf-8")

    final_text = final_text.replace(
        '    final draft = SaleDraft(\n"",\n',
        '    final draft = SaleDraft(\n""",\n',
    )
    final_text = final_text.replace("    r 'bool(re.search", "    r'bool(re.search")
    final_text = final_text.replace(
        r'(?m)^version:\*\1\.3\.0\\+8\s*$',
        r'(?m)^version:\s*1\.3\.0\+8\s*$',
    )
    final_text = final_text.replace(
        r'(?m)^version:\*\1\.3\.0\\+9\s*$',
        r'(?m)^version:\s*1\.3\.0\+9\s*$',
    )
    final_text = replace_exact(
        final_text,
        "        cashSessionId: refundMethod == 'Cash'\n"
        "            ? widget.state.currentCashSession?['id'] as int?\n"
        "            : null,\n",
        "        cashSessionId: refundMethod == 'Cash'\n"
        "            ? (widget.state.currentCashSession?['id'] as int?)\n"
        "            : null,\n",
        "cashSessionId ternary normalization",
    )
    final_path.write_text(final_text, encoding="utf-8")
    compile(final_text, str(final_path), "exec")

    hardening_path = Path("tool/apply_build9_validation_hardening.py")
    hardening_text = hardening_path.read_text(encoding="utf-8")
    hardening_text = replace_exact(
        hardening_text,
        '    "      ),",\n'
        '    "",\n'
        '    "      await tester.tap(find.text(\'Open editor\'));",\n',
        '    "      ),",\n'
        '    "      );",\n'
        '    "",\n'
        '    "      await tester.tap(find.text(\'Open editor\'));",\n',
        "generated pumpWidget closure",
    )
    hardening_path.write_text(hardening_text, encoding="utf-8")
    compile(hardening_text, str(hardening_path), "exec")
    print("Build 9 generators normalized and compiled.")


def cleanup_theme() -> None:
    path = Path("lib/core/app_theme.dart")
    text = path.read_text(encoding="utf-8")
    declaration = "    const muted = PremiumGlassPalette.muted;\n"
    if text.count(declaration) != 1:
        raise SystemExit(
            f"{path}: expected exactly one muted declaration, found {text.count(declaration)}"
        )
    updated = text.replace(declaration, "", 1)
    if re.search(r'\bmuted\b', updated):
        raise SystemExit(f"{path}: refusing cleanup because a muted reference remains")
    required = [
        "color: Color(0xFF4A5568)",
        "color: primary",
        "floatingLabelStyle: const TextStyle(",
    ]
    missing = [fragment for fragment in required if fragment not in updated]
    if missing:
        raise SystemExit(f"{path}: missing expected Build 9 contrast fragments: {missing!r}")
    path.write_text(updated, encoding="utf-8")
    print("Verified Build 9 contrast styles and removed unused muted alias.")


if __name__ == "__main__":
    if len(sys.argv) != 2 or sys.argv[1] not in {"normalize", "cleanup-theme"}:
        raise SystemExit("Usage: prepare_build9_pipeline.py [normalize|cleanup-theme]")
    if sys.argv[1] == "normalize":
        normalize_generators()
    else:
        cleanup_theme()
