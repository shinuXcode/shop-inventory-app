/// Deterministic Indian GST calculations in integer paise.
///
/// Rates are expressed in basis points: 18% = 1800. This class calculates
/// tax splits only; it does not decide legal taxability or place of supply.
enum GstSupplyType { intraState, interState }

class GstLine {
  const GstLine({
    required this.unitPriceMinor,
    required this.quantity,
    required this.rateBps,
    this.hsnSac,
  });

  final int unitPriceMinor;
  final int quantity;
  final int rateBps;
  final String? hsnSac;
}

class GstLineResult {
  const GstLineResult({
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
  });

  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  int get taxMinor => cgstMinor + sgstMinor + igstMinor;
  int get totalMinor => taxableMinor + taxMinor;
}

class GstInvoiceResult {
  const GstInvoiceResult({
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
  });

  final int subtotalMinor;
  final int discountMinor;
  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  int get taxMinor => cgstMinor + sgstMinor + igstMinor;
  int get totalMinor => taxableMinor + taxMinor;
}

class IndianGstCalculator {
  const IndianGstCalculator();

  int taxFor(int taxableMinor, int rateBps) {
    if (taxableMinor < 0) {
      throw ArgumentError.value(taxableMinor, 'taxableMinor');
    }
    if (rateBps < 0 || rateBps > 10000) {
      throw ArgumentError.value(rateBps, 'rateBps');
    }
    return (taxableMinor * rateBps + 5000) ~/ 10000;
  }

  GstLineResult calculateLine({
    required GstLine line,
    required GstSupplyType supplyType,
    int discountMinor = 0,
  }) {
    if (line.quantity <= 0) {
      throw ArgumentError.value(line.quantity, 'quantity');
    }
    if (line.unitPriceMinor < 0) {
      throw ArgumentError.value(line.unitPriceMinor, 'unitPriceMinor');
    }
    final subtotal = line.unitPriceMinor * line.quantity;
    if (discountMinor < 0 || discountMinor > subtotal) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }
    final taxable = subtotal - discountMinor;
    final tax = taxFor(taxable, line.rateBps);
    final cgst = supplyType == GstSupplyType.intraState ? tax ~/ 2 : 0;
    final sgst = supplyType == GstSupplyType.intraState ? tax - cgst : 0;
    return GstLineResult(
      taxableMinor: taxable,
      cgstMinor: cgst,
      sgstMinor: sgst,
      igstMinor: supplyType == GstSupplyType.interState ? tax : 0,
    );
  }

  GstInvoiceResult calculateInvoice({
    required List<GstLine> lines,
    required GstSupplyType supplyType,
    int discountMinor = 0,
  }) {
    if (lines.isEmpty) throw ArgumentError('At least one invoice line is required.');
    final subtotal = lines.fold<int>(
      0,
      (sum, line) {
        if (line.quantity <= 0 || line.unitPriceMinor < 0) {
          throw ArgumentError('Invoice lines must have positive quantities and non-negative prices.');
        }
        if (line.rateBps < 0 || line.rateBps > 10000) {
          throw ArgumentError.value(line.rateBps, 'rateBps');
        }
        return sum + line.unitPriceMinor * line.quantity;
      },
    );
    if (discountMinor < 0 || discountMinor > subtotal) {
      throw ArgumentError.value(discountMinor, 'discountMinor');
    }

    var remainingDiscount = discountMinor;
    var remainingSubtotal = subtotal;
    var taxable = 0;
    var cgst = 0;
    var sgst = 0;
    var igst = 0;

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final lineSubtotal = line.unitPriceMinor * line.quantity;
      final lineDiscount = index == lines.length - 1
          ? remainingDiscount
          : remainingSubtotal == 0
              ? 0
              : (lineSubtotal * remainingDiscount + remainingSubtotal ~/ 2) ~/
                  remainingSubtotal;
      remainingDiscount -= lineDiscount;
      remainingSubtotal -= lineSubtotal;
      final result = calculateLine(
        line: line,
        supplyType: supplyType,
        discountMinor: lineDiscount,
      );
      taxable += result.taxableMinor;
      cgst += result.cgstMinor;
      sgst += result.sgstMinor;
      igst += result.igstMinor;
    }

    return GstInvoiceResult(
      subtotalMinor: subtotal,
      discountMinor: discountMinor,
      taxableMinor: taxable,
      cgstMinor: cgst,
      sgstMinor: sgst,
      igstMinor: igst,
    );
  }
}
