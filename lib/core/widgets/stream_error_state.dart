import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../../l10n/gen/app_localizations.dart';

/// Shown instead of an infinite spinner when a Supabase stream/future never
/// resolves — surfaces the real error (timeout, RLS denial, network
/// failure, etc.) plus a one-tap retry, instead of leaving the screen
/// silently stuck forever. Shared across dashboard, observations list, and
/// reports — any screen reading live data from Supabase should use this in
/// its StreamBuilder/FutureBuilder's error branch.
class StreamErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const StreamErrorState({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.statusOpen),
            const SizedBox(height: 14),
            Text(
              l10n.dashboardLoadFailed,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
