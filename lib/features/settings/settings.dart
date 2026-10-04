import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sync/sync_service.dart';

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
    email.text = settings.businessEmail;
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
      businessEmail: email.text.trim(),
      businessAddress: address.text.trim(),
      gstNumber: gst.text.trim(),
      invoicePrefix: prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim(),
      thermalReceipt: thermal,
      darkMode: dark,
    );
    await ref.read(themeModeProvider.notifier).setDarkMode(dark);
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

  Future<void> _cloudAuth() async {
    if (!CloudConfig.configured) {
      _showMessage('Build with SUPABASE_URL and SUPABASE_ANON_KEY to enable cloud sync.');
      return;
    }
    final emailController = TextEditingController(text: email.text.trim());
    final passwordController = TextEditingController();
    final createAccount = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cloud account'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Sign in')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create account')),
        ],
      ),
    );
    if (createAccount == null) return;
    final client = Supabase.instance.client;
    try {
      if (createAccount) {
        final result = await client.auth.signUp(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        if (result.session == null) {
          _showMessage('Account created. Confirm your email if email confirmation is enabled.');
        } else {
          _showMessage('Cloud account created and signed in.');
        }
      } else {
        await client.auth.signInWithPassword(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
        _showMessage('Signed in as ' + emailController.text.trim());
      }
      if (mounted) setState(() {});
    } on AuthException catch (e) {
      _showMessage(e.message);
    } catch (e) {
      _showMessage('Cloud authentication failed: ' + e.toString());
    }
  }

  Future<void> _createBusiness() async {
    if (!_signedIn) {
      await _cloudAuth();
      if (!_signedIn) return;
    }
    final name = TextEditingController(text: business.text);
    final id = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create workspace'),
          content: TextField(
            controller: name,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(labelText: 'Business name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: name.text.trim().isEmpty ? null : () => Navigator.pop(dialogContext, name.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (id == null || id.isEmpty) return;
    try {
      final client = Supabase.instance.client;
      final result = await client.rpc('create_business', params: {
        'p_name': id,
        'p_phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'p_address': address.text.trim().isEmpty ? null : address.text.trim(),
        'p_gst_number': gst.text.trim().isEmpty ? null : gst.text.trim(),
        'p_currency': 'INR',
        'p_invoice_prefix': prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim(),
      });
      await settings.save(
        businessName: id,
        businessPhone: phone.text.trim(),
        businessEmail: email.text.trim(),
        businessAddress: address.text.trim(),
        gstNumber: gst.text.trim(),
        invoicePrefix: prefix.text.trim().isEmpty ? 'INV' : prefix.text.trim(),
        thermalReceipt: thermal,
        darkMode: dark,
        businessId: result.toString(),
      );
      if (mounted) {
        _showMessage('Workspace created. Local changes can now sync.');
        setState(() {});
      }
    } catch (e) {
      _showMessage('Workspace creation failed: ' + e.toString());
    }
  }

  Future<void> _syncNow() async {
    if (!settings.cloudConfigured) {
      _showMessage('Create a cloud workspace first.');
      return;
    }
    await ref.read(syncServiceProvider).syncNow();
    _showMessage('Sync completed' + (ref.read(syncServiceProvider).lastError == null ? '.' : ' with retryable errors.'));
  }

  Future<void> _signOut() async {
    if (!CloudConfig.configured) return;
    await Supabase.instance.client.auth.signOut();
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 10),
          TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Address')),
          const SizedBox(height: 10),
          TextField(controller: gst, decoration: const InputDecoration(labelText: 'GST number')),
          const SizedBox(height: 10),
          TextField(controller: prefix, decoration: const InputDecoration(labelText: 'Invoice prefix')),
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
          const SizedBox(height: 24),
          Text('Cloud & Sync', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    _signedIn ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                  ),
                  title: Text(_cloudUserEmail),
                  subtitle: Text(
                    settings.businessId == null
                      ? 'No workspace selected'
                      : 'Workspace: ' + settings.businessId!,
                  ),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (!_signedIn)
                    OutlinedButton.icon(
                      onPressed: _cloudAuth,
                      icon: const Icon(Icons.login_outlined),
                      label: const Text('Sign in / Sign up'),
                    ),
                  if (_signedIn && settings.businessId == null)
                    FilledButton.tonalIcon(
                      onPressed: _createBusiness,
                      icon: const Icon(Icons.business_outlined),
                      label: const Text('Create workspace'),
                    ),
                  if (_signedIn && settings.businessId != null)
                    FilledButton.tonalIcon(
                      onPressed: _syncNow,
                      icon: const Icon(Icons.sync_outlined),
                      label: const Text('Sync now'),
                    ),
                  if (_signedIn)
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('Sign out'),
                    ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Offline-first'),
            subtitle: Text('Billing and inventory are stored in local SQLite first. Cloud sync is optional and retryable.'),
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
    business.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    gst.dispose();
    prefix.dispose();
    super.dispose();
  }
}
