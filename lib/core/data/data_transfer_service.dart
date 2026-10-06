import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database.dart';

class ImportPreview {
  const ImportPreview({
    required this.fileName,
    required this.kind,
    required this.rows,
    this.snapshot,
    this.error,
    this.validationErrors = const [],
  });

  final String fileName;
  final String kind;
  final List<Map<String, String>> rows;
  final Map<String, dynamic>? snapshot;
  final String? error;
  final List<String> validationErrors;

  bool get isValid => error == null;
  String get label => switch (kind) {
    'backup' => 'SBILL backup',
    'products' => 'Products',
    'customers' => 'Customers',
    _ => 'Unknown data',
  };
}

class DataTransferService {
  static Future<ImportPreview?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'json', 'txt'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final picked = result.files.first;
    final bytes = await picked.readAsBytes();
    return parseFile(picked.name, bytes);
  }

  static ImportPreview parseFile(String fileName, List<int> bytes) {
    try {
      final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\uFEFF', '');
      if (p.extension(fileName).toLowerCase() == '.json') {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic> &&
            decoded['format'] == 'sbill-backup-v1') {
          return ImportPreview(
            fileName: fileName,
            kind: 'backup',
            rows: const [],
            snapshot: decoded,
            validationErrors: _validateBackup(decoded),
          );
        }
        final rows = _rowsFromJson(decoded);
        final kind = _inferKind(rows);
        final validationErrors = _validateRows(kind, rows);
        return ImportPreview(
          fileName: fileName,
          kind: kind,
          rows: rows,
          error: rows.isEmpty
              ? 'No importable rows were found.'
              : kind == 'unknown'
                  ? 'We could not identify product or customer columns.'
                  : null,
          validationErrors: validationErrors,
        );
      }
      final rows = parseDelimited(text);
      final kind = _inferKind(rows);
      final validationErrors = _validateRows(kind, rows);
      return ImportPreview(
        fileName: fileName,
        kind: kind,
        rows: rows,
        error: rows.isEmpty
            ? 'No importable rows were found.'
            : kind == 'unknown'
                ? 'We could not identify product or customer columns.'
                : null,
        validationErrors: validationErrors,
      );
    } catch (e) {
      return ImportPreview(
        fileName: fileName,
        kind: 'unknown',
        rows: const [],
        error: 'We could not read that file. Check the file format and try again.',
      );
    }
  }

  static List<Map<String, String>> parseDelimited(String text) {
    final records = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;

    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (quoted) {
        if (ch == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(ch);
        }
      } else if (ch == '"') {
        quoted = true;
      } else if (ch == ',' || ch == '\t' || ch == '|') {
        row.add(cell.toString().trim());
        cell = StringBuffer();
      } else if (ch == '\n' || ch == '\r') {
        if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(cell.toString().trim());
        cell = StringBuffer();
        if (row.any((value) => value.isNotEmpty)) records.add(row);
        row = <String>[];
      } else {
        cell.write(ch);
      }
    }
    row.add(cell.toString().trim());
    if (row.any((value) => value.isNotEmpty)) records.add(row);
    if (records.length < 2) return const [];

    final headers = records.first
        .map((value) => value.trim().toLowerCase().replaceAll(' ', '_'))
        .toList();
    return records.skip(1).map((values) {
      final mapped = <String, String>{};
      for (var i = 0; i < headers.length && i < values.length; i++) {
        mapped[headers[i]] = values[i].trim();
      }
      return mapped;
    }).where((row) => row.values.any((value) => value.isNotEmpty)).toList();
  }

  static Future<int> importPreview(AppDatabase db, ImportPreview preview) async {
    if (!preview.isValid) throw StateError(preview.error ?? 'Invalid import');
    if (preview.validationErrors.isNotEmpty) {
      throw StateError('Please fix the validation errors shown in the preview before importing.');
    }
    if (preview.kind == 'backup' && preview.snapshot != null) {
      return db.importSnapshot(preview.snapshot!);
    }
    if (preview.kind == 'products') return db.importProductRows(preview.rows);
    if (preview.kind == 'customers') return db.importCustomerRows(preview.rows);
    throw StateError('Could not determine whether this file contains products or customers.');
  }

  static Future<File> exportBackup(AppDatabase db) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(
      dir.path,
      'sbill-backup-' + DateTime.now().millisecondsSinceEpoch.toString() + '.json',
    ));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(await db.exportSnapshot()),
    );
    return file;
  }

  static Future<File> exportProducts(AppDatabase db) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'sbill-products.csv'));
    final items = await db.activeItemsForExport();
    final lines = <String>[
      'name,sku,barcode,category,price,tax,stock,low_stock_threshold',
      ...items.map((x) => _csv([
        x.name,
        x.sku ?? '',
        x.barcode ?? '',
        x.category ?? '',
        (x.priceMinor / 100).toStringAsFixed(2),
        x.taxRate.toString(),
        x.stockQuantity.toString(),
        x.lowStockThreshold.toString(),
      ])),
    ];
    await file.writeAsString(lines.join('\n'));
    return file;
  }

  static Future<File> exportCustomers(AppDatabase db) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'sbill-customers.csv'));
    final customers = await db.getCustomers();
    final lines = <String>[
      'name,phone,email,address,notes',
      ...customers.map((x) => _csv([
        x.name,
        x.phone ?? '',
        x.email ?? '',
        x.address ?? '',
        x.notes ?? '',
      ])),
    ];
    await file.writeAsString(lines.join('\n'));
    return file;
  }

  static Future<void> shareFile(File file, {String? text}) async {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [XFile(file.path)],
      ),
    );
  }

  static List<Map<String, String>> _rowsFromJson(Object? decoded) {
    if (decoded is List) {
      return decoded.whereType<Map>().map(_normalizeMap).toList();
    }
    if (decoded is Map) {
      for (final key in const ['products', 'items', 'customers', 'data']) {
        final value = decoded[key];
        if (value is List) {
          return value.whereType<Map>().map(_normalizeMap).toList();
        }
      }
    }
    return const [];
  }

  static List<String> _validateRows(String kind, List<Map<String, String>> rows) {
    final errors = <String>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final number = i + 2;
      if (kind == 'products') {
        final name = _rowValue(row, const ['name', 'product', 'product_name', 'item_name']);
        if (name.isEmpty) {
          errors.add('Row ' + number.toString() + ': product name is missing.');
          continue;
        }
        final priceText = _rowValue(row, const ['price', 'price_rupees', 'selling_price', 'rate']);
        final taxText = _rowValue(row, const ['tax', 'tax_rate', 'gst']);
        final stockText = _rowValue(row, const ['stock', 'quantity', 'stock_quantity']);
        final price = double.tryParse(priceText.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        final tax = double.tryParse(taxText.replaceAll(RegExp(r'[^0-9.\-]'), ''));
        final stock = int.tryParse(stockText.isEmpty ? '0' : stockText);
        if (price == null || !price.isFinite || price < 0) errors.add('Row ' + number.toString() + ': price must be a valid non-negative number.');
        if (tax == null || !tax.isFinite || tax < 0 || tax > 100) errors.add('Row ' + number.toString() + ': tax must be between 0 and 100%.');
        if (stock == null || stock < 0) errors.add('Row ' + number.toString() + ': stock must be a non-negative integer.');
      } else if (kind == 'customers') {
        final name = _rowValue(row, const ['name', 'customer', 'customer_name']);
        if (name.isEmpty) errors.add('Row ' + number.toString() + ': customer name is missing.');
      }
    }
    return errors;
  }

  static List<String> _validateBackup(Map<String, dynamic> snapshot) {
    final errors = <String>[];
    final items = (snapshot['items'] as List?)?.whereType<Map>().toList() ?? const [];
    final customers = (snapshot['customers'] as List?)?.whereType<Map>().toList() ?? const [];
    for (var i = 0; i < items.length; i++) {
      if ((items[i]['id']?.toString().trim() ?? '').isEmpty || (items[i]['name']?.toString().trim() ?? '').isEmpty) {
        errors.add('Backup product row ' + (i + 1).toString() + ': required identity is missing.');
      }
    }
    for (var i = 0; i < customers.length; i++) {
      if ((customers[i]['id']?.toString().trim() ?? '').isEmpty || (customers[i]['name']?.toString().trim() ?? '').isEmpty) {
        errors.add('Backup customer row ' + (i + 1).toString() + ': required identity is missing.');
      }
    }
    return errors;
  }

  static String _rowValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  static Map<String, String> _normalizeMap(Map value) => value.map(
    (key, value) => MapEntry(
      key.toString().trim().toLowerCase().replaceAll(' ', '_'),
      value?.toString().trim() ?? '',
    ),
  );

  static String _inferKind(List<Map<String, String>> rows) {
    if (rows.isEmpty) return 'unknown';
    final keys = rows.first.keys.toSet();
    if (keys.contains('name') &&
        (keys.contains('price') ||
         keys.contains('price_rupees') ||
         keys.contains('stock'))) {
      return 'products';
    }
    if (keys.contains('name') &&
        (keys.contains('phone') ||
         keys.contains('email') ||
         keys.contains('address'))) {
      return 'customers';
    }
    return 'unknown';
  }

  static String _csv(List<String> values) => values.map((value) {
    final escaped = value.replaceAll('"', '""');
    return '"' + escaped + '"';
  }).join(',');
}
