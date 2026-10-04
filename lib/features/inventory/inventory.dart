import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../core/database/app_database.dart';

final itemsProvider = StreamProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(databaseProvider).watchActiveItems());

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(itemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory'), actions: [
        IconButton(tooltip: 'Add product', onPressed: () => _add(context, ref), icon: const Icon(Icons.add))
      ]),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load inventory: $e')),
        data: (list) => list.isEmpty ? _empty(context, ref) :
          ListView.separated(
            padding: const EdgeInsets.all(16), itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final x = list[i];
              final low = x.stockQuantity <= x.lowStockThreshold;
              return Card(child: ListTile(
                leading: CircleAvatar(child: Text(x.name.isEmpty ? '?' : x.name[0].toUpperCase())),
                title: Text(x.name),
                subtitle: Text((x.sku ?? 'No SKU') + ' • ' + x.stockQuantity.toString() +
                  ' in stock' + (low ? ' • Low stock' : '')),
                trailing: Text('₹' + (x.priceMinor / 100).toStringAsFixed(2)),
              ));
            },
          ),
      ),
    );
  }

  Widget _empty(BuildContext c, WidgetRef r) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.inventory_2_outlined, size: 56),
      const SizedBox(height: 12), const Text('No products yet'),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: () => _add(c, r), icon: const Icon(Icons.add), label: const Text('Add product')),
    ]),
  );

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(), price = TextEditingController();
    final stock = TextEditingController(text: '0');
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Add product'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Product name')),
        const SizedBox(height: 8),
        TextField(controller: price, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Price (₹)')),
        const SizedBox(height: 8),
        TextField(controller: stock, keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Stock')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ));
    if (ok != true || name.text.trim().isEmpty) return;
    final now = DateTime.now();
    final rupees = double.tryParse(price.text) ?? 0;
    final qty = int.tryParse(stock.text) ?? 0;
    await ref.read(databaseProvider).saveItem(ItemsCompanion.insert(
      id: const Uuid().v4(), name: name.text.trim(), priceMinor: (rupees * 100).round(),
      createdAt: now, updatedAt: now, stockQuantity: Value(qty)));
  }
}
