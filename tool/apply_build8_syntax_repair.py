from pathlib import Path

suite_path = Path("lib/commercial/screens/commercial_suite_screen.dart")
suite = suite_path.read_text(encoding="utf-8")

old_cash = """        cashSessionId: method == 'Cash'
            ? widget.state.currentCashSession?['id'] as int?
            : null,"""
new_cash = """        cashSessionId: method == 'Cash'
            ? (widget.state.currentCashSession?['id'] as int?)
            : null,"""
if old_cash not in suite:
    raise SystemExit("Expected customer-payment cash-session expression was not found.")
suite = suite.replace(old_cash, new_cash, 1)

old_staff = """                            '${staff.isActive ? 'Active' : 'Disabled'}'
                            '${staff.lockedUntil != null ? ' • Locked' : ''}
'
                            'Last login: ${staff.lastLoginAt ?? 'Never'}',"""
new_staff = """                            '${staff.isActive ? 'Active' : 'Disabled'}'
                            '${staff.lockedUntil != null ? ' • Locked' : ''}\\n'
                            'Last login: ${staff.lastLoginAt ?? 'Never'}',"""
if old_staff not in suite:
    raise SystemExit("Expected unterminated staff-status string was not found.")
suite = suite.replace(old_staff, new_staff, 1)
suite_path.write_text(suite, encoding="utf-8", newline="\n")

state_path = Path("lib/state/app_state.dart")
state = state_path.read_text(encoding="utf-8")
old_sale = """      cashSessionId: draft.paymentMethod == 'Cash'
          ? currentCashSession?['id'] as int?
          : null,"""
new_sale = """      cashSessionId: draft.paymentMethod == 'Cash'
          ? (currentCashSession?['id'] as int?)
          : null,"""
if old_sale not in state:
    raise SystemExit("Expected sale cash-session expression was not found.")
state = state.replace(old_sale, new_sale, 1)
state_path.write_text(state, encoding="utf-8", newline="\n")
