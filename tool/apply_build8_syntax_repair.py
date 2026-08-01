from pathlib import Path


def replace_if_present(path: str, old: str, new: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    updated = text.replace(old, new, 1) if old in text else text
    if updated != text:
        file_path.write_text(updated, encoding="utf-8", newline="\n")
        print(f"updated {path}")


def remove_all(path: str, value: str) -> None:
    file_path = Path(path)
    text = file_path.read_text(encoding="utf-8")
    updated = text.replace(value, "")
    if updated != text:
        file_path.write_text(updated, encoding="utf-8", newline="\n")
        print(f"updated {path}")


suite = "lib/commercial/screens/commercial_suite_screen.dart"
replace_if_present(
    suite,
    """        cashSessionId: method == 'Cash'
            ? widget.state.currentCashSession?['id'] as int?
            : null,""",
    """        cashSessionId: method == 'Cash'
            ? (widget.state.currentCashSession?['id'] as int?)
            : null,""",
)
replace_if_present(
    suite,
    """                            '${staff.isActive ? 'Active' : 'Disabled'}'
                             '${staff.lockedUntil != null ? ' • Locked' : ''}
'
                             'Last login: ${staff.lastLoginAt ?? 'Never'}',""",
    """                            '${staff.isActive ? 'Active' : 'Disabled'}'
                             '${staff.lockedUntil != null ? ' • Locked' : ''}\\n'
                             'Last login: ${staff.lastLoginAt ?? 'Never'}',""",
)
remove_all(suite, "import '../../models/product.dart';\n")
remove_all(suite, "                  final id = document['id'] as int;\n")

state = "lib/state/app_state.dart"
replace_if_present(
    state,
    """      cashSessionId: draft.paymentMethod == 'Cash'
          ? currentCashSession?['id'] as int?
          : null,""",
    """      cashSessionId: draft.paymentMethod == 'Cash'
          ? (currentCashSession?['id'] as int?)
          : null,""",
)

commercial = "lib/commercial/services/commercial_service.dart"
remove_all(commercial, "import '../../models/sale.dart';\n")
