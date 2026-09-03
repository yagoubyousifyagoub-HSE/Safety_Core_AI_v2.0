/// Determines whether a captured GPS point falls inside a project's
/// registered site boundary, stored as raw GeoJSON `Polygon` or
/// `MultiPolygon` geometry (e.g. the `geometry` member of a Feature pulled
/// from the `project_boundaries` table).
///
/// GeoJSON coordinate order is always `[longitude, latitude]` — this is the
/// single most common source of bugs when wiring geofencing to a map
/// provider, so every ring access below is explicit about which index is
/// which.
class GeofenceService {
  /// Full geometry object, e.g.:
  /// ```json
  /// { "type": "Polygon", "coordinates": [ [ [lng, lat], ... ] ] }
  /// ```
  final Map<String, dynamic> geometry;

  const GeofenceService(this.geometry);

  /// Returns true if (lat, lng) lies inside the boundary (holes excluded).
  bool containsPoint({required double lat, required double lng}) {
    final type = geometry['type'] as String?;
    final coordinates = geometry['coordinates'];

    switch (type) {
      case 'Polygon':
        return _pointInPolygonCoordinates(
          lat: lat,
          lng: lng,
          rings: (coordinates as List).cast<List>(),
        );
      case 'MultiPolygon':
        for (final polygon in (coordinates as List)) {
          final isInside = _pointInPolygonCoordinates(
            lat: lat,
            lng: lng,
            rings: (polygon as List).cast<List>(),
          );
          if (isInside) return true;
        }
        return false;
      default:
        throw ArgumentError(
          'GeofenceService only supports Polygon/MultiPolygon geometry, got "$type".',
        );
    }
  }

  /// A Polygon's `coordinates` is a list of linear rings: ring[0] is the
  /// outer boundary, and any subsequent rings are holes cut out of it.
  /// A point counts as "inside" only if it's inside the outer ring AND
  /// outside every hole.
  static bool _pointInPolygonCoordinates({
    required double lat,
    required double lng,
    required List<List> rings,
  }) {
    if (rings.isEmpty) return false;

    final outerRing = _toDoubleRing(rings.first);
    if (!_rayCast(lat: lat, lng: lng, ring: outerRing)) return false;

    for (var i = 1; i < rings.length; i++) {
      final hole = _toDoubleRing(rings[i]);
      if (_rayCast(lat: lat, lng: lng, ring: hole)) {
        return false; // point falls inside an excluded hole
      }
    }
    return true;
  }

  static List<List<double>> _toDoubleRing(List rawRing) => rawRing
      .map<List<double>>(
        (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()],
      )
      .toList();

  /// Even-odd rule ray casting: cast a ray from the point to infinity (here,
  /// implicitly along +longitude) and count how many ring edges it crosses.
  /// An odd number of crossings means the point is inside.
  ///
  /// `ring[k] = [lng, lat]`. The loop uses the classic `j = i - 1` (wrapping)
  /// pairing so every edge, including the closing edge back to vertex 0, is
  /// tested exactly once.
  static bool _rayCast({
    required double lat,
    required double lng,
    required List<List<double>> ring,
  }) {
    var inside = false;
    final n = ring.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final lngI = ring[i][0], latI = ring[i][1];
      final lngJ = ring[j][0], latJ = ring[j][1];

      final edgeStraddlesLatitude = (latI > lat) != (latJ > lat);
      if (!edgeStraddlesLatitude) continue;

      final intersectionLng = lngI + (lat - latI) * (lngJ - lngI) / (latJ - latI);
      if (lng < intersectionLng) {
        inside = !inside;
      }
    }
    return inside;
  }
}
