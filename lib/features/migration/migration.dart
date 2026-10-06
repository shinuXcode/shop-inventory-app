import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/data/data_transfer_service.dart';

class MigrationPage extends ConsumerStatefulWidget {
  const MigrationPage({super.key});

  @override
  ConsumerState<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends ConsumerState<MigrationPage> {
  ImportPreview? preview;
  int duplicateCount = 0;
  bool busy = false;

  Future<void> _pick() async {
    setState(() => busy = true);
    try {
      final value = await DataTransferService.pick();
      if (!mounted) return;
      setState(() {
        preview = value;
        duplicateCount = 0;
      });
      if (value != null) await _countDuplicates(value);
      if (value != null && value.isValid && value.kind == 'unknown') {
        _message('Could not determine the file type. Use a header row with product or customer fields.');
      }
    } catch (e) {
      _message('Import file could not be opened: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _countDuplicates(ImportPreview value) async {
    final db = ref.read(databaseProvider);
    var count = 0;

    if (value.kind == 'backup') {
      final items = await db.activeItemsForExport();
      final customers = await db.getCustomers();
      final invoices = await db.recentInvoices(limit: 1000000);
      final itemIds = items.map((x) => x.id).toSet();
      final customerIds = customers.map((x) => x.id).toSet();
      final invoiceIds = invoices.map((x) => x.id).toSet();
      final snapshot = value.snapshot ?? const <String, dynamic>{};
      count += ((snapshot['items'] as List?)?.whereType<Map>().where((x) => itemIds.contains(x['id']?.toString())).length ?? 0);
      count += ((snapshot['customers'] as List?)?.whereType<Map>().where((x) => customerIds.contains(x['id']?.toString())).length ?? 0);
      count += ((snapshot['invoices'] as List?)?.whereType<Map>().where((x) => invoiceIds.contains(x['id']?.toString())).length ?? 0);
    } else if (value.kind == 'products') {
      final existing = await db.activeItemsForExport();
      final sku = <String>{};
      final barcode = <String>{};
      final names = <String>{};
      for (final item in existing) {
        final itemSku = (item.sku ?? '').trim();
        final itemBarcode = (item.barcode ?? '').trim();
        if (itemSku.isNotEmpty) sku.add(itemSku.toLowerCase());
        if (itemBarcode.isNotEmpty) barcode.add(itemBarcode);
        if (item.name.trim().isNotEmpty) names.add(item.name.trim().toLowerCase());
      }
      for (final row in value.rows) {
        final rowSku = (row['sku'] ?? row['code'] ?? '').trim().toLowerCase();
        final rowBarcode = (row['barcode'] ?? row['bar_code'] ?? '').trim();
        final rowName = (row['name'] ?? '').trim().toLowerCase();
        if ((rowSku.isNotEmpty && sku.contains(rowSku)) ||
            (rowBarcode.isNotEmpty && barcode.contains(rowBarcode)) ||
            (rowName.isNotEmpty && names.contains(rowName))) {
          count++;
        }
      }
    } else if (value.kind == 'customers') {
      final existing = await db.getCustomers();
      final phones = <String>{};
      final emails = <String>{};
      final names = <String>{};
      for (final customer in existing) {
        final customerPhone = (customer.phone ?? '').trim();
        final customerEmail = (customer.email ?? '').trim();
        if (customerPhone.isNotEmpty) phones.add(customerPhone);
        if (customerEmail.isNotEmpty) emails.add(customerEmail.toLowerCase());
        if (customer.name.trim().isNotEmpty) names.add(customer.name.trim().toLowerCase());
      }
      for (final row in value.rows) {
        final rowPhone = (row['phone'] ?? row['mobile'] ?? row['contact'] ?? '').trim();
        final rowEmail = (row['email'] ?? row['email_address'] ?? '').trim().toLowerCase();
        final rowName = (row['name'] ?? row['customer'] ?? row['customer_name'] ?? '').trim().toLowerCase();
        if ((rowPhone.isNotEmpty && phones.contains(rowPhone)) ||
            (rowEmail.isNotEmpty && emails.contains(rowEmail)) ||
            (rowName.isNotEmpty && names.contains(rowName))) {
          count++;
        }
      }
    }

    if (mounted) setState(() => duplicateCount = count);
  }

  Future<void> _import() async {
    final current = preview;
    if (current == null || !current.isValid) return;
    setState(() => busy = true);
    try {
      final count = await DataTransferService.importPreview(ref.read(databaseProvider), current);
      if (!mounted) return;
      _message('Imported ' + count.toString() + ' records into SBILL.');
      setState(() => preview = null);
    } catch (e) {
      _message('Import failed: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _export(String exportType) async {
    setState(() => busy = true);
    try {
      final db = ref.read(databaseProvider);
      final File file = switch (exportType) {
        'backup' => await DataTransferService.exportBackup(db),
        'products' => await DataTransferService.exportProducts(db),
        _ => await DataTransferService.exportCustomers(db),
      };
      final label = exportType == 'backup' ? 'backup' : exportType;
      await DataTransferService.shareFile(file, text: 'SBILL ' + label + ' export');
    } catch (e) {
      _message('Export failed: ' + e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final current = preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration Center'),
        actions: [
          if (current != null)
            IconButton(
              tooltip: 'Choose another file',
              onPressed: busy ? null : _pick,
              icon: const Icon(Icons.swap_horiz_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.move_to_inbox_outlined, size: 36, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Migration Center', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Import your products and customers before making your first bill. SBILL keeps the imported data local first.'),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: busy ? null : _pick,
                          icon: busy
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.upload_file_outlined),
                          label: const Text('Choose CSV / JSON / TXT'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (current != null) _previewCard(current),
          const SizedBox(height: 14),
          Text('Export', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _exportButton('Full SBILL backup', Icons.backup_outlined, 'backup'),
              _exportButton('Products CSV', Icons.inventory_2_outlined, 'products'),
              _exportButton('Customers CSV', Icons.people_outline, 'customers'),
            ],
          ),
          const SizedBox(height: 18),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Best migration path'),
              subtitle: Text(
                'Export products/customers as CSV from your old app, preview them here, then import. For SBILL-to-SBILL moves, use the full backup JSON.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard(ImportPreview value) {
    final count = value.kind == 'backup' ? _backupCount(value.snapshot) : value.rows.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(value.isValid ? Icons.check_circle_outline : Icons.error_outline),
                const SizedBox(width: 8),
                Expanded(child: Text(value.fileName, style: const TextStyle(fontWeight: FontWeight.w700))),
                Chip(label: Text(value.label)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value.isValid ? count.toString() + ' records ready to import' : value.error!),
            if (value.validationErrors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                value.validationErrors.length.toString() + ' validation error(s) detected.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...value.validationErrors.take(6).map(
                (error) => Text('• ' + error, style: Theme.of(context).textTheme.bodySmall),
              ),
              if (value.validationErrors.length > 6)
                Text('… and ' + (value.validationErrors.length - 6).toString() + ' more.', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (value.isValid && value.kind != 'backup' && value.rows.isNotEmpty) ...[

              const SizedBox(height: 8),
              Text(
                duplicateCount == 0
                    ? 'No matching records found in the current database.'
                    : duplicateCount.toString() + ' potential duplicate(s) detected. Existing matches will be skipped; no existing data will be overwritten.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Detected fields: ' + value.rows.first.keys.take(8).join(', '),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (value.kind == 'backup' && value.isValid) ...[
              const SizedBox(height: 8),
              Text(
                duplicateCount == 0
                    ? 'No matching backup records found in the current database.'
                    : duplicateCount.toString() + ' backup record(s) already exist and will be skipped.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (value.rows.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...value.rows.take(5).map(
                (row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    row.entries.take(4).map((e) => e.key + ': ' + e.value).join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            if (value.isValid) ...[
              const SizedBox(height: 14),
              if (value.validationErrors.isEmpty)
                FilledButton.icon(
                  onPressed: busy || value.kind == 'unknown' ? null : _import,
                  icon: const Icon(Icons.download_done_outlined),
                  label: const Text('Import valid records'),
                )
              else
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.error_outline),
                  label: Text(
                    'Fix ' + value.validationErrors.length.toString() + ' validation error(s) first',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _exportButton(String label, IconData icon, String exportType) =>
      OutlinedButton.icon(
        onPressed: busy ? null : () => _export(exportType),
        icon: Icon(icon),
        label: Text(label),
      );

  int _backupCount(Map<String, dynamic>? snapshot) {
    if (snapshot == null) return 0;
    return ['items', 'customers', 'invoices'].fold<int>(
      0,
      (sum, key) => sum + ((snapshot[key] as List?)?.length ?? 0),
    );
  }
}
