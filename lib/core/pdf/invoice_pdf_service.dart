import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/app_database.dart';

/// Generates printable invoices using the same layout for print, save and share.
///
/// The built-in PDF fonts do not include the Indian Rupee glyph. Currency is
/// therefore deliberately rendered as "INR" rather than a missing-glyph box.
/// For other non-Latin scripts a bundled Unicode font must be configured before
/// those scripts can be rendered faithfully in a PDF.
class InvoicePdfService {
  final NumberFormat _amount = NumberFormat('#,##,##0.00', 'en_IN');
  final DateFormat _date = DateFormat('dd MMM yyyy, hh:mm a');

  String _money(int minor, String currencyCode) =>
      '${currencyCode.trim().isEmpty ? 'INR' : currencyCode.trim().toUpperCase()} ${_amount.format(minor / 100)}';

  String _safePdfText(String value) {
    return value
        .replaceAll('₹', 'INR ')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('•', '|')
        .replaceAll('×', 'x')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('\u00a0', ' ')
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .runes
        .map((rune) => rune <= 255 ? String.fromCharCode(rune) : '?')
        .join();
  }

  String _safeFilename(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-');
    return cleaned.isEmpty ? 'invoice' : cleaned;
  }

  Future<Uint8List> buildInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = true,
    bool showSku = true,
    bool thermal = false,
  }) async {
    final doc = pw.Document(
      title: _safePdfText('$invoiceTitle ${invoice.invoiceNumber}'),
      author: _safePdfText(shopName),
    );
    pw.MemoryImage? logo;
    if (showLogo) {
      try {
        final data = await rootBundle.load('assets/icon/sbill_icon.png');
        logo = pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        logo = null;
      }
    }

    final pageFormat = thermal
        ? PdfPageFormat(
            80 * PdfPageFormat.mm,
            280 * PdfPageFormat.mm,
            marginLeft: 4 * PdfPageFormat.mm,
            marginRight: 4 * PdfPageFormat.mm,
            marginTop: 5 * PdfPageFormat.mm,
            marginBottom: 5 * PdfPageFormat.mm,
          )
        : PdfPageFormat.a4;
    final margin = thermal ? 0.0 : 28.0;
    final bodyStyle = pw.TextStyle(fontSize: thermal ? 8 : 9);
    final headingStyle = pw.TextStyle(
      fontSize: thermal ? 13 : 22,
      fontWeight: pw.FontWeight.bold,
    );
    final money = (int value) => _money(value, currencyCode);
    final safeItems = items;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.all(margin),
        maxPages: 200,
        header: thermal
            ? null
            : (context) => pw.Container(
                  alignment: pw.Alignment.centerRight,
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(
                    _safePdfText(shopName),
                    style: pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
        footer: thermal
            ? null
            : (context) => pw.Container(
                  alignment: pw.Alignment.center,
                  padding: const pw.EdgeInsets.only(top: 8),
                  child: pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
        build: (context) => [
          if (logo != null)
            pw.Align(
              alignment: thermal ? pw.Alignment.center : pw.Alignment.centerLeft,
              child: pw.Image(logo, width: thermal ? 34 : 52, height: thermal ? 34 : 52),
            ),
          pw.Text(_safePdfText(shopName), style: headingStyle),
          if ((shopAddress ?? '').trim().isNotEmpty)
            pw.Text(_safePdfText(shopAddress!), style: bodyStyle),
          if ((phone ?? '').trim().isNotEmpty)
            pw.Text('Phone: ${_safePdfText(phone!)}', style: bodyStyle),
          if ((gstNumber ?? '').trim().isNotEmpty)
            pw.Text('GSTIN: ${_safePdfText(gstNumber!)}', style: bodyStyle),
          pw.SizedBox(height: thermal ? 5 : 16),
          pw.Divider(color: PdfColors.grey500),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(
                  _safePdfText(invoiceTitle.trim().isEmpty ? 'INVOICE' : invoiceTitle),
                  style: pw.TextStyle(
                    fontSize: thermal ? 10 : 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Invoice: ${_safePdfText(invoice.invoiceNumber)}', style: bodyStyle),
                  pw.Text(
                    invoice.gstSupplyType == 'interState' ? 'Supply: INTER-STATE' : 'Supply: INTRA-STATE',
                    style: bodyStyle,
                  ),
                  pw.Text(_date.format(invoice.createdAt.toLocal()), style: bodyStyle),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: thermal ? 5 : 12),
          pw.TableHelper.fromTextArray(
            headers: [
              'Item',
              if (showSku) 'SKU',
              'Qty',
              'Rate',
              'Tax',
              'Amount',
            ],
            data: safeItems.map((item) => [
              _safePdfText(item.itemNameSnapshot),
              if (showSku) _safePdfText(item.skuSnapshot ?? ''),
              item.quantity.toString(),
              money(item.unitPriceMinor),
              money(item.taxMinor),
              money(item.lineTotalMinor),
            ]).toList(),
            headerStyle: pw.TextStyle(
              fontSize: thermal ? 7 : 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: pw.TextStyle(fontSize: thermal ? 7 : 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.35),
            cellPadding: pw.EdgeInsets.symmetric(
              horizontal: thermal ? 2 : 5,
              vertical: thermal ? 3 : 5,
            ),
          ),
          pw.SizedBox(height: thermal ? 6 : 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Container(
              width: thermal ? double.infinity : 250,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _summaryRow('Subtotal', money(invoice.subtotalMinor), bodyStyle),
                  _summaryRow('Discount', '-${money(invoice.discountMinor)}', bodyStyle),
                  if (invoice.cgstMinor > 0)
                    _summaryRow('CGST', money(invoice.cgstMinor), bodyStyle),
                  if (invoice.sgstMinor > 0)
                    _summaryRow('SGST', money(invoice.sgstMinor), bodyStyle),
                  if (invoice.igstMinor > 0)
                    _summaryRow('IGST', money(invoice.igstMinor), bodyStyle),
                  if (invoice.cgstMinor == 0 &&
                      invoice.sgstMinor == 0 &&
                      invoice.igstMinor == 0)
                    _summaryRow('GST / Tax', money(invoice.taxMinor), bodyStyle),
                  pw.Divider(color: PdfColors.grey600),
                  _summaryRow(
                    'TOTAL',
                    money(invoice.totalMinor),
                    pw.TextStyle(
                      fontSize: thermal ? 10 : 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  _summaryRow(
                    'Payment',
                    _safePdfText(invoice.paymentMethod.toUpperCase()),
                    bodyStyle,
                  ),
                ],
              ),
            ),
          ),
          if ((termsText ?? '').trim().isNotEmpty) ...[
            pw.SizedBox(height: thermal ? 6 : 16),
            pw.Text('Terms & conditions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: thermal ? 8 : 10)),
            pw.Text(_safePdfText(termsText!.trim()), style: bodyStyle),
          ],
          pw.SizedBox(height: thermal ? 8 : 18),
          pw.Center(
            child: pw.Text(
              _safePdfText((footerText ?? '').trim().isEmpty
                  ? 'Thank you for your business.'
                  : footerText!.trim()),
              textAlign: pw.TextAlign.center,
              style: bodyStyle,
            ),
          ),
        ],
      ),
    );
    return doc.save();
  }

  pw.Widget _summaryRow(String label, String value, pw.TextStyle style) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(child: pw.Text(label, style: style)),
            pw.Text(value, style: style),
          ],
        ),
      );

  Future<Uint8List> buildA4({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = true,
    bool showSku = true,
  }) => buildInvoice(
    invoice: invoice,
    items: items,
    shopName: shopName,
    shopAddress: shopAddress,
    phone: phone,
    gstNumber: gstNumber,
    footerText: footerText,
    invoiceTitle: invoiceTitle,
    termsText: termsText,
    currencyCode: currencyCode,
    showLogo: showLogo,
    showSku: showSku,
  );

  Future<Uint8List> buildThermal({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = false,
    bool showSku = false,
  }) => buildInvoice(
    invoice: invoice,
    items: items,
    shopName: shopName,
    shopAddress: shopAddress,
    phone: phone,
    gstNumber: gstNumber,
    footerText: footerText,
    invoiceTitle: invoiceTitle,
    termsText: termsText,
    currencyCode: currencyCode,
    showLogo: showLogo,
    showSku: showSku,
    thermal: true,
  );

  Future<void> printInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = true,
    bool showSku = true,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice,
      items: items,
      shopName: shopName,
      shopAddress: shopAddress,
      phone: phone,
      gstNumber: gstNumber,
      footerText: footerText,
      invoiceTitle: invoiceTitle,
      termsText: termsText,
      currencyCode: currencyCode,
      showLogo: showLogo,
      showSku: showSku,
      thermal: thermal,
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
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = true,
    bool showSku = true,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice,
      items: items,
      shopName: shopName,
      shopAddress: shopAddress,
      phone: phone,
      gstNumber: gstNumber,
      footerText: footerText,
      invoiceTitle: invoiceTitle,
      termsText: termsText,
      currencyCode: currencyCode,
      showLogo: showLogo,
      showSku: showSku,
      thermal: thermal,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_safeFilename(invoice.invoiceNumber)}.pdf',
    );
  }

  Future<File> saveInvoice({
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String shopName,
    String? shopAddress,
    String? phone,
    String? gstNumber,
    String? footerText,
    String invoiceTitle = 'TAX INVOICE',
    String? termsText,
    String currencyCode = 'INR',
    bool showLogo = true,
    bool showSku = true,
    bool thermal = false,
  }) async {
    final bytes = await buildInvoice(
      invoice: invoice,
      items: items,
      shopName: shopName,
      shopAddress: shopAddress,
      phone: phone,
      gstNumber: gstNumber,
      footerText: footerText,
      invoiceTitle: invoiceTitle,
      termsText: termsText,
      currencyCode: currencyCode,
      showLogo: showLogo,
      showSku: showSku,
      thermal: thermal,
    );
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, '${_safeFilename(invoice.invoiceNumber)}.pdf'));
    return file.writeAsBytes(bytes, flush: true);
  }
}
