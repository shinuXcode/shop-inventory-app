import 'package:flutter_test/flutter_test.dart';
import 'package:sbill/core/billing/billing_calculator.dart';

void main() {
  const calculator = BillingCalculator();

  test('₹100 x 2 at 18% produces ₹200 subtotal, ₹36 tax and ₹236 total', () {
    final result = calculator.calculate(
      lines: const [
        BillingLine(unitPriceMinor: 10000, quantity: 2, taxRateBps: 1800),
      ],
    );
    expect(result.subtotalMinor, 20000);
    expect(result.taxMinor, 3600);
    expect(result.totalMinor, 23600);
  });

  test('discount is included in taxable base deterministically', () {
    final result = calculator.calculate(
      lines: const [
        BillingLine(unitPriceMinor: 10000, quantity: 2, taxRateBps: 1800),
      ],
      discountMinor: 1000,
    );
    expect(result.subtotalMinor, 20000);
    expect(result.discountMinor, 1000);
    expect(result.taxMinor, 3420);
    expect(result.totalMinor, 22420);
  });

  test('discount greater than subtotal is rejected', () {
    expect(
      () => calculator.calculate(
        lines: const [BillingLine(unitPriceMinor: 100, quantity: 1, taxRateBps: 0)],
        discountMinor: 101,
      ),
      throwsArgumentError,
    );
  });
}
