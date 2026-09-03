import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/observation_model.dart';
import '../../../core/providers.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/geofence_service.dart';
import '../../../core/services/image_compressor.dart';
import '../../../core/services/watermark_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../auth/auth_service.dart';

class NewObservationScreen extends ConsumerStatefulWidget {
  final String projectName;

  /// True when reached from Local Demo Mode — every network call in this
  /// screen (geofence lookup, sync-to-Supabase) is skipped; the entry stays
  /// purely in the local offline queue.
  final bool isLocalDemo;

  const NewObservationScreen({
    super.key,
    this.projectName = 'Site A — Main Contract',
    this.isLocalDemo = false,
  });

  @override
  ConsumerState<NewObservationScreen> createState() => _NewObservationScreenState();
}

class _NewObservationScreenState extends ConsumerState<NewObservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  ObservationCategory _category = ObservationCategory.ppe;
  ObservationSeverity _severity = ObservationSeverity.medium;

  XFile? _capturedPhoto;
  Position? _position;
  bool? _isInsideGeofence;
  bool _isSubmitting = false;

  final _picker = ImagePicker();

  Future<void> _capturePhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (shot != null) setState(() => _capturedPhoto = shot);
  }

  Future<void> _tagLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    bool? insideGeofence;
    if (!widget.isLocalDemo) {
      try {
        final boundary = await _fetchProjectBoundary(widget.projectName);
        if (boundary != null) {
          insideGeofence = GeofenceService(boundary).containsPoint(
            lat: position.latitude,
            lng: position.longitude,
          );
        }
      } catch (_) {
        // No boundary registered for this project, or offline lookup failed —
        // fail open rather than blocking the field team from filing a report.
        insideGeofence = null;
      }
    }

    setState(() {
      _position = position;
      _isInsideGeofence = insideGeofence;
    });
  }

  Future<Map<String, dynamic>?> _fetchProjectBoundary(String projectName) async {
    final row = await Supabase.instance.client
        .from('project_boundaries')
        .select('geometry')
        .eq('project_name', projectName)
        .maybeSingle();
    return row == null ? null : row['geometry'] as Map<String, dynamic>;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate() || _capturedPhoto == null || _position == null) return;

    setState(() => _isSubmitting = true);

    try {
      final rawBytes = await _capturedPhoto!.readAsBytes();
      final watermarked = await WatermarkService.stamp(
        photoBytes: rawBytes,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        projectName: widget.projectName,
      );
      final compressed = await ImageCompressor.compress(watermarked);

      final dir = await getApplicationDocumentsDirectory();
      final localId = const Uuid().v4();
      final photoFile = File('${dir.path}/${localId}_before.jpg');
      await photoFile.writeAsBytes(compressed.bytes);

      final currentUserId = widget.isLocalDemo
          ? AppConstants.localDemoUserId
          : (Supabase.instance.client.auth.currentUser?.id ?? 'unknown');
      final isGuest = !widget.isLocalDemo && AuthService().isGuestSession;

      final observation = Observation(
        localId: localId,
        projectName: widget.projectName,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        category: _category,
        severity: _severity,
        latitude: _position!.latitude,
        longitude: _position!.longitude,
        wasInsideGeofenceAtCapture: _isInsideGeofence ?? true,
        photoBeforeLocalPath: photoFile.path,
        createdByUserId: currentUserId,
        // Guests and local-demo sessions self-assign so the demo lets them
        // complete the full raise -> after-photo -> pendingVerification
        // loop without needing a real consultant/contractor pairing (see
        // the "guests sandboxed to demo project" RLS policies in schema.sql).
        assignedContractorId: (isGuest || widget.isLocalDemo) ? currentUserId : null,
        createdAt: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 7)),
      );

      final syncService = ref.read(offlineSyncServiceProvider);
      await syncService.enqueue(observation);

      String message;
      if (widget.isLocalDemo) {
        // Never attempt a network call — Local Demo Mode's entire point is
        // to work with zero connectivity.
        message = l10n.savedLocalDemo;
      } else {
        final isOnline = await ConnectivityService().isOnline();
        if (isOnline) {
          await syncService.trySyncAll();
          message = l10n.submittedOnline;
        } else {
          message = l10n.savedOffline;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newObservationTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(labelText: l10n.fieldTitle),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldTitle : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.fieldDescription),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.fieldDescription : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ObservationCategory>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.fieldCategory),
              items: ObservationCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ObservationSeverity>(
              initialValue: _severity,
              decoration: InputDecoration(labelText: l10n.fieldSeverity),
              items: ObservationSeverity.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name)))
                  .toList(),
              onChanged: (v) => setState(() => _severity = v ?? _severity),
            ),
            const SizedBox(height: 20),
            _photoCard(l10n),
            const SizedBox(height: 14),
            _locationCard(l10n),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : Text(l10n.submitObservation),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCard(AppLocalizations l10n) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_capturedPhoto != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(File(_capturedPhoto!.path), height: 180, fit: BoxFit.cover),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _capturePhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(_capturedPhoto == null ? l10n.capturePhoto : l10n.retakePhoto),
              ),
            ],
          ),
        ),
      );

  Widget _locationCard(AppLocalizations l10n) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_position != null)
                Text(
                  'Lat ${_position!.latitude.toStringAsFixed(6)}, '
                  'Lng ${_position!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(color: AppColors.slate500, fontSize: 12),
                ),
              if (_isInsideGeofence == false) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.statusPendingVerification, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.outsideGeofence,
                        style: const TextStyle(color: AppColors.statusPendingVerification, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _tagLocation,
                icon: const Icon(Icons.my_location),
                label: Text(l10n.getLocation),
              ),
            ],
          ),
        ),
      );
}
