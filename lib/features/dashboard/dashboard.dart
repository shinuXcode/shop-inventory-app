import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder(
        future: db.recentInvoices(limit: 100),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final invoices = snap.data!;
          final d = DateTime.now();
          final today = invoices.where((x) =>
            x.createdAt.year == d.year &&
            x.createdAt.month == d.month &&
            x.createdAt.day == d.day);
          final sales = today.fold<int>(0, (s, x) => s + x.totalMinor);
          return GridView.count(
            padding: const EdgeInsets.all(16),
            crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 4 : 2,
            crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.7,
            children: [
              _metric(context, 'Today’s sales', '₹' + (sales / 100).toStringAsFixed(2), Icons.currency_rupee),
              _metric(context, 'Invoices', today.length.toString(), Icons.receipt_long_outlined),
              _metric(context, 'Average bill',
                today.isEmpty ? '₹0.00' : '₹' + (sales / 100 / today.length).toStringAsFixed(2),
                Icons.trending_up),
              _metric(context, 'Data mode', 'Offline-first', Icons.storage_outlined),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(BuildContext c, String t, String v, IconData i) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(i), const SizedBox(height: 10), Text(t), const SizedBox(height: 4),
          Text(v, style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))],
      ),
    ),
  );
}
