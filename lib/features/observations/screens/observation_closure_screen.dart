import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:signature/signature.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/observation_model.dart';
import '../../../core/models/user_role.dart';
import '../../../core/providers.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/image_compressor.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../widgets/status_chip.dart';

class ObservationClosureScreen extends ConsumerStatefulWidget {
  final Observation observation;
  final UserRole currentUserRole;

  const ObservationClosureScreen({
    super.key,
    required this.observation,
    required this.currentUserRole,
  });

  @override
  ConsumerState<ObservationClosureScreen> createState() => _ObservationClosureScreenState();
}

class _ObservationClosureScreenState extends ConsumerState<ObservationClosureScreen> {
  final _picker = ImagePicker();
  final _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.white,
    exportBackgroundColor: AppColors.slate800,
  );

  XFile? _afterPhoto;
  bool _isSubmitting = false;

  bool get _isConsultant => widget.currentUserRole.canSignOff;

  @override
  void dispose() {
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _captureAfterPhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (shot != null) setState(() => _afterPhoto = shot);
  }

  Future<void> _submitContractorCorrectiveAction() async {
    if (_afterPhoto == null) return;
    setState(() => _isSubmitting = true);
    try {
      final bytes = await _afterPhoto!.readAsBytes();
      final compressed = await ImageCompressor.compress(bytes);
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.observation.localId}_after.jpg');
      await file.writeAsBytes(compressed.bytes);

      final observation = widget.observation
        ..photoAfterLocalPath = file.path
        ..status = ObservationStatus.pendingVerification;

      await _persist(observation);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitConsultantSignOff() async {
    final l10n = AppLocalizations.of(context)!;
    if (_signatureController.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.closureRequiresSignature)));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final signatureBytes = await _signatureController.toPngBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${widget.observation.localId}_signature.png');
      if (signatureBytes != null) await file.writeAsBytes(signatureBytes);

      final observation = widget.observation
        ..signatureLocalPath = file.path
        ..status = ObservationStatus.closed
        ..closedAt = DateTime.now();

      await _persist(observation);
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _persist(Observation observation) async {
    final syncService = ref.read(offlineSyncServiceProvider);
    await syncService.enqueue(observation);
    if (await ConnectivityService().isOnline()) {
      await syncService.trySyncAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final o = widget.observation;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.closureTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(o.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              StatusChip(status: o.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(o.description, style: const TextStyle(color: AppColors.slate500, fontSize: 13)),
          const SizedBox(height: 20),

          if (!_isConsultant) ...[
            Text(l10n.afterPhotoLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            if (_afterPhoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(_afterPhoto!.path), height: 200, fit: BoxFit.cover),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _captureAfterPhoto,
              icon: const Icon(Icons.camera_alt_outlined),
              label: Text(l10n.capturePhoto),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: (_afterPhoto == null || _isSubmitting) ? null : _submitContractorCorrectiveAction,
              child: Text(l10n.submitObservation),
            ),
          ] else ...[
            Text(l10n.consultantSignOff, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.slate800,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.slate700),
              ),
              child: Signature(controller: _signatureController, backgroundColor: Colors.transparent),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _signatureController.clear(),
                child: Text(l10n.clearSignature),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitConsultantSignOff,
              child: Text(l10n.confirmClosure),
            ),
          ],
        ],
      ),
    );
  }
}
