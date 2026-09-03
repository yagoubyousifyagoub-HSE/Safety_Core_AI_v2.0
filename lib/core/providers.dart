import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/offline_sync_service.dart';

/// Overridden in `main.dart` with the already-`init()`-ed singleton, since
/// Hive box opening is async and must complete before `runApp`.
final offlineSyncServiceProvider = Provider<OfflineSyncService>((ref) {
  throw UnimplementedError(
    'offlineSyncServiceProvider must be overridden in main.dart with an initialized instance.',
  );
});
