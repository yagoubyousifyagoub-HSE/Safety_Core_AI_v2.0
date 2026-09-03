enum ObservationCategory {
  ppe,
  fallProtection,
  electrical,
  housekeeping,
  fireSafety,
  environmental,
  machineGuarding,
  chemicalHandling,
  ergonomics,
  other,
}

enum ObservationSeverity { low, medium, high, critical }

enum ObservationStatus { open, pendingVerification, closed }

extension ObservationCategoryX on ObservationCategory {
  static ObservationCategory fromString(String v) => ObservationCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ObservationCategory.other,
      );
}

extension ObservationSeverityX on ObservationSeverity {
  static ObservationSeverity fromString(String v) => ObservationSeverity.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ObservationSeverity.medium,
      );
}

extension ObservationStatusX on ObservationStatus {
  static ObservationStatus fromString(String v) => ObservationStatus.values.firstWhere(
        (e) => e.name == v,
        orElse: () => ObservationStatus.open,
      );
}

/// A single field finding, from raise → corrective action → sign-off.
///
/// [localId] is a client-generated UUID assigned at creation time and is
/// always stable across the offline queue → Supabase round trip, so the
/// remote `id` (server default `gen_random_uuid()`) can be reconciled with
/// whatever the device already queued, even after a crash mid-sync.
class Observation {
  final String localId;
  String? remoteId;

  final String projectName;
  final String title;
  final String description;
  final ObservationCategory category;
  final ObservationSeverity severity;
  ObservationStatus status;

  final double latitude;
  final double longitude;
  final bool wasInsideGeofenceAtCapture;

  String? photoBeforeLocalPath;
  String? photoBeforeUrl;
  String? photoAfterLocalPath;
  String? photoAfterUrl;
  String? signatureLocalPath;
  String? signatureUrl;

  final String createdByUserId;
  final String? assignedContractorId;
  final DateTime createdAt;
  final DateTime? dueDate;
  DateTime? closedAt;

  Observation({
    required this.localId,
    this.remoteId,
    required this.projectName,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    this.status = ObservationStatus.open,
    required this.latitude,
    required this.longitude,
    required this.wasInsideGeofenceAtCapture,
    this.photoBeforeLocalPath,
    this.photoBeforeUrl,
    this.photoAfterLocalPath,
    this.photoAfterUrl,
    this.signatureLocalPath,
    this.signatureUrl,
    required this.createdByUserId,
    this.assignedContractorId,
    required this.createdAt,
    this.dueDate,
    this.closedAt,
  });

  /// Map shape written to the Hive offline-queue box. Deliberately flat and
  /// primitives-only so it can be stored without a generated TypeAdapter.
  Map<String, dynamic> toQueueMap() => {
        'localId': localId,
        'remoteId': remoteId,
        'projectName': projectName,
        'title': title,
        'description': description,
        'category': category.name,
        'severity': severity.name,
        'status': status.name,
        'latitude': latitude,
        'longitude': longitude,
        'wasInsideGeofenceAtCapture': wasInsideGeofenceAtCapture,
        'photoBeforeLocalPath': photoBeforeLocalPath,
        'photoBeforeUrl': photoBeforeUrl,
        'photoAfterLocalPath': photoAfterLocalPath,
        'photoAfterUrl': photoAfterUrl,
        'signatureLocalPath': signatureLocalPath,
        'signatureUrl': signatureUrl,
        'createdByUserId': createdByUserId,
        'assignedContractorId': assignedContractorId,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'closedAt': closedAt?.toIso8601String(),
      };

  factory Observation.fromQueueMap(Map<dynamic, dynamic> m) => Observation(
        localId: m['localId'] as String,
        remoteId: m['remoteId'] as String?,
        projectName: m['projectName'] as String,
        title: m['title'] as String,
        description: m['description'] as String,
        category: ObservationCategoryX.fromString(m['category'] as String),
        severity: ObservationSeverityX.fromString(m['severity'] as String),
        status: ObservationStatusX.fromString(m['status'] as String),
        latitude: (m['latitude'] as num).toDouble(),
        longitude: (m['longitude'] as num).toDouble(),
        wasInsideGeofenceAtCapture: m['wasInsideGeofenceAtCapture'] as bool? ?? true,
        photoBeforeLocalPath: m['photoBeforeLocalPath'] as String?,
        photoBeforeUrl: m['photoBeforeUrl'] as String?,
        photoAfterLocalPath: m['photoAfterLocalPath'] as String?,
        photoAfterUrl: m['photoAfterUrl'] as String?,
        signatureLocalPath: m['signatureLocalPath'] as String?,
        signatureUrl: m['signatureUrl'] as String?,
        createdByUserId: m['createdByUserId'] as String,
        assignedContractorId: m['assignedContractorId'] as String?,
        createdAt: DateTime.parse(m['createdAt'] as String),
        dueDate: m['dueDate'] != null ? DateTime.parse(m['dueDate'] as String) : null,
        closedAt: m['closedAt'] != null ? DateTime.parse(m['closedAt'] as String) : null,
      );

  /// Payload shape for the Supabase `observations` table insert/upsert.
  /// `id` is only included when we already know the remote id (idempotent
  /// retry after a partial sync), otherwise we let Postgres default it and
  /// use `localId` as the upsert `on_conflict` key via a matching column.
  Map<String, dynamic> toSupabasePayload() => {
        if (remoteId != null) 'id': remoteId,
        'local_id': localId,
        'project_name': projectName,
        'title': title,
        'description': description,
        'category': category.name,
        'severity': severity.name,
        'status': status.name,
        'latitude': latitude,
        'longitude': longitude,
        'was_inside_geofence_at_capture': wasInsideGeofenceAtCapture,
        'photo_before_url': photoBeforeUrl,
        'photo_after_url': photoAfterUrl,
        'signature_url': signatureUrl,
        'created_by': createdByUserId,
        'assigned_contractor_id': assignedContractorId,
        'created_at': createdAt.toIso8601String(),
        'due_date': dueDate?.toIso8601String(),
        'closed_at': closedAt?.toIso8601String(),
      };

  factory Observation.fromSupabaseRow(Map<String, dynamic> row) => Observation(
        localId: row['local_id'] as String? ?? row['id'] as String,
        remoteId: row['id'] as String,
        projectName: row['project_name'] as String,
        title: row['title'] as String,
        description: row['description'] as String? ?? '',
        category: ObservationCategoryX.fromString(row['category'] as String),
        severity: ObservationSeverityX.fromString(row['severity'] as String),
        status: ObservationStatusX.fromString(row['status'] as String),
        latitude: (row['latitude'] as num).toDouble(),
        longitude: (row['longitude'] as num).toDouble(),
        wasInsideGeofenceAtCapture: row['was_inside_geofence_at_capture'] as bool? ?? true,
        photoBeforeUrl: row['photo_before_url'] as String?,
        photoAfterUrl: row['photo_after_url'] as String?,
        signatureUrl: row['signature_url'] as String?,
        createdByUserId: row['created_by'] as String,
        assignedContractorId: row['assigned_contractor_id'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        dueDate: row['due_date'] != null ? DateTime.parse(row['due_date'] as String) : null,
        closedAt: row['closed_at'] != null ? DateTime.parse(row['closed_at'] as String) : null,
      );
}
