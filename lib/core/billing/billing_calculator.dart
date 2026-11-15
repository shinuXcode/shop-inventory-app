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

  void _validateLine(BillingLine line) {
    if (line.unitPriceMinor < 0) {
      throw ArgumentError.value(line.unitPriceMinor, 'unitPriceMinor');
    }
    if (line.quantity <= 0) {
      throw ArgumentError.value(line.quantity, 'quantity');
    }
    if (line.taxRateBps < 0 || line.taxRateBps > 10000) {
      throw ArgumentError.value(line.taxRateBps, 'taxRateBps');
    }
  }

  int lineSubtotal(BillingLine line) {
    _validateLine(line);
    return line.unitPriceMinor * line.quantity;
  }

  int taxFor(int baseMinor, int taxRateBps) {
    if (baseMinor < 0) {
      throw ArgumentError.value(baseMinor, 'baseMinor');
    }
    if (taxRateBps < 0 || taxRateBps > 10000) {
      throw ArgumentError.value(taxRateBps, 'taxRateBps');
    }
    // Integer-only half-up rounding avoids floating-point currency drift.
    return (baseMinor * taxRateBps + 5000) ~/ 10000;
  }

  BillingTotals calculate({
    required List<BillingLine> lines,
    int discountMinor = 0,
  }) {
    if (discountMinor < 0) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }
    final subtotal = lines.fold<int>(
      0,
      (sum, line) => sum + lineSubtotal(line),
    );
    if (discountMinor > subtotal) {
      throw ArgumentError('Discount cannot exceed subtotal.');
    }

    var remainingDiscount = discountMinor;
    var remainingSubtotal = subtotal;
    var tax = 0;
    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final base = lineSubtotal(line);
      final allocatedDiscount = index == lines.length - 1
          ? remainingDiscount
          : remainingSubtotal == 0
              ? 0
              : (base * remainingDiscount + remainingSubtotal ~/ 2) ~/
                  remainingSubtotal;
      remainingDiscount -= allocatedDiscount;
      remainingSubtotal -= base;
      tax += taxFor(base - allocatedDiscount, line.taxRateBps);
    }

    final taxable = subtotal - discountMinor;
    return BillingTotals(
      subtotalMinor: subtotal,
      taxMinor: tax,
      discountMinor: discountMinor,
      totalMinor: taxable + tax,
    );
  }
}
