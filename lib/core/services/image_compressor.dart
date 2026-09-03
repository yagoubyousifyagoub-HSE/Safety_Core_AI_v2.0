import 'dart:typed_data';
import 'package:image/image.dart' as img;

class CompressionResult {
  final Uint8List bytes;
  final int originalBytes;
  final int compressedBytes;
  double get reductionRatio => 1 - (compressedBytes / originalBytes);

  CompressionResult({
    required this.bytes,
    required this.originalBytes,
    required this.compressedBytes,
  });
}

/// Field photos routinely come off modern phone cameras at 4000×3000+ and
/// 4–8 MB — unusable over a spotty site 4G connection and expensive in
/// Supabase Storage at fleet scale. This targets an 80%+ size reduction
/// (site-photo detail is preserved well above what's needed to read a
/// hazard tag or PPE violation) by first capping the long edge, then
/// stepping JPEG quality down only as far as needed to hit the target.
class ImageCompressor {
  ImageCompressor._();

  static const int _defaultMaxLongEdge = 1600;
  static const double _defaultTargetReduction = 0.80;
  static const int _minQuality = 40;

  static Future<CompressionResult> compress(
    Uint8List originalBytes, {
    int maxLongEdge = _defaultMaxLongEdge,
    double targetReduction = _defaultTargetReduction,
    int startQuality = 82,
  }) async {
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw ArgumentError('ImageCompressor: unable to decode image bytes.');
    }

    final longEdge = decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longEdge > maxLongEdge
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxLongEdge : null,
            height: decoded.height > decoded.width ? maxLongEdge : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    var quality = startQuality;
    Uint8List encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));

    // Step quality down in increments of 10 until we hit the target
    // reduction or the quality floor, whichever comes first — protects
    // against pathological inputs (already-compressed screenshots, etc.)
    // where dropping quality further wouldn't meaningfully shrink the file.
    while (1 - (encoded.lengthInBytes / originalBytes.lengthInBytes) < targetReduction &&
        quality > _minQuality) {
      quality -= 10;
      encoded = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }

    return CompressionResult(
      bytes: encoded,
      originalBytes: originalBytes.lengthInBytes,
      compressedBytes: encoded.lengthInBytes,
    );
  }
}
