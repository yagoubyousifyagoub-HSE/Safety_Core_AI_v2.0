import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/observation_model.dart';
import '../../../l10n/gen/app_localizations.dart';

class StatusChip extends StatelessWidget {
  final ObservationStatus status;
  final int? trailingCount;

  const StatusChip({super.key, required this.status, this.trailingCount});

  Color get _color => switch (status) {
        ObservationStatus.open => AppColors.statusOpen,
        ObservationStatus.pendingVerification => AppColors.statusPendingVerification,
        ObservationStatus.closed => AppColors.statusClosed,
      };

  IconData get _icon => switch (status) {
        ObservationStatus.open => Icons.error_outline,
        ObservationStatus.pendingVerification => Icons.hourglass_bottom,
        ObservationStatus.closed => Icons.check_circle_outline,
      };

  String _label(AppLocalizations l10n) => switch (status) {
        ObservationStatus.open => l10n.statusOpen,
        ObservationStatus.pendingVerification => l10n.statusPendingVerification,
        ObservationStatus.closed => l10n.statusClosed,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = trailingCount != null ? '${_label(l10n)} (${trailingCount!})' : _label(l10n);

    return Chip(
      avatar: Icon(_icon, size: 16, color: _color),
      label: Text(label, style: TextStyle(color: _color, fontWeight: FontWeight.w600, fontSize: 12)),
      backgroundColor: _color.withOpacity(0.12),
      side: BorderSide(color: _color.withOpacity(0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
