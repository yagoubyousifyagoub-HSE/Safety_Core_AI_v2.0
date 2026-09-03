import '../constants/app_constants.dart';
import '../models/observation_model.dart';

/// Hand-written sample findings so Local Demo Mode has something to show
/// on the dashboard/charts immediately, without ever touching Supabase.
/// Regenerated fresh (with `DateTime.now()`-relative dates) every time this
/// is called, so the demo always looks current.
List<Observation> buildLocalDemoObservations() {
  final now = DateTime.now();

  Observation sample({
    required String title,
    required String description,
    required ObservationCategory category,
    required ObservationSeverity severity,
    required ObservationStatus status,
    required int daysAgo,
  }) {
    final createdAt = now.subtract(Duration(days: daysAgo));
    return Observation(
      localId: 'demo-$title-$daysAgo',
      projectName: AppConstants.demoProjectName,
      title: title,
      description: description,
      category: category,
      severity: severity,
      status: status,
      latitude: 24.7136,
      longitude: 46.6753,
      wasInsideGeofenceAtCapture: true,
      createdByUserId: AppConstants.localDemoUserId,
      assignedContractorId: AppConstants.localDemoUserId,
      createdAt: createdAt,
      dueDate: createdAt.add(const Duration(days: 7)),
      closedAt: status == ObservationStatus.closed ? createdAt.add(const Duration(days: 3)) : null,
    );
  }

  return [
    sample(
      title: 'Missing guardrail on scaffold — Level 3',
      description: 'Edge protection removed after material delivery; not reinstalled.',
      category: ObservationCategory.fallProtection,
      severity: ObservationSeverity.critical,
      status: ObservationStatus.open,
      daysAgo: 1,
    ),
    sample(
      title: 'Worker without hard hat in lay-down yard',
      description: 'Observed during morning walk-through near the rebar storage area.',
      category: ObservationCategory.ppe,
      severity: ObservationSeverity.medium,
      status: ObservationStatus.open,
      daysAgo: 2,
    ),
    sample(
      title: 'Exposed temporary wiring near water source',
      description: 'Extension cable running through a puddle by the mixing station.',
      category: ObservationCategory.electrical,
      severity: ObservationSeverity.high,
      status: ObservationStatus.pendingVerification,
      daysAgo: 4,
    ),
    sample(
      title: 'Blocked fire extinguisher access',
      description: 'Pallets stacked in front of the extinguisher cabinet, Building B.',
      category: ObservationCategory.fireSafety,
      severity: ObservationSeverity.medium,
      status: ObservationStatus.pendingVerification,
      daysAgo: 5,
    ),
    sample(
      title: 'Housekeeping — walkway debris',
      description: 'Offcuts and packaging left across the main pedestrian route.',
      category: ObservationCategory.housekeeping,
      severity: ObservationSeverity.low,
      status: ObservationStatus.closed,
      daysAgo: 9,
    ),
    sample(
      title: 'Unlabeled chemical containers',
      description: 'Two drums near the paint shop without hazard labeling.',
      category: ObservationCategory.chemicalHandling,
      severity: ObservationSeverity.high,
      status: ObservationStatus.closed,
      daysAgo: 12,
    ),
  ];
}
