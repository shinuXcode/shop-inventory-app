import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/billing/indian_gst.dart';

void main() {
  const calculator = IndianGstCalculator();

  test('splits intra-state GST into equal CGST and SGST', () {
    final result = calculator.calculateLine(
      line: const GstLine(unitPriceMinor: 10000, quantity: 1, rateBps: 1800),
      supplyType: GstSupplyType.intraState,
    );
    expect(result.taxableMinor, 10000);
    expect(result.cgstMinor, 900);
    expect(result.sgstMinor, 900);
    expect(result.igstMinor, 0);
    expect(result.totalMinor, 11800);
  });

  test('uses IGST for inter-state supply', () {
    final result = calculator.calculateLine(
      line: const GstLine(unitPriceMinor: 10000, quantity: 2, rateBps: 1800),
      supplyType: GstSupplyType.interState,
    );
    expect(result.cgstMinor, 0);
    expect(result.sgstMinor, 0);
    expect(result.igstMinor, 3600);
    expect(result.totalMinor, 23600);
  });

  test('allocates invoice discount exactly across lines', () {
    final result = calculator.calculateInvoice(
      lines: const [
        GstLine(unitPriceMinor: 1000, quantity: 1, rateBps: 500),
        GstLine(unitPriceMinor: 2000, quantity: 1, rateBps: 1200),
      ],
      supplyType: GstSupplyType.intraState,
      discountMinor: 100,
    );
    expect(result.subtotalMinor, 3000);
    expect(result.discountMinor, 100);
    expect(result.taxableMinor, 2900);
    expect(result.totalMinor, result.taxableMinor + result.cgstMinor + result.sgstMinor);
  });

  test('rejects discounts above subtotal and invalid rates', () {
    expect(
      () => calculator.calculateLine(
        line: const GstLine(unitPriceMinor: 100, quantity: 1, rateBps: 1800),
        supplyType: GstSupplyType.interState,
        discountMinor: 101,
      ),
      throwsArgumentError,
    );
    expect(
      () => calculator.calculateLine(
        line: const GstLine(unitPriceMinor: 100, quantity: 1, rateBps: 10001),
        supplyType: GstSupplyType.interState,
      ),
      throwsArgumentError,
    );
  });
}
