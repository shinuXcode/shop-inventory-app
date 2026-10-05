import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app.dart';
import '../migration/migration.dart';
import '../shell/shell.dart';

final dashboardDataProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final db = ref.watch(databaseProvider);
  final invoices = await db.recentInvoices(limit: 500);
  final lowStock = await db.lowStockCount();
  return DashboardData(invoices: invoices, lowStock: lowStock);
});

class DashboardData {
  const DashboardData({required this.invoices, required this.lowStock});

  final List<Invoice> invoices;
  final int lowStock;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dashboardDataProvider),
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Failed to load dashboard: ' + error.toString()),
        ),
        data: (data) {
          final invoices = data.invoices;
          final lowStock = data.lowStock;
          final now = DateTime.now();
          final today = invoices.where((x) =>
            x.createdAt.year == now.year &&
            x.createdAt.month == now.month &&
            x.createdAt.day == now.day).toList();
          final sales = today.fold<int>(0, (s, x) => s + x.totalMinor);

          final daily = List<int>.generate(7, (index) {
            final date = DateTime(now.year, now.month, now.day)
                .subtract(Duration(days: 6 - index));
            return invoices.where((x) =>
              x.createdAt.year == date.year &&
              x.createdAt.month == date.month &&
              x.createdAt.day == date.day).fold<int>(
                0,
                (sum, x) => sum + x.totalMinor,
              );
          });
          final maxDay = daily.fold<int>(0, (a, b) => a > b ? a : b);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.2 : 1.8,
                    children: [
                      _metric(
                        context,
                        'Today’s sales',
                        '₹' + (sales / 100).toStringAsFixed(2),
                        Icons.currency_rupee_outlined,
                      ),
                      _metric(
                        context,
                        'Invoices today',
                        today.length.toString(),
                        Icons.receipt_long_outlined,
                      ),
                      _metric(
                        context,
                        'Average bill',
                        today.isEmpty
                            ? '₹0.00'
                            : '₹' + (sales / 100 / today.length).toStringAsFixed(2),
                        Icons.trending_up_outlined,
                      ),
                      _metric(
                        context,
                        'Low-stock items',
                        lowStock.toString(),
                        Icons.inventory_2_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              Text(
                'Quick actions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _quickAction(
                    context,
                    'New bill',
                    Icons.point_of_sale_outlined,
                    1,
                  ),
                  _quickAction(
                    context,
                    'Add product',
                    Icons.add_box_outlined,
                    2,
                  ),
                  _quickAction(
                    context,
                    'Add customer',
                    Icons.person_add_outlined,
                    3,
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MigrationPage(),
                      ),
                    ),
                    icon: const Icon(Icons.move_to_inbox_outlined),
                    label: const Text('Switch to SBILL'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sales — last 7 days',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 170,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (index) {
                            final value = daily[index];
                            final factor = maxDay == 0 ? 0.0 : value / maxDay;
                            final date = DateTime(now.year, now.month, now.day)
                                .subtract(Duration(days: 6 - index));
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      '₹' + (value / 100).toStringAsFixed(0),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    FractionallySizedBox(
                                      widthFactor: 0.8,
                                      child: Container(
                                        height: 95 * factor + 4,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('EEE').format(date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Recent invoices',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              ...invoices.take(8).map(
                (x) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(x.invoiceNumber),
                    subtitle: Text(x.createdAt.toLocal().toString()),
                    trailing: Text(
                      '₹' + (x.totalMinor / 100).toStringAsFixed(2),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _quickAction(
    BuildContext context,
    String label,
    IconData icon,
    int destination,
  ) =>
      FilledButton.tonalIcon(
        onPressed: () => Shell.navigateTo(context, destination),
        icon: Icon(icon),
        label: Text(label),
      );

  Widget _metric(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
