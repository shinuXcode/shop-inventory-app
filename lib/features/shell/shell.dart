import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard.dart';
import '../billing/billing.dart';
import '../inventory/inventory.dart';
import '../customers/customers.dart';
import '../invoices/invoices.dart';
import '../settings/settings.dart';
import '../onboarding/onboarding.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  static void navigateTo(BuildContext context, int destination) {
    final state = context.findAncestorStateOfType<_ShellState>();
    state?._select(destination);
  }

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final pages = const [
    DashboardPage(), BillingPage(), InventoryPage(), CustomersPage(), InvoicesPage(), SettingsPage()
  ];
  final labels = const ['Dashboard', 'Billing', 'Inventory', 'Customers', 'Invoices', 'Settings'];
  final icons = const [
    Icons.dashboard_outlined, Icons.point_of_sale_outlined, Icons.inventory_2_outlined,
    Icons.people_outline, Icons.receipt_long_outlined, Icons.settings_outlined
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || prefs.getBool('onboardingComplete') == true) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OnboardingDialog(),
      );
    });
  }

  void _select(int value) {
    if (!mounted || value < 0 || value >= pages.length) return;
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: Row(children: [
        if (wide) NavigationRail(
          selectedIndex: index,
          extended: MediaQuery.sizeOf(context).width >= 1200,
          onDestinationSelected: _select,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.receipt_long_outlined),
              ),
              if (MediaQuery.sizeOf(context).width >= 1200) ...[
                const SizedBox(width: 10),
                Text('SBILL', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          destinations: List.generate(labels.length, (i) =>
            NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i]))),
        ),
        Expanded(child: pages[index]),
      ]),
      bottomNavigationBar: wide ? null : NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: List.generate(labels.length, (i) =>
          NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
      ),
    );
  }
}
