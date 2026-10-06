import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../app.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sync/sync_service.dart';
import '../migration/migration.dart';
import '../account/account.dart';
import '../about/about.dart';
import '../support/support.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late SharedPreferences _prefs;
  late AppSettings settings;
  final business = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final gst = TextEditingController();
  final prefix = TextEditingController();
  final invoiceFooter = TextEditingController();
  bool thermal = false;
  bool dark = false;
  String currency = 'INR';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _prefs = await SharedPreferences.getInstance();
    settings = AppSettings(_prefs);
    business.text = settings.businessName;
    phone.text = settings.businessPhone;
    email.text = settings.businessEmail;
    address.text = settings.businessAddress;
    gst.text = settings.gstNumber;
    prefix.text = settings.invoicePrefix;
    invoiceFooter.text = settings.invoiceFooter;
    thermal = settings.thermalReceipt;
    dark = settings.darkMode;
    currency = settings.currency;
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    await settings.save(
      businessName: business.text.trim().isEmpty ? 'SBILL Shop' : business.text.trim(),
      businessPhone: phone.text.trim(),
      businessEmail: email.text.trim(),
      businessAddress: address.text.trim(),
      gstNumber: gst.text.trim(),
      invoicePrefix: prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim(),
      thermalReceipt: thermal,
      darkMode: dark,
      currency: currency,
      invoiceFooter: invoiceFooter.text.trim(),
    );
    await ref.read(themeModeProvider.notifier).setDarkMode(dark);
    if (_signedIn && settings.businessId != null) {
      await ref.read(syncServiceProvider).syncNow();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved locally')));
    }
  }

  String get _cloudUserEmail {
    if (!CloudConfig.configured) return 'Cloud not configured';
    try {
      return Supabase.instance.client.auth.currentUser?.email ?? 'Not signed in';
    } catch (_) {
      return 'Not initialized';
    }
  }

  bool get _signedIn {
    if (!CloudConfig.configured) return false;
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
          Text('Business information', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: business, decoration: const InputDecoration(labelText: 'Business name')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: gst, decoration: const InputDecoration(labelText: 'GST number')),
          const SizedBox(height: 10),
          TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Invoice prefix')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: currency,
            decoration: const InputDecoration(labelText: 'Currency'),
            items: const [
              DropdownMenuItem(value: 'INR', child: Text('INR — Indian Rupee')),
              DropdownMenuItem(value: 'USD', child: Text('USD — US Dollar')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR — Euro')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP — Pound Sterling')),
            ],
            onChanged: (value) => setState(() => currency = value ?? 'INR'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: invoiceFooter,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Invoice footer',
              hintText: 'Thank you for your business.',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            title: const Text('Thermal receipt default'),
            subtitle: const Text('Use 80 mm receipt layout when printing from invoice details.'),
            value: thermal,
            onChanged: (v) => setState(() => thermal = v),
          ),
          SwitchListTile(
            title: const Text('Dark mode preference'),
            value: dark,
            onChanged: (v) => setState(() => dark = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save settings')),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.move_to_inbox_outlined),
              title: const Text('Migration Center'),
              subtitle: const Text('Import products and customers, or restore a complete SBILL backup.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MigrationPage())),
            ),
          ),
          const SizedBox(height: 24),
          Text('Account & Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(
                _signedIn ? Icons.cloud_done_outlined : Icons.account_circle_outlined,
              ),
              title: Text(_signedIn ? _cloudUserEmail : 'SBILL account'),
              subtitle: Text(
                settings.businessId == null
                    ? 'Sign in or create an account to sync across devices.'
                    : 'Cloud workspace linked. Open Account Center to manage sync.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountPage()),
                );
                if (mounted) setState(() {});
              },
            ),
          ),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Offline-first'),
            subtitle: Text('Billing and inventory are stored in local SQLite first. Cloud sync is optional and retryable.'),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent_outlined),
              title: const Text('Support Center'),
              subtitle: const Text('Create and track support requests with your SBILL account.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportPage())),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About SBILL'),
              subtitle: const Text('Website, founder page, portfolio and project links.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutPage())),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    business.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    gst.dispose();
    prefix.dispose();
    invoiceFooter.dispose();
    super.dispose();
  }
}
