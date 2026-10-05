import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/sbill_logo.dart';

class OnboardingDialog extends StatefulWidget {
  const OnboardingDialog({super.key});

  @override
  State<OnboardingDialog> createState() => _OnboardingDialogState();
}

class _OnboardingDialogState extends State<OnboardingDialog> {
  final pageController = PageController();
  final businessName = TextEditingController();
  var page = 0;

  static const steps = [
    ('Welcome to SBILL', 'Fast billing, inventory and customers without forcing you into a cloud account.'),
    ('Set up your shop', 'Enter your business name now. You can complete GST, address and invoice settings later.'),
    ('Switch from another app', 'Bring products and customers with CSV, JSON or TXT files, or restore a full SBILL backup.'),
    ('Ready for the counter', 'Use Billing for the fastest daily workflow. Search, add, pay and issue an invoice.'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = steps[page];
    return AlertDialog(
      title: Row(
        children: [
          const SBillLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(child: Text(current.$1)),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 250,
        child: PageView.builder(
          controller: pageController,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: steps.length,
          onPageChanged: (value) => setState(() => page = value),
          itemBuilder: (_, index) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  steps[index].$2,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 22),
                if (index == 1)
                  TextField(
                    controller: businessName,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.storefront_outlined),
                      labelText: 'Business name',
                      hintText: 'e.g. Sadab Mobile Store',
                    ),
                  ),
                if (index == 2)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.import_export_outlined),
                      title: Text('Migration Center'),
                      subtitle: Text('Available from Settings after setup.'),
                    ),
                  ),
                if (index == 3)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final text in const [
                        'Offline-first',
                        'Barcode-ready',
                        'A4 + thermal',
                        'UPI + card + cash',
                      ])
                        Chip(label: Text(text)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _skip, child: const Text('Set up later')),
        FilledButton.icon(
          onPressed: page == steps.length - 1 ? _finish : _next,
          icon: Icon(page == steps.length - 1 ? Icons.check : Icons.arrow_forward),
          label: Text(page == steps.length - 1 ? 'Start using SBILL' : 'Next'),
        ),
      ],
    );
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    final name = businessName.text.trim();
    if (name.isNotEmpty) await prefs.setString('businessName', name);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _skip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboardingComplete', true);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _next() async {
    if (page == 1) {
      final name = businessName.text.trim();
      if (name.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('businessName', name);
      }
    }
    await pageController.nextPage(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    pageController.dispose();
    businessName.dispose();
    super.dispose();
  }
}
