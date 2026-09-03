import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

/// Burns a legally-defensible evidence stamp directly into the photo's pixel
/// data (not EXIF, which is stripped by most chat/email clients) so that
/// GPS coordinates, capture time, and project name survive any downstream
/// compression, export, or screenshot of the printed HSE notice.
class WatermarkService {
  WatermarkService._();

  static Future<Uint8List> stamp({
    required Uint8List photoBytes,
    required double latitude,
    required double longitude,
    required String projectName,
    DateTime? capturedAt,
    int jpegQuality = 90,
  }) async {
    final decoded = img.decodeImage(photoBytes);
    if (decoded == null) {
      throw ArgumentError('WatermarkService: unable to decode image bytes.');
    }

    final timestamp = capturedAt ?? DateTime.now();
    final dateLine = DateFormat('yyyy-MM-dd HH:mm').format(timestamp);
    final gpsLine =
        'Lat ${latitude.toStringAsFixed(6)}  •  Lng ${longitude.toStringAsFixed(6)}';

    final lines = <String>[projectName, gpsLine, dateLine];

    final barHeight = 26 * lines.length + 20;
    final width = decoded.width;
    final height = decoded.height;

    // Semi-transparent black bar anchored to the bottom of the frame so text
    // stays legible regardless of the underlying photo's brightness.
    img.fillRect(
      decoded,
      x1: 0,
      y1: height - barHeight,
      x2: width,
      y2: height,
      color: img.ColorRgba8(0, 0, 0, 150),
    );

    var y = height - barHeight + 12;
    for (final line in lines) {
      img.drawString(
        decoded,
        line,
        font: img.arial24,
        x: 14,
        y: y,
        color: img.ColorRgb8(255, 255, 255),
      );
      y += 26;
    }

    // "Safety Core AI" provenance mark, bottom-right corner, small.
    img.drawString(
      decoded,
      'Safety Core AI',
      font: img.arial14,
      x: width - 130,
      y: height - 18,
      color: img.ColorRgba8(255, 255, 255, 180),
    );

    return Uint8List.fromList(img.encodeJpg(decoded, quality: jpegQuality));
  }
}
