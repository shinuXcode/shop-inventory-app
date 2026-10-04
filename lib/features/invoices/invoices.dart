import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app.dart';
import '../../core/pdf/invoice_pdf_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/database/app_database.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  const InvoicesPage({super.key});
  @override ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  late Future<List<Invoice>> future;
  final pdf = InvoicePdfService();

  @override
  void initState() {
    super.initState();
    future = ref.read(databaseProvider).recentInvoices(limit: 100);
  }

  void refresh() => setState(() => future = ref.read(databaseProvider).recentInvoices(limit: 100));

  String money(int minor) => '₹' + (minor / 100).toStringAsFixed(2);

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
        if (s.hasError) return Center(child: Text('Failed to load invoices: ' + s.error.toString()));
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
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
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
                    subtitle: Text(items[i].quantity.toString() + ' × ' + money(items[i].unitPriceMinor)),
                    trailing: Text(money(items[i].lineTotalMinor)),
                  ),
                ),
              ),
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Subtotal: ' + money(invoice.subtotalMinor)),
                  Text('Discount: -' + money(invoice.discountMinor)),
                  Text('Tax: ' + money(invoice.taxMinor)),
                  Text('Payment: ' + invoice.paymentMethod.toUpperCase()),
                  Text('Total: ' + money(invoice.totalMinor), style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _print(invoice, items, settings),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print A4'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _print(invoice, items, settings, thermal: true),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Print Thermal'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _share(invoice, items, settings),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Share PDF'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _save(invoice, items, settings),
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

  Future<void> _print(Invoice invoice, List<InvoiceItem> items, AppSettings settings, {bool thermal = false}) async {
    await pdf.printInvoice(
      invoice: invoice,
      items: items,
      shopName: settings.businessName,
      shopAddress: settings.businessAddress,
      phone: settings.businessPhone,
      gstNumber: settings.gstNumber,
      thermal: thermal,
    );
  }

  Future<void> _share(Invoice invoice, List<InvoiceItem> items, AppSettings settings) async {
    await pdf.shareInvoice(
      invoice: invoice,
      items: items,
      shopName: settings.businessName,
      shopAddress: settings.businessAddress,
      phone: settings.businessPhone,
      gstNumber: settings.gstNumber,
    );
  }

  Future<void> _save(Invoice invoice, List<InvoiceItem> items, AppSettings settings) async {
    final file = await pdf.saveInvoice(
      invoice: invoice,
      items: items,
      shopName: settings.businessName,
      shopAddress: settings.businessAddress,
      phone: settings.businessPhone,
      gstNumber: settings.gstNumber,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved: ' + file.path)),
    );
  }
}
