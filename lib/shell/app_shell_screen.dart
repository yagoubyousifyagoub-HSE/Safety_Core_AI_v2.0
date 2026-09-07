import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers.dart';
import '../../core/widgets/elegant_bottom_nav.dart';
import '../../l10n/gen/app_localizations.dart';
import '../about/screens/about_app_screen.dart';
import '../auth/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../observations/screens/observations_list_screen.dart';
import '../observations/widgets/emergency_dialog.dart';
import '../reports/screens/reports_screen.dart';

/// Owns the single Scaffold for the whole signed-in experience: the four
/// persistent tabs live in an [IndexedStack] (so switching tabs never loses
/// scroll position or an in-flight stream subscription), the bottom nav is
/// the animated [ElegantBottomNav], and the Emergency Stop-Work action is a
/// shell-level FAB so it's reachable from every tab, not just Dashboard.
class AppShellScreen extends ConsumerStatefulWidget {
  final bool localDemo;
  const AppShellScreen({super.key, this.localDemo = false});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsServiceProvider);
    final isDemoMode = widget.localDemo || AuthService().isGuestSession;

    final tabs = [
      DashboardScreen(localDemo: widget.localDemo),
      ObservationsListScreen(isLocalDemo: widget.localDemo),
      ReportsScreen(isLocalDemo: widget.localDemo),
      const AboutAppScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.emergencyRed,
        tooltip: l10n.emergencyStopWork,
        onPressed: () => showDialog(
          context: context,
          builder: (_) => EmergencyDialog(
            hotlineNumber: settings.hotlineNumber.value,
            isDemoMode: isDemoMode,
          ),
        ),
        child: const Icon(Icons.warning_amber_rounded),
      ),
      bottomNavigationBar: ElegantBottomNav(
        currentIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        items: [
          NavTabItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: l10n.dashboardTab,
          ),
          NavTabItem(
            icon: Icons.fact_check_outlined,
            activeIcon: Icons.fact_check_rounded,
            label: l10n.observationsTab,
          ),
          NavTabItem(
            icon: Icons.picture_as_pdf_outlined,
            activeIcon: Icons.picture_as_pdf_rounded,
            label: l10n.reportsTab,
          ),
          NavTabItem(
            icon: Icons.info_outline,
            activeIcon: Icons.info_rounded,
            label: l10n.aboutTab,
          ),
        ],
      ),
    );
  }
}
