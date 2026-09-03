import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/observation_model.dart';

class PdfReportService {
  PdfReportService._();

  static const PdfColor _slate900 = PdfColor.fromInt(0xFF0F172A);
  static const PdfColor _slate500 = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _slate200 = PdfColor.fromInt(0xFFE2E8F0);

  static PdfColor _severityColor(ObservationSeverity s) => switch (s) {
        ObservationSeverity.low => const PdfColor.fromInt(0xFF60A5FA),
        ObservationSeverity.medium => const PdfColor.fromInt(0xFFF59E0B),
        ObservationSeverity.high => const PdfColor.fromInt(0xFFF97316),
        ObservationSeverity.critical => const PdfColor.fromInt(0xFFDC2626),
      };

  /// Builds a single-page A4 non-conformance / corrective-action notice
  /// suitable for printing and physically posting at the affected work area.
  static Future<Uint8List> generateNonConformanceNotice({
    required Observation observation,
    Uint8List? beforePhoto,
    Uint8List? afterPhoto,
    Uint8List? signatureImage,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(observation),
            pw.SizedBox(height: 14),
            _detailsTable(observation),
            pw.SizedBox(height: 14),
            pw.Text(
              'Description',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _slate900),
            ),
            pw.SizedBox(height: 4),
            pw.Text(observation.description, style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 14),
            _photoRow(beforePhoto, afterPhoto),
            pw.Spacer(),
            _signOffBlock(observation, signatureImage),
            pw.Divider(color: _slate500),
            _footer(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _header(Observation o) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'HSE NON-CONFORMANCE NOTICE',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _slate900),
              ),
              pw.Text(o.projectName, style: const pw.TextStyle(fontSize: 11, color: _slate500)),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _severityColor(o.severity),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              o.severity.name.toUpperCase(),
              style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
        ],
      );

  static pw.Widget _detailsTable(Observation o) {
    final rows = <List<String>>[
      ['Finding', o.title],
      ['Category', o.category.name],
      ['Status', o.status.name],
      ['GPS Coordinates', '${o.latitude.toStringAsFixed(6)}, ${o.longitude.toStringAsFixed(6)}'],
      ['Raised', o.createdAt.toIso8601String().split('.').first],
      if (o.dueDate != null) ['Corrective Action Due', o.dueDate!.toIso8601String().split('.').first],
    ];
    return pw.Table(
      columnWidths: {0: const pw.FlexColumnWidth(1.3), 1: const pw.FlexColumnWidth(2.5)},
      children: rows
          .map(
            (r) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(r[0], style: pw.TextStyle(fontSize: 9, color: _slate500)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(r[1], style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _photoRow(Uint8List? before, Uint8List? after) => pw.Row(
        children: [
          if (before != null)
            pw.Expanded(child: _photoBlock('BEFORE', before)),
          if (before != null && after != null) pw.SizedBox(width: 10),
          if (after != null) pw.Expanded(child: _photoBlock('AFTER', after)),
        ],
      );

  static pw.Widget _photoBlock(String label, Uint8List bytes) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _slate500)),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 160,
            decoration: pw.BoxDecoration(border: pw.Border.all(color: _slate200)),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
        ],
      );

  static pw.Widget _signOffBlock(Observation o, Uint8List? signature) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Consultant Sign-Off', style: const pw.TextStyle(fontSize: 9, color: _slate500)),
              pw.SizedBox(height: 4),
              if (signature != null)
                pw.Container(height: 50, width: 160, child: pw.Image(pw.MemoryImage(signature)))
              else
                pw.Container(
                  height: 50,
                  width: 160,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: _slate500)),
                  ),
                ),
            ],
          ),
          pw.Text(
            o.closedAt != null ? 'Closed: ${o.closedAt!.toIso8601String().split('.').first}' : 'Open',
            style: const pw.TextStyle(fontSize: 9, color: _slate500),
          ),
        ],
      );

  static pw.Widget _footer() => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: pw.Text(
          'Issued via Safety Core AI  •  OSHA 29 CFR 1926/1910  •  ISO 45001:2018  •  ANSI Z16.1  •  '
          'System designed by HSE Engineer Yagoub Mohamed',
          style: const pw.TextStyle(fontSize: 7, color: _slate500),
        ),
      );

  /// Convenience: hand the generated PDF straight to the OS print/share sheet.
  static Future<void> printOrShare(Uint8List pdfBytes, {String fileName = 'hse_notice.pdf'}) {
    return Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }
}
