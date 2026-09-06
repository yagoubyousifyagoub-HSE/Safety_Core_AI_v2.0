import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/observation_model.dart';
import '../../../core/providers.dart';
import '../../../core/services/local_demo_data.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../observations/widgets/status_chip.dart';

/// Pick any observation and generate its official 1-page HSE
/// non-conformance notice. `PdfReportService` already existed in the
/// codebase — this screen is what actually puts a button in front of it.
class ReportsScreen extends ConsumerStatefulWidget {
  final bool isLocalDemo;
  const ReportsScreen({super.key, this.isLocalDemo = false});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  Observation? _selected;
  bool _isGenerating = false;

  List<Observation> _loadObservations() {
    if (widget.isLocalDemo) {
      final syncService = ref.read(offlineSyncServiceProvider);
      return [...buildLocalDemoObservations(), ...syncService.pendingObservations];
    }
    // Live mode reads whatever's already cached from the dashboard's stream
    // isn't available here without duplicating a subscription, so reports
    // pulls a one-off snapshot instead of a live stream — acceptable since
    // this page is a point-in-time export, not a live view.
    return [];
  }

  Future<void> _generate(Observation o) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isGenerating = true);
    try {
      Uint8List? before;
      Uint8List? after;
      if (o.photoBeforeLocalPath != null) {
        final f = File(o.photoBeforeLocalPath!);
        if (await f.exists()) before = await f.readAsBytes();
      }
      if (o.photoAfterLocalPath != null) {
        final f = File(o.photoAfterLocalPath!);
        if (await f.exists()) after = await f.readAsBytes();
      }

      final pdfBytes = await PdfReportService.generateNonConformanceNotice(
        observation: o,
        beforePhoto: before,
        afterPhoto: after,
      );
      await PdfReportService.printOrShare(pdfBytes, fileName: '${o.localId}_notice.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.submitFailed}\n$e')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reportsTitle)),
      body: widget.isLocalDemo
          ? _buildList(context, l10n, _loadObservations())
          : _buildLiveList(context, l10n),
    );
  }

  Widget _buildLiveList(BuildContext context, AppLocalizations l10n) {
    final client = Supabase.instance.client;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: client.from('observations').select().order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final observations = snapshot.data!.map((row) => Observation.fromSupabaseRow(row)).toList();
        return _buildList(context, l10n, observations);
      },
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n, List<Observation> observations) {
    if (observations.isEmpty) {
      return Center(
        child: Text(l10n.noObservationsYet, style: const TextStyle(color: AppColors.slate500)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.selectObservationForReport, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
        const SizedBox(height: 10),
        for (final o in observations)
          Card(
            child: ListTile(
              selected: _selected?.localId == o.localId,
              onTap: () => setState(() => _selected = o),
              title: Text(o.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(o.category.name, style: const TextStyle(color: AppColors.slate500, fontSize: 12)),
              trailing: StatusChip(status: o.status),
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: (_selected == null || _isGenerating) ? null : () => _generate(_selected!),
          icon: _isGenerating
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(l10n.generateReport),
        ),
      ],
    );
  }
}
