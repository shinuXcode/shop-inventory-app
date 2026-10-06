import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app.dart';
import '../../core/database/app_database.dart';
import '../migration/migration.dart';

final itemsProvider = StreamProvider.autoDispose<List<Item>>(
  (ref) => ref.watch(databaseProvider).watchActiveItems(),
);

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
    final items = ref.watch(itemsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            tooltip: 'Import products',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MigrationPage()),
            ),
            icon: const Icon(Icons.file_download_outlined),
          ),
          IconButton(
            tooltip: 'Add product',
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Could not load inventory: $error'),
        ),
        data: (list) {
          final query = search.text.trim().toLowerCase();
          final filtered = query.isEmpty
              ? list
              : list.where((item) {
                  return item.name.toLowerCase().contains(query) ||
                      (item.sku ?? '').toLowerCase().contains(query) ||
                      (item.barcode ?? '').toLowerCase().contains(query) ||
                      (item.category ?? '').toLowerCase().contains(query);
                }).toList();

          final lowStock = filtered.where(
            (item) => item.stockQuantity <= item.lowStockThreshold,
          ).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: search,
                      onChanged: (_) => setState(() {}),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText:
                            'Search product, SKU, barcode or category',
                        suffixIcon: search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  search.clear();
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close),
                              ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryChip(
                            label: '${filtered.length} products',
                            icon: Icons.inventory_2_outlined,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SummaryChip(
                            label: '${lowStock} low stock',
                            icon: Icons.warning_amber_rounded,
                            emphasis: lowStock > 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? _empty(context, searched: query.isNotEmpty)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth >= 1100) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                16,
                              ),
                              child: Card(
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Product')),
                                    DataColumn(label: Text('SKU')),
                                    DataColumn(label: Text('Price')),
                                    DataColumn(label: Text('Stock')),
                                    DataColumn(label: Text('Tax')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: filtered.map((item) {
                                    final low = item.stockQuantity <=
                                        item.lowStockThreshold;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(
                                            item.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        DataCell(Text(item.sku ?? '—')),
                                        DataCell(
                                          Text(
                                            '₹${(item.priceMinor / 100).toStringAsFixed(2)}',
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Text(
                                                item.stockQuantity.toString(),
                                              ),
                                              if (low) ...[
                                                const SizedBox(width: 6),
                                                const Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 18,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            '${item.taxRate.toStringAsFixed(2)}%',
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit product',
                                                onPressed: () =>
                                                    _edit(context, item: item),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip:
                                                    'Archive product',
                                                onPressed: () => _deactivate(
                                                  context,
                                                  item,
                                                ),
                                                icon: const Icon(
                                                  Icons.archive_outlined,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, index) {
                              final item = filtered[index];
                              final low = item.stockQuantity <=
                                  item.lowStockThreshold;
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      item.name.isEmpty
                                          ? '?'
                                          : item.name[0].toUpperCase(),
                                    ),
                                  ),
                                  title: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${item.sku ?? 'No SKU'} • ${item.stockQuantity} in stock'
                                    '${low ? ' • Low stock' : ''}',
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Product actions',
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        _edit(context, item: item);
                                      } else if (action == 'deactivate') {
                                        _deactivate(context, item);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'deactivate',
                                        child: Text('Archive'),
                                      ),
                                    ],
                                    icon:
                                        const Icon(Icons.more_vert),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Product'),
      ),
    );
  }

  Widget _empty(BuildContext context, {required bool searched}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searched
                  ? Icons.search_off_outlined
                  : Icons.inventory_2_outlined,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              searched
                  ? 'No products match your search'
                  : 'No active products',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (!searched)
              FilledButton.icon(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add),
                label: const Text('Add product'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, {Item? item}) async {
    final name = TextEditingController(text: item?.name ?? '');
    final sku = TextEditingController(text: item?.sku ?? '');
    final barcode = TextEditingController(text: item?.barcode ?? '');
    final category = TextEditingController(text: item?.category ?? '');
    final price = TextEditingController(
      text: item == null ? '' : (item.priceMinor / 100).toStringAsFixed(2),
    );
    final tax = TextEditingController(text: item?.taxRate.toString() ?? '0');
    final stock =
        TextEditingController(text: item?.stockQuantity.toString() ?? '0');
    final lowStock = TextEditingController(
      text: item?.lowStockThreshold.toString() ?? '5',
    );

    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(item == null ? 'Add product' : 'Edit product'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: item == null,
                    decoration:
                        const InputDecoration(labelText: 'Product name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sku,
                    decoration: const InputDecoration(labelText: 'SKU'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: barcode,
                    decoration: const InputDecoration(labelText: 'Barcode'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: category,
                    decoration:
                        const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Price (₹)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tax,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tax (%)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stock,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: lowStock,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Low-stock threshold',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (ok != true || name.text.trim().isEmpty) return;

      final priceText = price.text.trim();
      final taxText = tax.text.trim();
      final stockText = stock.text.trim();
      final thresholdText = lowStock.text.trim();
      final priceRupees = double.tryParse(priceText);
      final taxRate = double.tryParse(taxText);
      final stockValue = int.tryParse(stockText);
      final threshold = int.tryParse(thresholdText);

      if (priceRupees == null || !priceRupees.isFinite ||
          taxRate == null || !taxRate.isFinite ||
          stockValue == null || threshold == null ||
          priceRupees < 0 || taxRate < 0 || taxRate > 100 ||
          stockValue < 0 || threshold < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter valid non-negative values. Tax must be between 0 and 100%.')),
          );
        }
        return;
      }

      final normalizedSku = sku.text.trim();
      final normalizedBarcode = barcode.text.trim();
      final duplicate = await ref.read(databaseProvider).findItemConflict(
        sku: normalizedSku,
        barcode: normalizedBarcode,
        excludingId: item?.id,
      );
      if (duplicate != null) {
        final reason = normalizedSku.isNotEmpty &&
                duplicate.sku?.trim().toLowerCase() == normalizedSku.toLowerCase()
            ? 'SKU'
            : 'barcode';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('That $reason is already used by “${duplicate.name}”. Choose a unique value.')),
        );
        return;
      }

      final now = DateTime.now();
      final id = item?.id ?? const Uuid().v4();
      final companion = item == null
          ? ItemsCompanion.insert(
              id: id,
              sku: Value(
                sku.text.trim().isEmpty ? null : sku.text.trim(),
              ),
              name: name.text.trim(),
              priceMinor: (priceRupees * 100).round(),
              taxRate: Value(taxRate),
              stockQuantity: Value(stockValue),
              lowStockThreshold: Value(threshold),
              category: Value(
                category.text.trim().isEmpty
                    ? null
                    : category.text.trim(),
              ),
              barcode: Value(
                barcode.text.trim().isEmpty
                    ? null
                    : barcode.text.trim(),
              ),
              createdAt: now,
              updatedAt: now,
            )
          : ItemsCompanion(
              id: Value(id),
              sku: Value(
                sku.text.trim().isEmpty ? null : sku.text.trim(),
              ),
              name: Value(name.text.trim()),
              priceMinor: Value((priceRupees * 100).round()),
              taxRate: Value(taxRate),
              stockQuantity: Value(stockValue),
              lowStockThreshold: Value(threshold),
              category: Value(
                category.text.trim().isEmpty
                    ? null
                    : category.text.trim(),
              ),
              barcode: Value(
                barcode.text.trim().isEmpty
                    ? null
                    : barcode.text.trim(),
              ),
              updatedAt: Value(now),
              isActive: const Value(true),
            );

      await ref.read(databaseProvider).saveItem(companion);
    } finally {
      name.dispose();
      sku.dispose();
      barcode.dispose();
      category.dispose();
      price.dispose();
      tax.dispose();
      stock.dispose();
      lowStock.dispose();
    }
  }

  Future<void> _deactivate(BuildContext context, Item item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive product?'),
        content: Text(
          '“${item.name}” will disappear from active inventory but remain '
          'in historical invoices.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(databaseProvider).saveItem(
          ItemsCompanion(
            id: Value(item.id),
            isActive: const Value(false),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.icon,
    this.emphasis = false,
  });

  final String label;
  final IconData icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: emphasis
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
