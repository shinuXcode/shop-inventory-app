class AppConstants {
  // Expense categories
  static const List<String> expenseCategories = [
    'Rent',
    'Electricity',
    'Internet',
    'Salary',
    'Transport',
    'Repair',
    'Packaging',
    'Miscellaneous',
  ];

  // Payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'Card',
    'UPI',
    'Credit',
    'Cheque',
  ];

  // Stock transaction types
  static const List<String> stockTransactionTypes = [
    'Purchase',
    'Sale',
    'Sale Return',
    'Purchase Return',
    'Manual Adjustment',
    'Damaged',
    'Lost',
    'Opening Stock',
  ];

  // Currency
  static const String currencySymbol = '₹';
  
  // Database
  static const int databaseVersion = 1;
  static const String databaseName = 'shop_inventory.db';
}
