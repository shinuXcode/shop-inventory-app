import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../migration/migration.dart';
import '../../core/database/app_database.dart';

final itemsProvider = StreamProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(databaseProvider).watchActiveItems());

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  final search = TextEditingController();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final items = ref.watch(itemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory'), actions: [
        IconButton(
          tooltip: 'Import products / switch to SBILL',
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MigrationPage())),
          icon: const Icon(Icons.file_download_outlined),
        ),
        IconButton(
          tooltip: 'Add product',
          onPressed: () => _edit(context, ref),
          icon: const Icon(Icons.add_box_outlined),
        ),
      ]),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load inventory: $e')),
        data: (list) {
          final query = search.text.trim().toLowerCase();
          final filtered = query.isEmpty ? list : list.where((x) =>
            x.name.toLowerCase().contains(query) ||
            (x.sku ?? '').toLowerCase().contains(query) ||
            (x.barcode ?? '').toLowerCase().contains(query) ||
            (x.category ?? '').toLowerCase().contains(query)
          ).toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: TextField(
                controller: search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search product, SKU, barcode or category',
                  suffixIcon: search.text.isEmpty ? null : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () { search.clear(); setState(() {}); },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            ),
            Expanded(child: filtered.isEmpty ? _empty(context, ref, searched: query.isNotEmpty) : LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 1100) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Product')), DataColumn(label: Text('SKU')),
                    DataColumn(label: Text('Price')), DataColumn(label: Text('Stock')),
                    DataColumn(label: Text('Tax')), DataColumn(label: Text('Actions')),
                  ],
                  rows: filtered.map((x) => DataRow(cells: [
                    DataCell(Text(x.name)),
                    DataCell(Text(x.sku ?? '—')),
                    DataCell(Text('₹' + (x.priceMinor / 100).toStringAsFixed(2))),
                    DataCell(Text(x.stockQuantity.toString())),
                    DataCell(Row(children: [
                      if (x.stockQuantity <= x.lowStockThreshold) const Icon(Icons.warning_amber_rounded, size: 18),
                      if (x.stockQuantity <= x.lowStockThreshold) const SizedBox(width: 4),
                      Text(x.taxRate.toString() + '%'),
                    ])),
                    DataCell(Row(children: [
                      IconButton(tooltip: 'Edit product', onPressed: () => _edit(context, ref, item: x), icon: const Icon(Icons.edit_outlined)),
                      IconButton(tooltip: 'Deactivate product', onPressed: () => _deactivate(context, ref, x), icon: const Icon(Icons.archive_outlined)),
                    ])),
                  ])).toList(),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final x = filtered[i];
                final low = x.stockQuantity <= x.lowStockThreshold;
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Text(x.name.isEmpty ? '?' : x.name[0].toUpperCase())),
                  title: Text(x.name),
                  subtitle: Text((x.sku ?? 'No SKU') + ' • ' + x.stockQuantity.toString() + ' in stock' + (low ? ' • Low stock' : '')),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Product actions',
                    onSelected: (action) {
                      if (action == 'edit') _edit(context, ref, item: x);
                      if (action == 'deactivate') _deactivate(context, ref, x);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'deactivate', child: Text('Deactivate')),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ));
              },
            );
          },
        )),
      ]);
  }

  Widget _empty(BuildContext c, WidgetRef r, {bool searched = false}) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.inventory_2_outlined, size: 56), const SizedBox(height: 12),
    Text(searched ? 'No products match your search' : 'No active products'), const SizedBox(height: 12),
    FilledButton.icon(onPressed: () => _edit(c, r), icon: const Icon(Icons.add), label: const Text('Add product')),
  ]));

  Future<void> _edit(BuildContext context, WidgetRef ref, {Item? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final barcode = TextEditingController(text: item?.barcode ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final price = TextEditingController(text: item == null ? '' : (item.priceMinor / 100).toStringAsFixed(2));
    final tax = TextEditingController(text: item?.taxRate.toString() ?? '0');
    final stock = TextEditingController(text: item?.stockQuantity.toString() ?? '0');
    final lowStock = TextEditingController(text: item?.lowStockThreshold.toString() ?? '5');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item == null ? 'Add product' : 'Edit product'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: item == null, decoration: const InputDecoration(labelText: 'Product name')),
          const SizedBox(height: 10), TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU')),
          const SizedBox(height: 10), TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode')),
          const SizedBox(height: 10), TextField(controller: category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 10), TextField(controller: price, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price (₹)')),
          const SizedBox(height: 10), TextField(controller: tax, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Tax (%)')),
          const SizedBox(height: 10), TextField(controller: stock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Stock')),
          const SizedBox(height: 10), TextField(controller: lowStock, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Low-stock threshold')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    final priceRupees = double.tryParse(price.text) ?? 0;
    final taxRate = double.tryParse(tax.text) ?? 0;
    final stockValue = int.tryParse(stock.text) ?? 0;
    final threshold = int.tryParse(lowStock.text) ?? 5;
    if (priceRupees < 0 || taxRate < 0 || stockValue < 0 || threshold < 0) return;

    final now = DateTime.now();
    final id = item?.id ?? const Uuid().v4();
    final companion = item == null
      ? ItemsCompanion.insert(
          id: id, sku: Value(sku.text.trim().isEmpty ? null : sku.text.trim()),
          name: name.text.trim(), priceMinor: (priceRupees * 100).round(),
          taxRate: Value(taxRate), stockQuantity: Value(stockValue),
          lowStockThreshold: Value(threshold),
          category: Value(category.text.trim().isEmpty ? null : category.text.trim()),
          barcode: Value(barcode.text.trim().isEmpty ? null : barcode.text.trim()),
          createdAt: now, updatedAt: now)
      : ItemsCompanion(
          id: Value(id), sku: Value(sku.text.trim().isEmpty ? null : sku.text.trim()),
          name: Value(name.text.trim()), priceMinor: Value((priceRupees * 100).round()),
          taxRate: Value(taxRate), stockQuantity: Value(stockValue),
          lowStockThreshold: Value(threshold),
          category: Value(category.text.trim().isEmpty ? null : category.text.trim()),
          barcode: Value(barcode.text.trim().isEmpty ? null : barcode.text.trim()),
          updatedAt: Value(now), isActive: const Value(true));
    await ref.read(databaseProvider).saveItem(companion);
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Deactivate product?'),
        content: Text('“' + item.name + '” will disappear from active inventory but remain in historical invoices.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Deactivate')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(databaseProvider).saveItem(
      ItemsCompanion(id: Value(item.id), isActive: const Value(false), updatedAt: Value(DateTime.now())),
    );
  }
}
