class BillingLine {
  const BillingLine({
    required this.unitPriceMinor,
    required this.quantity,
    required this.taxRateBps,
  });
  final int unitPriceMinor;
  final int quantity;
  final int taxRateBps;
}

class BillingTotals {
  const BillingTotals({
    required this.subtotalMinor,
    required this.taxMinor,
    required this.discountMinor,
    required this.totalMinor,
  });
  final int subtotalMinor;
  final int taxMinor;
  final int discountMinor;
  final int totalMinor;
}

class BillingCalculator {
  const BillingCalculator();

  int lineSubtotal(BillingLine line) => line.unitPriceMinor * line.quantity;

  int taxFor(int baseMinor, int taxRateBps) =>
      ((baseMinor * taxRateBps) / 10000).round();

  BillingTotals calculate({
    required List<BillingLine> lines,
    int discountMinor = 0,
  }) {
    if (discountMinor < 0) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }
    final subtotal = lines.fold<int>(0, (sum, line) => sum + lineSubtotal(line));
    if (discountMinor > subtotal) {
      throw ArgumentError('Discount cannot exceed subtotal.');
    }
    final taxable = subtotal - discountMinor;
    final tax = lines.isEmpty
        ? 0
        : taxFor(taxable, lines.fold<int>(0, (sum, line) => line.taxRateBps) ~/ lines.length);
    return BillingTotals(
      subtotalMinor: subtotal,
      taxMinor: tax,
      discountMinor: discountMinor,
      totalMinor: taxable + tax,
    );
  }
}
