import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/sbill_logo.dart';
import '../../core/cloud/cloud_config.dart';
import '../../core/widgets/user_facing_error.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const websiteUrl = 'https://sbill-showcase.vercel.app/';
  static const founderUrl = 'https://sbill-showcase.vercel.app/founder.html';
  static const portfolioV2 = 'https://mohammad-sadab-portfolio-v2.vercel.app/';
  static const portfolio = 'https://sadab01.vercel.app/';
  static const github = 'https://github.com/shinuXcode/shop-inventory-app';
  static const version = '1.2.0';
  static const build = '3';

  Future<void> _open(BuildContext context, String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That link could not be opened. Please try again.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFacingError(e, fallback: 'That link could not be opened. Please try again.'))),
        );
      }
    }
  }

  Widget _link(BuildContext context, String title, String subtitle, String url, IconData icon) =>
      Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.open_in_new_outlined),
          onTap: () => _open(context, url),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About SBILL')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    const SBillLogo(size: 92),
                    const SizedBox(height: 16),
                    Text(
                      'SBILL',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Simple Billing. Smarter Business.',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _link(context, 'SBILL Website', 'Product website, downloads and support', websiteUrl, Icons.language_outlined),
              _link(context, 'Founder Page', 'Mohammad Sadab — founder and builder', founderUrl, Icons.person_outline),
              _link(context, 'Founder Portfolio V2', portfolioV2, portfolioV2, Icons.web_outlined),
              _link(context, 'Founder Portfolio', portfolio, portfolio, Icons.public_outlined),
              _link(context, 'GitHub Repository', 'SBILL source code and releases', github, Icons.code_outlined),
              _link(context, 'Support Center', 'Create or track a support request', 'https://sbill-showcase.vercel.app/support.html', Icons.support_agent_outlined),
              const SizedBox(height: 18),
              Card(
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Version'),
                      subtitle: Text('SBILL 1.2.0 (build 3)'),
                    ),
                    ListTile(
                      leading: Icon(Icons.sync_outlined),
                      title: const Text('Account & sync'),
                      subtitle: Text(
                        CloudConfig.configured
                            ? 'Cloud account features are configured for this build. Manage sign-in and workspace sync from Account & Sync.'
                            : 'Cloud account is not configured in this build. SBILL continues to work offline.',
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'SBILL is offline-first. Billing, inventory and invoices remain available without an account. '
                    'An optional SBILL account connects the same business workspace across supported devices and the website.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
