import 'package:flutter/material.dart';
import '../dashboard/dashboard.dart';
import '../billing/billing.dart';
import '../inventory/inventory.dart';
import '../customers/customers.dart';
import '../invoices/invoices.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [
    DashboardPage(), BillingPage(), InventoryPage(), CustomersPage(), InvoicesPage()
  ];
  final labels = const ['Dashboard', 'Billing', 'Inventory', 'Customers', 'Invoices'];
  final icons = const [
    Icons.dashboard_outlined, Icons.point_of_sale_outlined,
    Icons.inventory_2_outlined, Icons.people_outline, Icons.receipt_long_outlined
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(children: [
        if (wide) NavigationRail(
          selectedIndex: index,
          onDestinationSelected: (v) => setState(() => index = v),
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('SBILL', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          destinations: List.generate(labels.length, (i) =>
            NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i]))),
        ),
        Expanded(child: pages[index]),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: List.generate(labels.length, (i) =>
          NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
      ),
    );
  }
}
