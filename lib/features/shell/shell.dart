import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../dashboard/dashboard.dart';
import '../billing/billing.dart';
import '../inventory/inventory.dart';
import '../customers/customers.dart';
import '../invoices/invoices.dart';
import '../settings/settings.dart';
import '../onboarding/onboarding.dart';
import '../migration/migration.dart';
import '../account/account.dart';
import '../../core/widgets/sbill_logo.dart';

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
      final destination = await showDialog<OnboardingDestination>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const OnboardingDialog(),
      );
      if (!mounted) return;
      switch (destination) {
        case OnboardingDestination.migration:
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MigrationPage()),
          );
          break;
        case OnboardingDestination.account:
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
          break;
        case OnboardingDestination.none:
        case null:
          break;
      }
    });
  }

  void _select(int value) {
    if (!mounted || value < 0 || value >= pages.length) return;
    setState(() => index = value);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final rail = width >= 720;
    final extended = width >= 1200;
    return Scaffold(
      body: Row(children: [
        if (rail) NavigationRail(
          selectedIndex: index,
          extended: extended,
          onDestinationSelected: _select,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const SBillLogo(size: 38),
              if (MediaQuery.sizeOf(context).width >= 1200) ...[
                const SizedBox(width: 10),
                Text('SBILL', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ]),
          ),
          destinations: List.generate(labels.length, (i) =>
            NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i]))),
        ),
        Expanded(
          child: ClipRect(
            child: Stack(
              children: [
                for (var i = 0; i < pages.length; i++)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: i != index,
                      child: AnimatedOpacity(
                        opacity: i == index ? 1 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedSlide(
                          offset: i == index
                              ? Offset.zero
                              : Offset(i < index ? -0.015 : 0.015, 0),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutCubic,
                          child: pages[i],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ]),
      bottomNavigationBar: rail ? null : NavigationBar(
        selectedIndex: index,
        onDestinationSelected: _select,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: List.generate(labels.length, (i) =>
          NavigationDestination(icon: Icon(icons[i]), label: labels[i])),
      ),
    );
  }
}
