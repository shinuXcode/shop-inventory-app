import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
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
  });

  final String fileName;
  final String kind;
  final List<Map<String, String>> rows;
  final Map<String, dynamic>? snapshot;
  final String? error;

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
    final bytes = picked.bytes ?? await File(picked.path!).readAsBytes();
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
          );
        }
        final rows = _rowsFromJson(decoded);
        return ImportPreview(
          fileName: fileName,
          kind: _inferKind(rows),
          rows: rows,
          error: rows.isEmpty ? 'No importable rows were found.' : null,
        );
      }
      final rows = parseDelimited(text);
      return ImportPreview(
        fileName: fileName,
        kind: _inferKind(rows),
        rows: rows,
        error: rows.isEmpty ? 'No importable rows were found.' : null,
      );
    } catch (e) {
      return ImportPreview(
        fileName: fileName,
        kind: 'unknown',
        rows: const [],
        error: 'Could not read file: ' + e.toString(),
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
