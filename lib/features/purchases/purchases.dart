import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/billing/money_formatter.dart';
import '../../core/database/app_database.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage>
    with SingleTickerProviderStateMixin {
  late Future<_RetailData> _future;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<_RetailData> _load() async {
    final db = ref.read(databaseProvider);
    final values = await Future.wait<Object>([
      db.getSuppliers(),
      db.recentPurchases(),
      db.recentExpenses(),
      db.expiringStock(),
      db.searchItems(''),
    ]);
    return _RetailData(
      suppliers: values[0] as List<Supplier>,
      purchases: values[1] as List<Purchase>,
      expenses: values[2] as List<Expense>,
      expiring: values[3] as List<StockBatch>,
      items: values[4] as List<Item>,
    );
  }

  void _refresh() => setState(() => _future = _load());

  String _money(int minor) => MoneyFormatter.format(minor);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases & expenses'),
        actions: [
          IconButton(tooltip: 'Add supplier', onPressed: _addSupplier, icon: const Icon(Icons.person_add_alt_1_outlined)),
          IconButton(tooltip: 'Record purchase', onPressed: _recordPurchase, icon: const Icon(Icons.add_shopping_cart_outlined)),
          IconButton(tooltip: 'Add expense', onPressed: _addExpense, icon: const Icon(Icons.post_add_outlined)),
          IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_outlined)),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Suppliers'), Tab(text: 'Purchases'), Tab(text: 'Expenses')],
        ),
      ),
      body: FutureBuilder<_RetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load purchasing data: ${snapshot.error}'),
              ),
            );
          }
          final data = snapshot.data!;
          return Column(
            children: [
              if (data.expiring.isNotEmpty)
                MaterialBanner(
                  leading: const Icon(Icons.warning_amber_rounded),
                  content: Text(
                    '${data.expiring.length} stock batch(es) are expired or nearing expiry. Review them before sale.',
                  ),
                  actions: [
                    TextButton(onPressed: () => _showExpiring(data), child: const Text('Review')),
                  ],
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _supplierList(data),
                    _purchaseList(data),
                    _expenseList(data),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          switch (_tabs.index) {
            case 0: _addSupplier(); break;
            case 1: _recordPurchase(); break;
            case 2: _addExpense(); break;
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  Widget _supplierList(_RetailData data) {
    if (data.suppliers.isEmpty) {
      return const _EmptyState(
        icon: Icons.store_mall_directory_outlined,
        title: 'No suppliers yet',
        message: 'Add suppliers to track purchases and outstanding balances.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.suppliers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final supplier = data.suppliers[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
            title: Text(supplier.name),
            subtitle: Text([
              if ((supplier.phone ?? '').isNotEmpty) supplier.phone!,
              if ((supplier.gstin ?? '').isNotEmpty) 'GSTIN ${supplier.gstin}',
            ].join(' • ')),
            trailing: FutureBuilder<int>(
              future: ref.read(databaseProvider).supplierOutstandingMinor(supplier.id),
              builder: (context, value) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Outstanding', style: TextStyle(fontSize: 11)),
                  Text(_money(value.data ?? 0), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _purchaseList(_RetailData data) {
    if (data.purchases.isEmpty) {
      return const _EmptyState(
        icon: Icons.shopping_bag_outlined,
        title: 'No purchases recorded',
        message: 'Record supplier purchases to increase stock and track supplier dues.',
      );
    }
    final suppliers = {for (final supplier in data.suppliers) supplier.id: supplier};
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.purchases.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final purchase = data.purchases[index];
        final supplier = suppliers[purchase.supplierId];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: Text(purchase.purchaseNumber),
            subtitle: Text(
              '${supplier?.name ?? 'Supplier'} • ${DateFormat('dd MMM yyyy').format(purchase.createdAt)} • ${purchase.paymentStatus.toUpperCase()}',
            ),
            trailing: Text(_money(purchase.totalMinor), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  Widget _expenseList(_RetailData data) {
    if (data.expenses.isEmpty) {
      return const _EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No expenses recorded',
        message: 'Track rent, electricity, transport and other shop expenses.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.expenses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final expense = data.expenses[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: Text(expense.category),
            subtitle: Text(
              '${expense.description ?? expense.paymentMethod} • ${DateFormat('dd MMM yyyy').format(expense.incurredAt)}',
            ),
            trailing: Text(_money(expense.amountMinor), style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }

  Future<void> _addSupplier() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final gstin = TextEditingController();
    final address = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add supplier'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Supplier name')),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
              TextField(controller: gstin, decoration: const InputDecoration(labelText: 'GSTIN')),
              TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save supplier'),
          ),
        ],
      ),
    );
    if (saved == true) {
      final now = DateTime.now();
      await ref.read(databaseProvider).saveSupplier(SuppliersCompanion.insert(
        id: const Uuid().v4(),
        name: name.text.trim(),
        phone: Value(phone.text.trim().isEmpty ? null : phone.text.trim()),
        email: Value(email.text.trim().isEmpty ? null : email.text.trim()),
        gstin: Value(gstin.text.trim().isEmpty ? null : gstin.text.trim()),
        address: Value(address.text.trim().isEmpty ? null : address.text.trim()),
        createdAt: now,
        updatedAt: now,
      ));
      _refresh();
    }
    name.dispose();
    phone.dispose();
    email.dispose();
    gstin.dispose();
    address.dispose();
  }

  Future<void> _recordPurchase() async {
    final data = await _future;
    if (data.suppliers.isEmpty || data.items.isEmpty) {
      _message('Add at least one supplier and one active product first.');
      return;
    }
    String? supplierId = data.suppliers.first.id;
    String? itemId = data.items.first.id;
    DateTime? expiryDate;
    final quantity = TextEditingController(text: '1');
    final cost = TextEditingController(text: (data.items.first.costMinor / 100).toStringAsFixed(2));
    final paid = TextEditingController(text: '0');
    final discount = TextEditingController(text: '0');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record purchase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: data.suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                  onChanged: (value) => setDialogState(() => supplierId = value),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: itemId,
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: data.items.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      itemId = value;
                      final selected = data.items.firstWhere((item) => item.id == value);
                      cost.text = (selected.costMinor / 100).toStringAsFixed(2);
                    });
                  },
                ),
                TextField(controller: quantity, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
                TextField(controller: cost, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit cost (INR)')),
                TextField(controller: discount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Purchase discount (INR)')),
                TextField(controller: paid, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount paid (INR)')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) setDialogState(() => expiryDate = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(expiryDate == null ? 'Set expiry date (optional)' : DateFormat('dd MMM yyyy').format(expiryDate!)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (supplierId == null || itemId == null) return;
                if ((int.tryParse(quantity.text) ?? 0) <= 0) return;
                if ((double.tryParse(cost.text) ?? -1) < 0) return;
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save purchase'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && supplierId != null && itemId != null) {
      final item = data.items.firstWhere((entry) => entry.id == itemId);
      final qty = int.parse(quantity.text);
      final costMinor = ((double.tryParse(cost.text) ?? 0) * 100).round();
      final discountMinor = ((double.tryParse(discount.text) ?? 0) * 100).round();
      final paidMinor = ((double.tryParse(paid.text) ?? 0) * 100).round();
      try {
        await ref.read(databaseProvider).recordPurchase(
          purchaseId: const Uuid().v4(),
          purchaseNumber: 'PUR-${DateTime.now().millisecondsSinceEpoch}',
          supplierId: supplierId!,
          lines: [
            PurchaseLine(
              id: const Uuid().v4(),
              itemId: item.id,
              quantity: qty,
              unitCostMinor: costMinor,
              taxRateBps: (item.taxRate * 100).round(),
              expiryDate: expiryDate,
            ),
          ],
          discountMinor: discountMinor,
          paidMinor: paidMinor,
        );
        _refresh();
      } catch (error) {
        _message('Purchase was not saved: $error');
      }
    }
    quantity.dispose();
    cost.dispose();
    paid.dispose();
    discount.dispose();
  }

  Future<void> _addExpense() async {
    final category = TextEditingController();
    final amount = TextEditingController();
    final description = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add shop expense'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: category, decoration: const InputDecoration(labelText: 'Category (rent, electricity, etc.)')),
            TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (INR)')),
            TextField(controller: description, decoration: const InputDecoration(labelText: 'Description (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (category.text.trim().isEmpty || (double.tryParse(amount.text) ?? 0) <= 0) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save expense'),
          ),
        ],
      ),
    );
    if (saved == true) {
      await ref.read(databaseProvider).addExpense(
        id: const Uuid().v4(),
        category: category.text,
        amountMinor: ((double.tryParse(amount.text) ?? 0) * 100).round(),
        description: description.text,
        incurredAt: DateTime.now(),
      );
      _refresh();
    }
    category.dispose();
    amount.dispose();
    description.dispose();
  }

  Future<void> _showExpiring(_RetailData data) async {
    final itemNames = {for (final item in data.items) item.id: item.name};
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expiry review'),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: data.expiring.map((batch) => ListTile(
              title: Text(itemNames[batch.itemId] ?? 'Unknown product'),
              subtitle: Text(batch.expiryDate == null
                  ? 'No expiry date'
                  : 'Expires ${DateFormat('dd MMM yyyy').format(batch.expiryDate!)}'),
              trailing: Text('${batch.quantity} units'),
            )).toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

class _RetailData {
  const _RetailData({
    required this.suppliers,
    required this.purchases,
    required this.expenses,
    required this.expiring,
    required this.items,
  });

  final List<Supplier> suppliers;
  final List<Purchase> purchases;
  final List<Expense> expenses;
  final List<StockBatch> expiring;
  final List<Item> items;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
