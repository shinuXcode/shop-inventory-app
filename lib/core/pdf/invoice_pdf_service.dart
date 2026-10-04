import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';

class InvoicePdfService {
  String _money(int minor) => '₹' + (minor / 100).toStringAsFixed(2);

  Future<Uint8List> buildInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    bool thermal = false,
  }) async {
    final doc = pw.Document();
    final pageFormat = thermal
        ? PdfPageFormat(80 * PdfPageFormat.mm, 280 * PdfPageFormat.mm,
            marginLeft: 4 * PdfPageFormat.mm,
            marginRight: 4 * PdfPageFormat.mm,
            marginTop: 5 * PdfPageFormat.mm,
            marginBottom: 5 * PdfPageFormat.mm)
        : PdfPageFormat.a4;

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => thermal
            ? _thermalPage(invoice, items, shopName, shopAddress, phone, gstNumber)
            : _a4Page(invoice, items, shopName, shopAddress, phone, gstNumber),
      ),
    );
    return doc.save();
  }

  pw.Widget _a4Page(
    Invoice invoice,
    List<InvoiceItem> items,
    String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
  ) => pw.Padding(
    padding: const pw.EdgeInsets.all(28),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      if ((shopAddress ?? '').isNotEmpty) pw.Text(shopAddress!),
      if ((phone ?? '').isNotEmpty) pw.Text(phone!),
      if ((gstNumber ?? '').isNotEmpty) pw.Text('GSTIN: ' + gstNumber!),
      pw.SizedBox(height: 20),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('TAX INVOICE', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Invoice ' + invoice.invoiceNumber),
          pw.Text(invoice.createdAt.toLocal().toString()),
        ]),
      ]),
      pw.SizedBox(height: 18),
      pw.Table.fromTextArray(
        headers: const ['Item', 'Qty', 'Unit', 'Tax', 'Total'],
        data: items.map((x) => [
          x.itemNameSnapshot,
          x.quantity.toString(),
          _money(x.unitPriceMinor),
          _money(x.taxMinor),
          _money(x.lineTotalMinor),
        ]).toList(),
      ),
      pw.SizedBox(height: 16),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Subtotal  ' + _money(invoice.subtotalMinor)),
          pw.Text('Discount  -' + _money(invoice.discountMinor)),
          pw.Text('Tax  ' + _money(invoice.taxMinor)),
          pw.SizedBox(height: 6),
          pw.Text(
            'TOTAL  ' + _money(invoice.totalMinor),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Payment: ' + invoice.paymentMethod.toUpperCase()),
        ]),
      ),
      pw.Spacer(),
      pw.Center(child: pw.Text('Thank you for your business.')),
    ]),
  );

  pw.Widget _thermalPage(
    Invoice invoice,
    List<InvoiceItem> items,
    String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
  ) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    if ((shopAddress ?? '').isNotEmpty) pw.Text(shopAddress!, textAlign: pw.TextAlign.center),
    if ((phone ?? '').isNotEmpty) pw.Text(phone!),
    if ((gstNumber ?? '').isNotEmpty) pw.Text('GSTIN: ' + gstNumber!),
    pw.Divider(),
    pw.Text('INVOICE ' + invoice.invoiceNumber, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    pw.Text(invoice.createdAt.toLocal().toString()),
    pw.Divider(),
    ...items.map((x) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(x.itemNameSnapshot, maxLines: 2)),
        pw.Text(x.quantity.toString() + ' x ' + _money(x.unitPriceMinor)),
        pw.SizedBox(width: 4),
        pw.Text(_money(x.lineTotalMinor)),
      ]),
    )),
    pw.Divider(),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Subtotal'), pw.Text(_money(invoice.subtotalMinor)),
    ]),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Discount'), pw.Text('-' + _money(invoice.discountMinor)),
    ]),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Tax'), pw.Text(_money(invoice.taxMinor)),
    ]),
    pw.SizedBox(height: 4),
    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('TOTAL', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.Text(_money(invoice.totalMinor), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
    ]),
    pw.SizedBox(height: 4),
    pw.Text('Payment: ' + invoice.paymentMethod.toUpperCase()),
    pw.SizedBox(height: 8),
    pw.Text('Thank you.'),
  ]);

  Future<Uint8List> buildA4({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
  }) => buildInvoice(
    invoice: invoice, items: items, shopName: shopName, shopAddress: shopAddress,
    phone: phone, gstNumber: gstNumber, thermal: false,
  );

  Future<Uint8List> buildThermal({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
  }) => buildInvoice(
    invoice: invoice, items: items, shopName: shopName, shopAddress: shopAddress,
    phone: phone, gstNumber: gstNumber, thermal: true,
  );

  Future<void> printInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice, items: items, shopName: shopName, shopAddress: shopAddress,
      phone: phone, gstNumber: gstNumber, thermal: thermal,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> shareInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice, items: items, shopName: shopName, shopAddress: shopAddress,
      phone: phone, gstNumber: gstNumber, thermal: thermal,
    );
    await Printing.sharePdf(bytes: bytes, filename: invoice.invoiceNumber + '.pdf');
  }

  Future<File> saveInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice, items: items, shopName: shopName, shopAddress: shopAddress,
      phone: phone, gstNumber: gstNumber, thermal: thermal,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, invoice.invoiceNumber + '.pdf'));
    return file.writeAsBytes(bytes, flush: true);
  }
}
