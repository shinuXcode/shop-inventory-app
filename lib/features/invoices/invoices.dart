import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../app.dart';
import '../../core/pdf/invoice_pdf_service.dart';
import '../../core/billing/money_formatter.dart';
import '../../core/settings/app_settings.dart';
import '../../core/database/app_database.dart';
import '../../core/widgets/user_facing_error.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});
  @override ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  late Future<List<Invoice>> future;
  final pdf = InvoicePdfService();
  String currencyCode = 'INR';

  @override
  void initState() {
    super.initState();
    future = ref.read(databaseProvider).recentInvoices(limit: 100);
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final code = AppSettings(prefs).currency;
    if (mounted) setState(() => currencyCode = code);
  }

  void refresh() => setState(() => future = ref.read(databaseProvider).recentInvoices(limit: 100));

  String money(int minor) => MoneyFormatter.format(minor, currencyCode: currencyCode);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Invoices'),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: refresh,
          icon: const Icon(Icons.refresh_outlined),
        ),
      ],
    ),
    body: FutureBuilder<List<Invoice>>(
      future: future,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) return Center(child: Text(userFacingError(s.error, fallback: 'Invoices are temporarily unavailable. Please try again.')));
        final list = s.data ?? const <Invoice>[];
        if (list.isEmpty) return const Center(child: Text('No invoices yet.'));
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final x = list[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(x.invoiceNumber),
                subtitle: Text(
                  x.paymentMethod.toUpperCase() + ' • ' + x.createdAt.toLocal().toString(),
                ),
                trailing: Text(
                  money(x.totalMinor),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                onTap: () => _details(x),
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _details(Invoice invoice) async {
    final db = ref.read(databaseProvider);
    final items = await db.invoiceItemsFor(invoice.id);
    final customer = invoice.customerId == null ? null : await db.customerById(invoice.customerId!);
    final payments = invoice.customerId == null
        ? <CustomerPayment>[]
        : (await db.customerPaymentsFor(invoice.customerId!))
            .where((payment) => payment.invoiceId == invoice.id)
            .toList();
    final returns = await db.salesReturnsForInvoice(invoice.id);
    final returnedMinor = returns.fold<int>(0, (sum, row) => sum + row.totalMinor);
    final outstandingMinor = (invoice.totalMinor - invoice.paidMinor - returnedMinor).clamp(0, invoice.totalMinor);
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final settings = AppSettings(prefs);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(invoice.invoiceNumber, style: Theme.of(context).textTheme.headlineSmall)),
                Text(money(invoice.totalMinor), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Text(invoice.createdAt.toLocal().toString()),
              if (customer != null) Text('Customer: ' + customer.name),
              const SizedBox(height: 16),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(items[i].itemNameSnapshot),
                    subtitle: Text([
                      items[i].quantity.toString() + ' × ' + money(items[i].unitPriceMinor),
                      if ((items[i].skuSnapshot ?? '').isNotEmpty) 'SKU: ${items[i].skuSnapshot}',
                      if ((items[i].hsnSacSnapshot ?? '').isNotEmpty) 'HSN/SAC: ${items[i].hsnSacSnapshot}',
                    ].join(' • ')),
                    trailing: Text(money(items[i].lineTotalMinor)),
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(invoice.gstSupplyType == 'interState'
                    ? 'Supply: Inter-state'
                    : invoice.gstSupplyType == 'intraState'
                        ? 'Supply: Intra-state'
                        : 'Supply type: Not recorded'),
                  Text('Subtotal: ' + money(invoice.subtotalMinor)),
                  Text('Discount: -' + money(invoice.discountMinor)),
                  if (invoice.cgstMinor > 0) Text('CGST: ' + money(invoice.cgstMinor)),
                  if (invoice.sgstMinor > 0) Text('SGST: ' + money(invoice.sgstMinor)),
                  if (invoice.igstMinor > 0) Text('IGST: ' + money(invoice.igstMinor)),
                  if (invoice.cgstMinor == 0 && invoice.sgstMinor == 0 && invoice.igstMinor == 0)
                    Text('GST / Tax: ' + money(invoice.taxMinor)),
                  Text('Payment: ' + invoice.paymentMethod.toUpperCase() + ' • ' + invoice.paymentStatus.toUpperCase()),
                  Text('Paid: ' + money(invoice.paidMinor)),
                  Text('Balance: ' + money(outstandingMinor)),
                  Text('Total: ' + money(invoice.totalMinor), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              if (payments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Payment history', style: Theme.of(context).textTheme.titleMedium),
                ...payments.map((payment) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.payments_outlined),
                  title: Text(money(payment.amountMinor)),
                  subtitle: Text(
                    '${payment.paymentMethod.toUpperCase()} • ${payment.receivedAt.toLocal()}'
                    '${(payment.reference ?? '').isEmpty ? '' : ' • ${payment.reference}'}',
                  ),
                )),
              ],
              if (returns.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Sales returns', style: Theme.of(context).textTheme.titleMedium),
                ...returns.map((returned) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_return_outlined),
                  title: Text('${returned.returnNumber} • ${money(returned.totalMinor)}'),
                  subtitle: Text('${returned.refundMethod.toUpperCase()} • ${returned.createdAt.toLocal()}'),
                )),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (invoice.customerId != null && outstandingMinor > 0)
                    FilledButton.tonalIcon(
                      onPressed: () => _recordPayment(invoice),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Record payment'),
                    ),
                  FilledButton.tonalIcon(
                    onPressed: () => _createReturn(invoice, items),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Sales return'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _print(invoice, items, settings, customer: customer, thermal: settings.thermalReceipt),
                    icon: const Icon(Icons.print_outlined),
                    label: Text(settings.thermalReceipt ? 'Print Thermal (default)' : 'Print A4 (default)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _print(invoice, items, settings, customer: customer, thermal: !settings.thermalReceipt),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(settings.thermalReceipt ? 'Print A4' : 'Print Thermal'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _share(invoice, items, settings, customer: customer),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _save(invoice, items, settings, customer: customer),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save PDF'),
                  ),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }


  Future<void> _recordPayment(Invoice invoice) async {
    final priorReturns = await ref.read(databaseProvider).salesReturnsForInvoice(invoice.id);
    final returnedMinor = priorReturns.fold<int>(0, (sum, row) => sum + row.totalMinor);
    final outstandingMinor = (invoice.totalMinor - invoice.paidMinor - returnedMinor).clamp(0, invoice.totalMinor);
    if (outstandingMinor <= 0) return;
    final amount = TextEditingController();
    String method = 'cash';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Record payment • ${invoice.invoiceNumber}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Outstanding: ${money(outstandingMinor)}'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount received (INR)', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'upi', child: Text('UPI')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                    DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  ],
                  onChanged: (value) => setDialogState(() => method = value ?? 'cash'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save receipt'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      amount.dispose();
      return;
    }
    final parsed = double.tryParse(amount.text.trim().replaceAll(',', ''));
    amount.dispose();
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payment amount.')),
      );
      return;
    }
    try {
      await ref.read(databaseProvider).recordCustomerPayment(
        id: const Uuid().v4(),
        invoiceId: invoice.id,
        amountMinor: (parsed * 100).round(),
        paymentMethod: method,
      );
      refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer payment recorded.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'Payment could not be recorded.'))),
      );
    }
  }

  Future<void> _createReturn(Invoice invoice, List<InvoiceItem> invoiceLines) async {
    if (invoiceLines.isEmpty) return;
    final db = ref.read(databaseProvider);
    final priorReturns = await (db.select(db.salesReturnItems)
          ..where((t) => t.invoiceItemId.isIn(invoiceLines.map((x) => x.id).toList())))
        .get();
    final returned = <String, int>{};
    for (final line in priorReturns) {
      returned.update(
        line.invoiceItemId,
        (value) => value + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    final quantities = <String, int>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Return items • ${invoice.invoiceNumber}'),
          content: SizedBox(
            width: 520,
            height: 360,
            child: ListView.separated(
              itemCount: invoiceLines.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final line = invoiceLines[index];
                final remaining = line.quantity - (returned[line.id] ?? 0);
                if (remaining <= 0) {
                  return ListTile(
                    title: Text(line.itemNameSnapshot),
                    subtitle: const Text('Fully returned'),
                    trailing: const Icon(Icons.check_circle_outline),
                  );
                }
                final selected = quantities[line.id] ?? 0;
                return ListTile(
                  title: Text(line.itemNameSnapshot),
                  subtitle: Text('${remaining} remaining • ${money(line.unitPriceMinor)} each'),
                  trailing: SizedBox(
                    width: 112,
                    child: DropdownButtonFormField<int>(
                      initialValue: selected,
                      decoration: const InputDecoration(labelText: 'Quantity', isDense: true),
                      items: List.generate(
                        remaining + 1,
                        (value) => DropdownMenuItem(value: value, child: Text(value.toString())),
                      ),
                      onChanged: (value) => setDialogState(() => quantities[line.id] = value ?? 0),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: quantities.values.any((value) => value > 0)
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    String refundMethod = 'cash';
    final refundConfirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Confirm refund'),
          content: DropdownButtonFormField<String>(
            initialValue: refundMethod,
            decoration: const InputDecoration(labelText: 'Refund method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'upi', child: Text('UPI')),
              DropdownMenuItem(value: 'card', child: Text('Card reversal')),
              DropdownMenuItem(value: 'store_credit', child: Text('Store credit')),
            ],
            onChanged: (value) => setDialogState(() => refundMethod = value ?? 'cash'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Record return')),
          ],
        ),
      ),
    );
    if (refundConfirmed != true) return;
    final returnId = const Uuid().v4();
    try {
      await db.recordSalesReturn(
        id: returnId,
        returnNumber: 'RET-${DateTime.now().millisecondsSinceEpoch}',
        invoiceId: invoice.id,
        lines: quantities.entries
            .where((entry) => entry.value > 0)
            .map((entry) => SalesReturnLine(invoiceItemId: entry.key, quantity: entry.value))
            .toList(),
        refundMethod: refundMethod,
      );
      refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sales return recorded and returned stock restored.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'The sales return could not be recorded.'))),
      );
    }
  }

  Future<void> _print(Invoice invoice, List<InvoiceItem> items, AppSettings settings, {Customer? customer, bool thermal = false}) async {
    try {
      await pdf.printInvoice(
        invoice: invoice,
        items: items,
        shopName: settings.businessName,
        shopAddress: settings.businessAddress,
        phone: settings.businessPhone,
        gstNumber: settings.gstNumber,
        customerName: customer?.name,
        customerPhone: customer?.phone,
        customerEmail: customer?.email,
        customerAddress: customer?.address,
        footerText: settings.invoiceFooter,
        invoiceTitle: settings.invoiceTitle,
        termsText: settings.invoiceTerms,
        currencyCode: settings.currency,
        showLogo: settings.showInvoiceLogo,
        showSku: settings.showSkuOnInvoice,
        thermal: thermal,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'The invoice could not be printed. Please try again.'))),
      );
    }
  }

  Future<void> _share(Invoice invoice, List<InvoiceItem> items, AppSettings settings, {Customer? customer}) async {
    try {
      await pdf.shareInvoice(
        invoice: invoice,
        items: items,
        shopName: settings.businessName,
        shopAddress: settings.businessAddress,
        phone: settings.businessPhone,
        gstNumber: settings.gstNumber,
        customerName: customer?.name,
        customerPhone: customer?.phone,
        customerEmail: customer?.email,
        customerAddress: customer?.address,
        footerText: settings.invoiceFooter,
        invoiceTitle: settings.invoiceTitle,
        termsText: settings.invoiceTerms,
        currencyCode: settings.currency,
        showLogo: settings.showInvoiceLogo,
        showSku: settings.showSkuOnInvoice,
        thermal: settings.thermalReceipt,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'The invoice could not be shared. Please try again.'))),
      );
    }
  }

  Future<void> _save(Invoice invoice, List<InvoiceItem> items, AppSettings settings, {Customer? customer}) async {
    try {
      final file = await pdf.saveInvoice(
        invoice: invoice,
        items: items,
        shopName: settings.businessName,
        shopAddress: settings.businessAddress,
        phone: settings.businessPhone,
        gstNumber: settings.gstNumber,
        customerName: customer?.name,
        customerPhone: customer?.phone,
        customerEmail: customer?.email,
        customerAddress: customer?.address,
        footerText: settings.invoiceFooter,
        invoiceTitle: settings.invoiceTitle,
        termsText: settings.invoiceTerms,
        currencyCode: settings.currency,
        showLogo: settings.showInvoiceLogo,
        showSku: settings.showSkuOnInvoice,
        thermal: settings.thermalReceipt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice saved to ' + file.path)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFacingError(e, fallback: 'The invoice could not be saved. Please try again.'))),
      );
    }
  }
}
