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

  test('rejects negative prices, zero quantities and invalid tax rates', () {
    expect(() => calculator.calculate(
      lines: const [BillingLine(unitPriceMinor: -1, quantity: 1, taxRateBps: 0)],
    ), throwsArgumentError);
    expect(() => calculator.calculate(
      lines: const [BillingLine(unitPriceMinor: 100, quantity: 0, taxRateBps: 0)],
    ), throwsArgumentError);
    expect(() => calculator.calculate(
      lines: const [BillingLine(unitPriceMinor: 100, quantity: 1, taxRateBps: 10001)],
    ), throwsArgumentError);
  });

  test('allocates discounts using integer paise without losing a paise', () {
    final result = calculator.calculate(
      lines: const [
        BillingLine(unitPriceMinor: 100, quantity: 1, taxRateBps: 0),
        BillingLine(unitPriceMinor: 200, quantity: 1, taxRateBps: 0),
        BillingLine(unitPriceMinor: 300, quantity: 1, taxRateBps: 0),
      ],
      discountMinor: 1,
    );
    expect(result.subtotalMinor, 600);
    expect(result.discountMinor, 1);
    expect(result.totalMinor, 599);
  });
}
