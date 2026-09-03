import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../l10n/gen/app_localizations.dart';

/// Full-screen-weight modal for declaring an imminent-danger Stop-Work
/// Order. The pulsing banner is intentionally aggressive — this dialog is
/// only ever shown when someone has already decided to invoke it.
class EmergencyDialog extends StatefulWidget {
  final String hotlineNumber;

  /// True for guest/demo sessions — the call button is replaced with a
  /// disabled notice so a person exploring the app can never place a real
  /// emergency call by accident.
  final bool isDemoMode;

  const EmergencyDialog({super.key, required this.hotlineNumber, this.isDemoMode = false});

  @override
  State<EmergencyDialog> createState() => _EmergencyDialogState();
}

class _EmergencyDialogState extends State<EmergencyDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _callHotline() async {
    if (widget.isDemoMode) return; // never place a real call from a guest/demo session
    final uri = Uri(scheme: 'tel', path: widget.hotlineNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      backgroundColor: AppColors.slate900,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.emergencyRed, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.12);
                final opacity = 0.55 + (_pulseController.value * 0.45);
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  color: AppColors.emergencyRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.pan_tool_alt, color: Colors.white, size: 44),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.emergencyStopWork,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.emergencyRed,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.emergencyBody,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.slate200, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            if (widget.isDemoMode)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.slate800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.slate700),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.slate500),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.guestEmergencyDisabled,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergencyRed),
                  onPressed: _callHotline,
                  icon: const Icon(Icons.call),
                  label: Text(l10n.callHseHotline),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.acknowledge, style: const TextStyle(color: AppColors.slate500)),
            ),
          ],
        ),
      ),
    );
  }
}
