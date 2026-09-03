import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  static const String _paypalHandle = '@yagoupyo';
  static const String _paypalUrl = 'https://paypal.me/yagoupyo';

  Future<void> _openPaypal() async {
    final uri = Uri.parse(_paypalUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.shield_moon_outlined, size: 64, color: AppColors.accent),
          const SizedBox(height: 12),
          Center(
            child: Text(l10n.appTitle, style: Theme.of(context).textTheme.headlineSmall),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              l10n.aboutStandards,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 28),

          _infoCard(
            icon: Icons.verified_user_outlined,
            title: 'OSHA 29 CFR 1926 / 1910',
            subtitle: 'US construction & general industry HSE recordkeeping alignment',
          ),
          const SizedBox(height: 10),
          _infoCard(
            icon: Icons.workspace_premium_outlined,
            title: 'ISO 45001:2018',
            subtitle: 'Occupational health & safety management systems',
          ),
          const SizedBox(height: 10),
          _infoCard(
            icon: Icons.query_stats_outlined,
            title: 'ANSI Z16.1',
            subtitle: 'LTIFR / TRIR recordable incident rate methodology',
          ),
          const SizedBox(height: 28),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.leadDesigner, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text(
                    'HSE Engineer Yagoub Mohamed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(l10n.supportDevelopment, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openPaypal,
            icon: const Icon(Icons.volunteer_activism_outlined),
            label: Text('${l10n.donateViaPaypal} ($_paypalHandle)'),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required IconData icon, required String title, required String subtitle}) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
      ),
    );
  }
}
