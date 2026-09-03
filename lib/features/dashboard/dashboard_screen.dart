import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/observation_model.dart';
import '../../core/providers.dart';
import '../../core/services/local_demo_data.dart';
import '../../l10n/gen/app_localizations.dart';
import '../about/screens/about_app_screen.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';
import '../observations/screens/new_observation_screen.dart';
import '../observations/widgets/emergency_dialog.dart';
import '../observations/widgets/status_chip.dart';
import '../observations/widgets/sync_badge.dart';
import 'kpi_calculator.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  /// When true, this screen never touches Supabase — no Auth session, no
  /// Realtime stream, no network call of any kind. Data is a static local
  /// sample set plus anything already sitting in the offline Hive queue.
  /// This exists specifically so the app can be explored end-to-end when
  /// the backend is unreachable (DNS issues, no connectivity, first-run
  /// demoing without a configured Supabase project, etc.).
  final bool localDemo;

  const DashboardScreen({super.key, this.localDemo = false});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  static const String _emergencyHotline = '+966500000000'; // replace with site HSE hotline

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = AuthService();
    final isGuest = !widget.localDemo && authService.isGuestSession;
    final isDemoMode = widget.localDemo || isGuest;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboardTitle),
        actions: [
          // Sync status is meaningless in local demo mode — it will never
          // reach a real backend, so showing "pending sync" would just be
          // confusing noise.
          if (!widget.localDemo)
            const Padding(padding: EdgeInsets.only(right: 8), child: SyncBadge()),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AboutAppScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emergencyRed,
        onPressed: () => showDialog(
          context: context,
          builder: (_) => EmergencyDialog(hotlineNumber: _emergencyHotline, isDemoMode: isDemoMode),
        ),
        icon: const Icon(Icons.warning_amber_rounded),
        label: Text(l10n.emergencyStopWork),
      ),
      body: widget.localDemo
          ? _buildLocalDemoBody(context, l10n, isDemoMode)
          : _buildLiveBody(context, l10n, isGuest),
    );
  }

  /// Static sample data + whatever's already queued locally — no network.
  Widget _buildLocalDemoBody(BuildContext context, AppLocalizations l10n, bool isDemoMode) {
    final syncService = ref.read(offlineSyncServiceProvider);
    final observations = [
      ...buildLocalDemoObservations(),
      ...syncService.pendingObservations,
    ];

    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LocalDemoBanner(
            onExit: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            ),
          ),
          const SizedBox(height: 16),
          _KpiSection(observations: observations),
          const SizedBox(height: 24),
          Text(l10n.observationsByCategory, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _CategoryBarChart(observations: observations),
          const SizedBox(height: 24),
          Text(l10n.statusDistribution, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _StatusLegend(observations: observations, isLocalDemo: true),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  /// Realtime Supabase stream — used for real accounts and guest sessions.
  Widget _buildLiveBody(BuildContext context, AppLocalizations l10n, bool isGuest) {
    final client = Supabase.instance.client;
    final authService = AuthService();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: client.from('observations').stream(primaryKey: ['id']).order('created_at'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final observations = snapshot.data!.map((row) => Observation.fromSupabaseRow(row)).toList();

        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isGuest) ...[
                _GuestBanner(onSignOut: () async {
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                }),
                const SizedBox(height: 16),
              ],
              _KpiSection(observations: observations),
              const SizedBox(height: 24),
              Text(l10n.observationsByCategory, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _CategoryBarChart(observations: observations),
              const SizedBox(height: 24),
              Text(l10n.statusDistribution, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _StatusLegend(observations: observations, isLocalDemo: false),
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}

class _KpiSection extends StatelessWidget {
  final List<Observation> observations;
  const _KpiSection({required this.observations});

  /// Placeholder hours-worked base until wired to the `site_kpi_inputs`
  /// table (monthly manhours submitted by each contractor). Swap for a live
  /// FutureBuilder query once that reporting flow exists.
  static const double _assumedHoursWorked = 480000;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final critical = observations.where((o) => o.severity == ObservationSeverity.critical).length;
    final open = observations.where((o) => o.status == ObservationStatus.open).length;
    final overdue = observations
        .where((o) =>
            o.status != ObservationStatus.closed &&
            o.dueDate != null &&
            o.dueDate!.isBefore(DateTime.now()))
        .length;

    final ltifr = KpiCalculator.calculateLTIFR(
      lostTimeInjuries: critical,
      totalHoursWorked: _assumedHoursWorked,
    );
    final trir = KpiCalculator.calculateTRIR(
      recordableIncidents: observations.length,
      totalHoursWorked: _assumedHoursWorked,
    );

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _KpiCard(label: l10n.kpiLtifr, value: ltifr.toStringAsFixed(2), accent: AppColors.statusOpen),
        _KpiCard(label: l10n.kpiTrir, value: trir.toStringAsFixed(2), accent: AppColors.severityHigh),
        _KpiCard(label: l10n.kpiOpenObservations, value: '$open', accent: AppColors.accent),
        _KpiCard(label: l10n.kpiOverdue, value: '$overdue', accent: AppColors.statusPendingVerification),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _KpiCard({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: accent)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  final List<Observation> observations;
  const _CategoryBarChart({required this.observations});

  @override
  Widget build(BuildContext context) {
    final counts = <ObservationCategory, int>{};
    for (final o in observations) {
      counts[o.category] = (counts[o.category] ?? 0) + 1;
    }
    final categories = counts.keys.toList();
    final maxY = counts.values.isEmpty
        ? 5.0
        : (counts.values.reduce((a, b) => a > b ? a : b)).toDouble() + 1;

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= categories.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      categories[i].name,
                      style: const TextStyle(fontSize: 9, color: AppColors.slate500),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < categories.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[categories[i]]!.toDouble(),
                    color: AppColors.accent,
                    width: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusLegend extends StatelessWidget {
  final List<Observation> observations;
  final bool isLocalDemo;
  const _StatusLegend({required this.observations, required this.isLocalDemo});

  @override
  Widget build(BuildContext context) {
    int countOf(ObservationStatus s) => observations.where((o) => o.status == s).length;
    final isGuest = !isLocalDemo && AuthService().isGuestSession;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        StatusChip(status: ObservationStatus.open, trailingCount: countOf(ObservationStatus.open)),
        StatusChip(
          status: ObservationStatus.pendingVerification,
          trailingCount: countOf(ObservationStatus.pendingVerification),
        ),
        StatusChip(status: ObservationStatus.closed, trailingCount: countOf(ObservationStatus.closed)),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: Text(AppLocalizations.of(context)!.newObservationTitle),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => NewObservationScreen(
                projectName: (isGuest || isLocalDemo) ? AppConstants.demoProjectName : 'Site A — Main Contract',
                isLocalDemo: isLocalDemo,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shown at the top of the dashboard for anonymous "try the app" sessions —
/// makes it unambiguous that everything below is sandboxed demo data, and
/// offers a one-tap way to sign out and switch to a real email-verified
/// account.
class _GuestBanner extends StatelessWidget {
  final VoidCallback onSignOut;
  const _GuestBanner({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.offlineAmber, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.explore_outlined, color: AppColors.offlineAmber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.guestModeBanner,
                style: const TextStyle(fontSize: 12, color: AppColors.slate200),
              ),
            ),
            TextButton(
              onPressed: onSignOut,
              child: Text(l10n.guestModeAction, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown at the top of the dashboard in Local Demo Mode — makes it explicit
/// that this session never talks to the network at all (as opposed to
/// Guest Mode, which is a real sandboxed Supabase session).
class _LocalDemoBanner extends StatelessWidget {
  final VoidCallback onExit;
  const _LocalDemoBanner({required this.onExit});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.slate500, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.phonelink_off_outlined, color: AppColors.slate500, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.localDemoBanner,
                style: const TextStyle(fontSize: 12, color: AppColors.slate200),
              ),
            ),
            TextButton(
              onPressed: onExit,
              child: Text(l10n.guestModeAction, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
