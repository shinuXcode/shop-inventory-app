import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';

class InvoicesPage extends ConsumerWidget {
  const InvoicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Invoices')),
    body: FutureBuilder(
      future: ref.read(databaseProvider).recentInvoices(),
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final list = s.data!;
        if (list.isEmpty) return const Center(child: Text('No invoices yet'));
        return ListView.separated(
          padding: const EdgeInsets.all(16), itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final x = list[i];
            return Card(child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(x.invoiceNumber),
              subtitle: Text(x.paymentMethod + ' • ' + x.createdAt.toString()),
              trailing: Text('₹' + (x.totalMinor / 100).toStringAsFixed(2)),
            ));
          },
        );
      },
    ),
  );
}
