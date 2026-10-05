import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/settings/app_settings.dart';
import '../../core/sync/sync_service.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  late SharedPreferences prefs;
  late AppSettings settings;
  StreamSubscription<AuthState>? authSubscription;
  bool loading = true;
  bool busy = false;
  bool signUp = false;
  String? message;

  bool get configured => CloudConfig.configured;

  SupabaseClient get client => Supabase.instance.client;

  User? get user => configured ? client.auth.currentUser : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    prefs = await SharedPreferences.getInstance();
    settings = AppSettings(prefs);
    email.text = user?.email ?? '';
    if (configured) {
      authSubscription = client.auth.onAuthStateChange.listen((_) async {
        if (!mounted) return;
        setState(() {});
        if (client.auth.currentUser != null) {
          await _bindCurrentAccount();
        }
      });
      if (user != null) await _bindCurrentAccount();
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _bindCurrentAccount() async {
    final current = client.auth.currentUser;
    if (current == null) return;
    if (settings.accountUserId != current.id) {
      await settings.clearCloudBinding();
      await prefs.setString('accountUserId', current.id);
      settings = AppSettings(prefs);
    }

    if (settings.businessId == null) {
      final memberships = await client
          .from('business_members')
          .select('business_id')
          .eq('user_id', current.id);

      if (memberships.isNotEmpty) {
        final businessId = memberships.first['business_id']?.toString();
        if (businessId != null && businessId.isNotEmpty) {
          await _selectWorkspace(businessId, syncAfter: true);
        }
      }
    } else {
      await _loadRemoteBusiness(settings.businessId!);
      await ref.read(syncServiceProvider).syncNow();
    }

    if (mounted) setState(() {});
  }

  Future<void> _selectWorkspace(String businessId, {bool syncAfter = false}) async {
    await prefs.setString('businessId', businessId);
    settings = AppSettings(prefs);
    await _loadRemoteBusiness(businessId);
    if (syncAfter) await ref.read(syncServiceProvider).syncNow();
  }

  Future<void> _loadRemoteBusiness(String businessId) async {
    try {
      final row = await client
          .from('businesses')
          .select('name,phone,email,address,gst_number,currency,invoice_prefix')
          .eq('id', businessId)
          .maybeSingle();
      if (row == null) return;

      await settings.save(
        businessName: row['name']?.toString() ?? settings.businessName,
        businessPhone: row['phone']?.toString() ?? '',
        businessEmail: row['email']?.toString() ?? '',
        businessAddress: row['address']?.toString() ?? '',
        gstNumber: row['gst_number']?.toString() ?? '',
        invoicePrefix: row['invoice_prefix']?.toString().trim().isEmpty == true
            ? 'INV'
            : (row['invoice_prefix']?.toString() ?? 'INV'),
        thermalReceipt: settings.thermalReceipt,
        darkMode: settings.darkMode,
        invoiceFooter: settings.invoiceFooter,
        businessId: businessId,
        accountUserId: client.auth.currentUser?.id,
      );
      settings = AppSettings(prefs);
    } catch (_) {
      // Initial login must remain usable even when the workspace profile is unavailable.
    }
  }

  Future<void> _submit() async {
    if (!configured || busy) return;
    final address = email.text.trim();
    final pass = password.text;
    if (address.isEmpty || pass.isEmpty) {
      setState(() => message = 'Email and password are required.');
      return;
    }
    if (pass.length < 6) {
      setState(() => message = 'Use a password with at least 6 characters.');
      return;
    }

    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (signUp) {
        final result = await client.auth.signUp(email: address, password: pass);
        if (result.session == null) {
          setState(() {
            message = 'Account created. Confirm your email, then sign in.';
            signUp = false;
          });
        } else {
          setState(() => message = 'Account created and signed in.');
          await _bindCurrentAccount();
        }
      } else {
        await client.auth.signInWithPassword(email: address, password: pass);
        setState(() => message = 'Signed in.');
        await _bindCurrentAccount();
      }
    } on AuthException catch (e) {
      setState(() => message = e.message);
    } catch (e) {
      setState(() => message = 'Account action failed: $e');
    } finally {
      password.clear();
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!configured) return;
    final address = email.text.trim();
    if (address.isEmpty) {
      setState(() => message = 'Enter your email first.');
      return;
    }
    try {
      await client.auth.resetPasswordForEmail(address);
      setState(() => message = 'Password reset email sent.');
    } on AuthException catch (e) {
      setState(() => message = e.message);
    } catch (e) {
      setState(() => message = 'Could not send password reset email: $e');
    }
  }

  Future<void> _createWorkspace() async {
    if (!configured || user == null || busy) return;
    final controller = TextEditingController(text: settings.businessName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create business workspace'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onChanged: (_) => setDialogState(() {}),
            decoration: const InputDecoration(
              labelText: 'Business name',
              prefixIcon: Icon(Icons.storefront_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;

    setState(() => busy = true);
    try {
      final result = await client.rpc('create_business', params: {
        'p_name': name.trim(),
        'p_phone': settings.businessPhone.trim().isEmpty ? null : settings.businessPhone.trim(),
        'p_address': settings.businessAddress.trim().isEmpty ? null : settings.businessAddress.trim(),
        'p_gst_number': settings.gstNumber.trim().isEmpty ? null : settings.gstNumber.trim(),
        'p_currency': settings.currency,
        'p_invoice_prefix': settings.invoicePrefix,
      });
      await settings.save(
        businessName: name.trim(),
        businessPhone: settings.businessPhone,
        businessEmail: settings.businessEmail,
        businessAddress: settings.businessAddress,
        gstNumber: settings.gstNumber,
        invoicePrefix: settings.invoicePrefix,
        thermalReceipt: settings.thermalReceipt,
        darkMode: settings.darkMode,
        invoiceFooter: settings.invoiceFooter,
        businessId: result.toString(),
        accountUserId: user!.id,
      );
      settings = AppSettings(prefs);
      await ref.read(syncServiceProvider).syncNow();
      setState(() => message = 'Workspace created and synced.');
    } catch (e) {
      setState(() => message = 'Workspace creation failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _syncNow() async {
    if (settings.businessId == null || busy) return;
    setState(() => busy = true);
    await ref.read(syncServiceProvider).syncNow();
    if (mounted) {
      setState(() {
        busy = false;
        message = ref.read(syncServiceProvider).lastError == null
            ? 'Sync completed.'
            : 'Sync completed with retryable errors.';
      });
    }
  }

  Future<void> _signOut() async {
    if (!configured || busy) return;
    setState(() => busy = true);
    try {
      await client.auth.signOut();
      await settings.clearCloudBinding();
      settings = AppSettings(prefs);
      setState(() => message = 'Signed out. Local data remains available offline.');
    } catch (e) {
      setState(() => message = 'Sign out failed: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!configured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text('Cloud account is not configured', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 10),
                    const Text(
                      'SBILL stays fully offline without an account. Build with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY to enable login, signup and multi-device sync.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final signedIn = user != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Account & Sync')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: signedIn ? _signedInView() : _authView(),
                ),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(message!),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.devices_outlined),
                  title: Text('One account, multiple devices'),
                  subtitle: Text(
                    'Use the same SBILL account on Android, Windows, macOS and iOS. Each device keeps local SQLite data and synchronizes changes when connected.',
                  ),
                ),
              ),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Offline remains available'),
                  subtitle: Text(
                    'Signing out stops cloud synchronization but does not delete your local billing and inventory data.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _authView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.account_circle_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 12),
      Text(signUp ? 'Create your SBILL account' : 'Sign in to SBILL',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text(signUp
          ? 'Create one account and use the same business workspace on every supported device.'
          : 'Sync your business data across supported devices while keeping billing local-first.'),
      const SizedBox(height: 20),
      TextField(
        controller: email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        decoration: const InputDecoration(
          labelText: 'Email',
          prefixIcon: Icon(Icons.email_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        decoration: const InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline),
        ),
        onSubmitted: (_) => _submit(),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: busy ? null : _submit,
          icon: busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(signUp ? Icons.person_add_outlined : Icons.login_outlined),
          label: Text(signUp ? 'Create account' : 'Sign in'),
        ),
      ),
      if (!signUp)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: busy ? null : _resetPassword,
            child: const Text('Forgot password?'),
          ),
        ),
      const Divider(height: 28),
      Center(
        child: TextButton(
          onPressed: busy ? null : () => setState(() {
            signUp = !signUp;
            message = null;
          }),
          child: Text(signUp ? 'Already have an account? Sign in' : 'New to SBILL? Create an account'),
        ),
      ),
    ],
  );

  Widget _signedInView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          CircleAvatar(
            radius: 26,
            child: Text(
              (user!.email ?? 'S').isEmpty
                  ? 'S'
                  : (user!.email ?? 'S')[0].toUpperCase(),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Signed in', style: Theme.of(context).textTheme.labelLarge),
                Text(
                  user!.email ?? 'SBILL account',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            const Icon(Icons.business_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Business workspace'),
                  Text(
                    settings.businessId == null ? 'Not linked yet' : settings.businessName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            if (settings.businessId == null)
              FilledButton.tonalIcon(
                onPressed: busy ? null : _createWorkspace,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Create'),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: settings.businessId == null || busy ? null : _syncNow,
            icon: const Icon(Icons.sync_outlined),
            label: const Text('Sync now'),
          ),
          OutlinedButton.icon(
            onPressed: busy ? null : _signOut,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Sign out'),
          ),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    authSubscription?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }
}
