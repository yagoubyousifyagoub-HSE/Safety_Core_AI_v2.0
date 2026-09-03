import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Small pill in the app bar reflecting the local offline queue:
/// grey/hidden dot = nothing pending, amber = N pending, spinner = syncing.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final syncService = ref.watch(offlineSyncServiceProvider);

    return StreamBuilder<int>(
      stream: syncService.pendingCountStream,
      initialData: syncService.pendingCount,
      builder: (context, countSnapshot) {
        final pending = countSnapshot.data ?? 0;

        return StreamBuilder<SyncState>(
          stream: syncService.stateStream,
          initialData: SyncState.idle,
          builder: (context, stateSnapshot) {
            final isSyncing = stateSnapshot.data == SyncState.syncing;

            final Color color = isSyncing
                ? AppColors.accent
                : (pending > 0 ? AppColors.offlineAmber : AppColors.syncedGreen);
            final String label = isSyncing
                ? l10n.syncing
                : (pending > 0 ? l10n.syncPending(pending) : l10n.syncAllUpToDate);
            final IconData icon = isSyncing
                ? Icons.sync
                : (pending > 0 ? Icons.cloud_off_outlined : Icons.cloud_done_outlined);

            return GestureDetector(
              onTap: () => syncService.trySyncAll(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
