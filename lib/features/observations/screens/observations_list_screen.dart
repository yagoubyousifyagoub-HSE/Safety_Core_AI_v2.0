import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/observation_model.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers.dart';
import '../../../core/services/local_demo_data.dart';
import '../../../core/widgets/stream_error_state.dart';
import '../../../l10n/gen/app_localizations.dart';
import 'observation_closure_screen.dart';

/// The missing "middle" page: a real, tappable list of every observation,
/// wired to [ObservationClosureScreen] — previously that screen existed in
/// the codebase but was never reachable from anywhere in the app.
class ObservationsListScreen extends ConsumerStatefulWidget {
  final bool isLocalDemo;
  const ObservationsListScreen({super.key, this.isLocalDemo = false});

  @override
  ConsumerState<ObservationsListScreen> createState() => _ObservationsListScreenState();
}

class _ObservationsListScreenState extends ConsumerState<ObservationsListScreen> {
  // In Local Demo Mode there's no real Supabase profile to read a role
  // from, so a visible toggle lets you exercise both halves of the
  // workflow (contractor after-photo vs. consultant sign-off) from the
  // same device. For a real signed-in account, role should come from
  // AuthService.fetchCurrentProfile() instead — see the note in About.
  UserRole _demoRole = UserRole.contractor;
  int _liveRetryCount = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.observationsListTitle),
        bottom: widget.isLocalDemo
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(l10n.roleToggleContractor, style: const TextStyle(fontSize: 12)),
                          selected: _demoRole == UserRole.contractor,
                          onSelected: (_) => setState(() => _demoRole = UserRole.contractor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(l10n.roleToggleConsultant, style: const TextStyle(fontSize: 12)),
                          selected: _demoRole == UserRole.consultant,
                          onSelected: (_) => setState(() => _demoRole = UserRole.consultant),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: widget.isLocalDemo ? _buildLocalDemoList(context, l10n) : _buildLiveList(context, l10n),
    );
  }

  Widget _buildLocalDemoList(BuildContext context, AppLocalizations l10n) {
    final syncService = ref.read(offlineSyncServiceProvider);
    final observations = [
      ...buildLocalDemoObservations(),
      ...syncService.pendingObservations,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return _list(context, observations, currentUserRole: _demoRole);
  }

  Widget _buildLiveList(BuildContext context, AppLocalizations l10n) {
    final client = Supabase.instance.client;
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_liveRetryCount),
      stream: client
          .from('observations')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .timeout(
            const Duration(seconds: 12),
            onTimeout: (sink) => sink.addError(
              TimeoutException('No response after 12s — check Realtime replication and RLS policies.'),
            ),
          ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StreamErrorState(
            error: snapshot.error.toString(),
            onRetry: () => setState(() => _liveRetryCount++),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final observations = snapshot.data!.map((row) => Observation.fromSupabaseRow(row)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // Real accounts: role should come from AuthService.fetchCurrentProfile()
        // once that's wired into a profile-loading layer above this screen.
        return _list(context, observations, currentUserRole: UserRole.contractor);
      },
    );
  }

  Widget _list(BuildContext context, List<Observation> observations, {required UserRole currentUserRole}) {
    final l10n = AppLocalizations.of(context)!;
    if (observations.isEmpty) {
      return Center(
        child: Text(l10n.noObservationsYet, style: const TextStyle(color: AppColors.slate500)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: observations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final o = observations[index];
        return Card(
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ObservationClosureScreen(
                  observation: o,
                  currentUserRole: currentUserRole,
                  isLocalDemo: widget.isLocalDemo,
                ),
              ),
            ),
            title: Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${o.category.name} · ${o.severity.name}',
              style: const TextStyle(color: AppColors.slate500, fontSize: 12),
            ),
            trailing: _MiniStatusDot(status: o.status),
          ),
        );
      },
    );
  }
}

class _MiniStatusDot extends StatelessWidget {
  final ObservationStatus status;
  const _MiniStatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ObservationStatus.open => AppColors.statusOpen,
      ObservationStatus.pendingVerification => AppColors.statusPendingVerification,
      ObservationStatus.closed => AppColors.statusClosed,
    };
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
