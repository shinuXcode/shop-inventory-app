import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/settings/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SharedPreferences _prefs;
  late AppSettings settings;
  final business = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final gst = TextEditingController();
  final prefix = TextEditingController();
  bool thermal = false;
  bool dark = false;
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
    address.text = settings.businessAddress;
    gst.text = settings.gstNumber;
    prefix.text = settings.invoicePrefix;
    thermal = settings.thermalReceipt;
    dark = settings.darkMode;
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    await settings.save(
      businessName: business.text.trim().isEmpty ? 'SBILL Shop' : business.text.trim(),
      businessPhone: phone.text.trim(),
      businessAddress: address.text.trim(),
      gstNumber: gst.text.trim(),
      invoicePrefix: prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim(),
      thermalReceipt: thermal,
      darkMode: dark,
    );
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved locally')));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Business information', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: business, decoration: const InputDecoration(labelText: 'Business name')),
          const SizedBox(height: 10),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: gst, decoration: const InputDecoration(labelText: 'GST number')),
          const SizedBox(height: 10),
          TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Invoice prefix')),
          const SizedBox(height: 18),
          SwitchListTile(
            title: const Text('Thermal receipt default'),
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
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.sync_outlined),
            title: Text('Synchronization'),
            subtitle: Text('Local-first billing remains usable when offline. Cloud sync is being added incrementally.'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('About SBILL'),
            subtitle: Text('Simple Billing. Smarter Business.'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    business.dispose(); phone.dispose(); address.dispose(); gst.dispose(); prefix.dispose();
    super.dispose();
  }
}
