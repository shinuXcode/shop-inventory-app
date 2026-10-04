import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';

class InvoicePdfService {
  Future<Uint8List> buildInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
  }) async {
    final doc = pw.Document();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Padding(
        padding: const pw.EdgeInsets.all(28),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          if (shopAddress != null) pw.Text(shopAddress),
          if (phone != null) pw.Text(phone),
          pw.SizedBox(height: 20),
          pw.Text('Invoice ' + invoice.invoiceNumber, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text(invoice.createdAt.toString()),
          pw.SizedBox(height: 18),
          pw.Table.fromTextArray(
            headers: const ['Item', 'Qty', 'Unit', 'Tax', 'Total'],
            data: items.map((x) => [
              x.itemNameSnapshot,
              x.quantity.toString(),
              '₹' + (x.unitPriceMinor / 100).toStringAsFixed(2),
              '₹' + (x.taxMinor / 100).toStringAsFixed(2),
              '₹' + (x.lineTotalMinor / 100).toStringAsFixed(2),
            ]).toList(),
          ),
          pw.Spacer(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(
            'TOTAL  ₹' + (invoice.totalMinor / 100).toStringAsFixed(2),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text('Payment: ' + invoice.paymentMethod),
        ]),
      ),
    ));
    return doc.save();
  }

  Future<void> printInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice, items: items, shopName: shopName,
      shopAddress: shopAddress, phone: phone);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
