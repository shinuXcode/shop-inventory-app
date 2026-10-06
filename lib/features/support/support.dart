import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/user_facing_error.dart';

import '../account/account.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/settings/app_settings.dart';

class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  final subject = TextEditingController();
  final message = TextEditingController();

  String category = 'General';
  bool loading = true;
  bool sending = false;
  List<Map<String, dynamic>> tickets = const [];

  bool get configured => CloudConfig.configured;
  SupabaseClient get client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    if (!configured) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      final user = client.auth.currentUser;
      if (user != null) {
        final rows = await client
            .from('support_tickets')
            .select('id,category,subject,message,status,priority,admin_reply,created_at,updated_at')
            .eq('user_id', user.id)
            .order('updated_at', ascending: false);
        if (mounted) setState(() => tickets = List<Map<String, dynamic>>.from(rows));
      }
    } catch (e) {
      if (mounted) _message(userFacingError(e, fallback: 'Support requests are temporarily unavailable.'));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submit() async {
    if (!configured || sending) return;
    final user = client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
      await _loadTickets();
      return;
    }

    final s = subject.text.trim();
    final m = message.text.trim();
    if (s.length < 3 || m.length < 5) {
      _message('Enter a clear subject and message.');
      return;
    }

    setState(() => sending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = AppSettings(prefs);
      await client.from('support_tickets').insert({
        'user_id': user.id,
        'business_id': settings.businessId,
        'category': category,
        'subject': s,
        'message': m,
        'priority': 'normal',
      });
      subject.clear();
      message.clear();
      _message('Support request submitted.');
      await _loadTickets();
    } catch (e) {
      _message(userFacingError(e, fallback: 'Your support request could not be submitted. Please try again.'));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _close(String id) async {
    if (!configured || client.auth.currentUser == null) return;
    try {
      await client.rpc('close_support_ticket', params: {'p_ticket_id': id});
      await _loadTickets();
    } catch (e) {
      _message(userFacingError(e, fallback: 'The request could not be closed. Please try again.'));
    }
  }

  void _message(String value) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = configured && client.auth.currentUser != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Support Center')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.support_agent_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SBILL Support', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            Text(
                              !configured
                                  ? 'Online support is not configured in this build.'
                                  : !signedIn
                                      ? 'Sign in with your SBILL account to create and track support requests.'
                                      : 'Support requests use the same SBILL account and are visible on the website too.',
                            ),
                            if (configured && !signedIn) ...[
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
                                  await _loadTickets();
                                  if (mounted) setState(() {});
                                },
                                icon: const Icon(Icons.login_outlined),
                                label: const Text('Sign in'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (configured && signedIn) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create support request', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          items: const [
                            DropdownMenuItem(value: 'General', child: Text('General')),
                            DropdownMenuItem(value: 'Bug', child: Text('Bug report')),
                            DropdownMenuItem(value: 'Billing', child: Text('Billing issue')),
                            DropdownMenuItem(value: 'Sync', child: Text('Account / sync')),
                            DropdownMenuItem(value: 'Feature', child: Text('Feature request')),
                          ],
                          onChanged: sending ? null : (value) => setState(() => category = value ?? 'General'),
                          decoration: const InputDecoration(labelText: 'Category'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: subject,
                          enabled: !sending,
                          decoration: const InputDecoration(labelText: 'Subject'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: message,
                          enabled: !sending,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(labelText: 'Describe the issue or request'),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: sending ? null : _submit,
                          icon: sending
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.send_outlined),
                          label: const Text('Send request'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _contactCard(),
                const SizedBox(height: 16),
                Text('My requests', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (loading)
                  const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                else if (tickets.isEmpty)
                  const Card(child: ListTile(title: Text('No support requests yet.')))
                else
                  ...tickets.map(_ticket),
              ],
              if (!configured) ...[
                const SizedBox(height: 16),
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.cloud_off_outlined),
                    title: Text('Online support is waiting for cloud configuration'),
                    subtitle: Text('Once the SBILL Supabase project is configured, this center will use the same account and tickets as the website.'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Direct support', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('Use email, WhatsApp, or the call action. The support phone number is not displayed in the interface.'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('mailto:mrsadabflight@gmail.com?subject=SBILL%20Support'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Email support'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('https://wa.me/917366815917?text=Hello%20SBILL%20Support'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('WhatsApp'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse('tel:+917366815917'),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.call_outlined),
                    label: const Text('Call support'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _ticket(Map<String, dynamic> ticket) {
    final status = ticket['status']?.toString() ?? 'open';
    final reply = (ticket['admin_reply']?.toString() ?? '').trim();
    final categoryLabel = ticket['category']?.toString() ?? 'General';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(status == 'closed' ? Icons.check_circle_outline : Icons.support_agent_outlined),
        title: Text(ticket['subject']?.toString() ?? 'Support request'),
        subtitle: Text(categoryLabel + ' • ' + status.toUpperCase()),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(ticket['message']?.toString() ?? ''),
          ),
          if (reply.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Support reply\n' + reply),
            ),
          ],
          if (status != 'closed')
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _close(ticket['id'].toString()),
                child: const Text('Close request'),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }
}
