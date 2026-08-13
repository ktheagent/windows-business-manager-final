from pathlib import Path

path = Path("lib/commercial/services/advanced_report_service.dart")
text = path.read_text(encoding="utf-8")

old_call = "_authorize(actor, filter);"
new_call = "_authorize(actor, filter, kind);"
if old_call not in text:
    raise SystemExit("Report authorization call not found")
text = text.replace(old_call, new_call, 1)

old = """  static void _authorize(StaffUser actor, CommercialReportFilter filter) {
    if (!actor.can(CommercialPermission.reportsView) &&
        !actor.can(CommercialPermission.reportsProfit)) {
      throw StateError('Your staff role cannot view commercial reports.');
    }
"""
new = """  static void _authorize(
    StaffUser actor,
    CommercialReportFilter filter,
    CommercialReportKind kind,
  ) {
    const profitKinds = <CommercialReportKind>{
      CommercialReportKind.grossProfit,
      CommercialReportKind.netProfit,
      CommercialReportKind.costOfGoodsSold,
      CommercialReportKind.profitByProduct,
      CommercialReportKind.profitByCategory,
      CommercialReportKind.profitByUser,
      CommercialReportKind.profitByBranch,
    };
    if (profitKinds.contains(kind) &&
        !actor.can(CommercialPermission.reportsProfit)) {
      throw StateError(
        'Your staff role cannot view profit-sensitive reports.',
      );
    }
    if (!profitKinds.contains(kind) &&
        !actor.can(CommercialPermission.reportsView) &&
        !actor.can(CommercialPermission.reportsProfit)) {
      throw StateError('Your staff role cannot view commercial reports.');
    }
"""
if old not in text:
    raise SystemExit("Report authorization method not found")
text = text.replace(old, new, 1)

for token in [
    "_authorize(actor, filter, kind)",
    "profit-sensitive reports",
    "CommercialReportKind.profitByUser",
]:
    if token not in text:
        raise SystemExit(f"Service patch missing token: {token}")

path.write_text(text, encoding="utf-8")
