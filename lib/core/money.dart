import 'dart:math' as math;

/// Currency-safe helpers for all persisted monetary values.
///
/// SQLite stores the resulting values as REAL for backward compatibility with
/// existing customer databases, but every calculation is normalized through
/// integer minor units before it is persisted or compared.
abstract final class MoneyMath {
  static const int scale = 100;

  static int toMinorUnits(num value) => (value.toDouble() * scale).round();

  static double fromMinorUnits(int value) => value / scale;

  static double round(num value) => fromMinorUnits(toMinorUnits(value));

  static double add(Iterable<num> values) {
    var total = 0;
    for (final value in values) {
      total += toMinorUnits(value);
    }
    return fromMinorUnits(total);
  }

  static double subtract(num left, num right) =>
      fromMinorUnits(toMinorUnits(left) - toMinorUnits(right));

  static double multiply(num quantity, num unitAmount) =>
      round(quantity.toDouble() * unitAmount.toDouble());

  static double percent(num amount, num rate) =>
      round(amount.toDouble() * rate.toDouble() / 100);

  static double clampNonNegative(num value) =>
      fromMinorUnits(math.max(0, toMinorUnits(value)));

  static bool greaterThan(num left, num right) =>
      toMinorUnits(left) > toMinorUnits(right);

  static bool equal(num left, num right) =>
      toMinorUnits(left) == toMinorUnits(right);
}
