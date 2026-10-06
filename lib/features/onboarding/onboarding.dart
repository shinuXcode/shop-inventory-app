import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/app_settings.dart';
import '../../core/widgets/sbill_logo.dart';

enum OnboardingDestination { none, migration, account }

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final pageController = PageController();
  final businessName = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final gstNumber = TextEditingController();
  final invoicePrefix = TextEditingController(text: 'INV');
  bool thermalReceipt = false;
  bool useCloud = false;
  bool importAfterSetup = false;
  String currency = 'INR';
  String printerPreference = 'manual';
  int page = 0;

  static const totalPages = 5;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = math.min(size.width - 32, 640.0);
    final height = math.min(size.height * 0.68, 520.0);

    return AlertDialog(
      title: Row(
        children: [
          const SBillLogo(size: 42),
          const SizedBox(width: 12),
          Expanded(child: Text(_title)),
        ],
      ),
      content: SizedBox(
        width: width,
        height: height,
        child: PageView(
          controller: pageController,
          physics: const NeverScrollableScrollPhysics(),
          onPageChanged: (value) => setState(() => page = value),
          children: [
            _welcomePage(),
            _businessPage(),
            _invoicePage(),
            _migrationPage(),
            _cloudPage(),
          ],
        ),
      ),
      actions: [
        if (page > 0)
          TextButton(
            onPressed: _back,
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: _skip,
          child: const Text('Skip setup'),
        ),
        FilledButton.icon(
          onPressed: page == totalPages - 1 ? _finish : _next,
          icon: Icon(page == totalPages - 1 ? Icons.check : Icons.arrow_forward),
          label: Text(page == totalPages - 1 ? 'Finish' : 'Next'),
        ),
      ],
    );
  }

  String get _title => const [
    'Welcome to SBILL',
    'Set up your business',
    'Invoice & receipt preferences',
    'Starting inventory',
    'Cloud account (optional)',
  ][page];

  Widget _pageBody(List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.only(top: 4, right: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );

  Widget _welcomePage() => _pageBody([
    Text(
      'Fast billing, inventory and customers without forcing you into a cloud account.',
      style: Theme.of(context).textTheme.bodyLarge,
    ),
    const SizedBox(height: 24),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        Chip(label: Text('Offline-first')),
        Chip(label: Text('Local SQLite')),
        Chip(label: Text('Barcode-ready')),
        Chip(label: Text('A4 + thermal')),
        Chip(label: Text('Cash + UPI + card + credit')),
      ],
    ),
    const SizedBox(height: 24),
    const Card(
      child: ListTile(
        leading: Icon(Icons.lock_outline),
        title: Text('Your choice'),
        subtitle: Text(
          'You can keep SBILL completely offline. Cloud sync is optional and can be enabled later from Account & Sync.',
        ),
      ),
    ),
  ]);

  Widget _businessPage() => _pageBody([
    Text(
      'Business information',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: businessName,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.storefront_outlined),
        labelText: 'Business name *',
      ),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: phone,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.phone_outlined),
        labelText: 'Phone',
      ),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: email,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.email_outlined),
        labelText: 'Business email',
      ),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: address,
      minLines: 1,
      maxLines: 3,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.location_on_outlined),
        labelText: 'Business address',
      ),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: gstNumber,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.receipt_long_outlined),
        labelText: 'GSTIN / tax ID',
      ),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: currency,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.currency_rupee_outlined),
        labelText: 'Currency',
      ),
      items: const [
        DropdownMenuItem(value: 'INR', child: Text('INR — Indian Rupee')),
        DropdownMenuItem(value: 'USD', child: Text('USD — US Dollar')),
        DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
        DropdownMenuItem(value: 'GBP', child: Text('GBP — Pound Sterling')),
      ],
      onChanged: (value) => setState(() => currency = value ?? 'INR'),
    ),
  ]);

  Widget _invoicePage() => _pageBody([
    Text(
      'Invoice & printer preferences',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: invoicePrefix,
      textCapitalization: TextCapitalization.characters,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.tag_outlined),
        labelText: 'Invoice prefix',
      ),
    ),
    const SizedBox(height: 10),
    DropdownButtonFormField<String>(
      initialValue: printerPreference,
      decoration: const InputDecoration(
        prefixIcon: Icon(Icons.print_outlined),
        labelText: 'Printer workflow',
      ),
      items: const [
        DropdownMenuItem(
          value: 'manual',
          child: Text('Choose Print / Save manually'),
        ),
        DropdownMenuItem(
          value: 'thermal',
          child: Text('Prefer thermal receipt output'),
        ),
      ],
      onChanged: (value) => setState(() => printerPreference = value ?? 'manual'),
    ),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Use thermal receipt by default'),
      subtitle: const Text('Sets the default invoice print format to the compact receipt layout.'),
      value: thermalReceipt,
      onChanged: (value) => setState(() => thermalReceipt = value),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.print_outlined),
        title: Text('Printer setup'),
        subtitle: Text(
          'SBILL keeps printing user-controlled. The actual printer is selected by the platform when you print.',
        ),
      ),
    ),
  ]);

  Widget _migrationPage() => _pageBody([
    Text(
      'Starting inventory',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    const Text(
      'Bring your existing products and customers from CSV, JSON or TXT, or restore a SBILL backup.',
    ),
    const SizedBox(height: 12),
    CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Open Migration Center after setup'),
      subtitle: const Text('Use this when you already have product or customer data to import.'),
      value: importAfterSetup,
      onChanged: (value) => setState(() => importAfterSetup = value ?? false),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.inventory_2_outlined),
        title: Text('Starting with an empty inventory'),
        subtitle: Text('You can add products manually at any time from Inventory.'),
      ),
    ),
  ]);

  Widget _cloudPage() => _pageBody([
    Text(
      'One account across devices',
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    const Text(
      'An SBILL account uses the same identity on Android, Windows, macOS, iOS and the SBILL website.',
    ),
    const SizedBox(height: 12),
    SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Connect an SBILL cloud account'),
      subtitle: const Text(
        'Optional. You can skip this and continue using SBILL fully offline.',
      ),
      value: useCloud,
      onChanged: (value) => setState(() => useCloud = value),
    ),
    const Card(
      child: ListTile(
        leading: Icon(Icons.sync_outlined),
        title: Text('Sync stays optional'),
        subtitle: Text(
          'Your local billing data does not depend on an internet connection.',
        ),
      ),
    ),
  ]);

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    final name = businessName.text.trim();
    final safeName = name.isEmpty ? 'SBILL Shop' : name;

    final settings = AppSettings(prefs);
    await settings.save(
      businessName: safeName,
      businessPhone: phone.text.trim(),
      businessEmail: email.text.trim(),
      businessAddress: address.text.trim(),
      gstNumber: gstNumber.text.trim(),
      invoicePrefix: invoicePrefix.text.trim().isEmpty ? 'INV' : invoicePrefix.text.trim().toUpperCase(),
      currency: currency,
      thermalReceipt: thermalReceipt,
      darkMode: settings.darkMode,
    );
    await prefs.setBool('printerPreferenceThermal', printerPreference == 'thermal' || thermalReceipt);
    await prefs.setBool('onboardingCloudOptIn', useCloud);
    await prefs.setBool('onboardingComplete', true);

    if (!mounted) return;
    Navigator.pop(
      context,
      useCloud
          ? OnboardingDestination.account
          : importAfterSetup
              ? OnboardingDestination.migration
              : OnboardingDestination.none,
    );
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (mounted) Navigator.pop(context, OnboardingDestination.none);
  }

  Future<void> _next() async {
    if (page == 1 && businessName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your business name, or use Skip setup.')),
      );
      return;
    }
    await pageController.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    pageController.previousPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    businessName.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    gstNumber.dispose();
    invoicePrefix.dispose();
    super.dispose();
  }
}
