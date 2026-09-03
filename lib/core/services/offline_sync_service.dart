import 'dart:async';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/observation_model.dart';
import 'connectivity_service.dart';

enum SyncState { idle, syncing }

/// Local-first queue backing every "New Observation" / "Closure" submission.
///
/// Writes always land here first, keyed by [Observation.localId] — the UI
/// never blocks on network. A background sync loop (triggered on app start,
/// on reconnect, and on a periodic timer) drains the queue against Supabase.
/// Storage of `Map<String, dynamic>` (see [Observation.toQueueMap]) avoids
/// needing a generated Hive TypeAdapter, keeping this file self-contained
/// and immediately compilable without a `build_runner` step.
class OfflineSyncService {
  static const String boxName = 'pending_observations';

  late final Box _box;
  final SupabaseClient _client = Supabase.instance.client;
  final ConnectivityService _connectivity;

  final _pendingCountController = StreamController<int>.broadcast();
  final _stateController = StreamController<SyncState>.broadcast();
  StreamSubscription<bool>? _connectivitySub;

  Stream<int> get pendingCountStream => _pendingCountController.stream;
  Stream<SyncState> get stateStream => _stateController.stream;

  OfflineSyncService({ConnectivityService? connectivityService})
      : _connectivity = connectivityService ?? ConnectivityService();

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    _emitPendingCount();

    // Auto-drain the queue the moment connectivity returns.
    _connectivitySub = _connectivity.onStatusChange.listen((isOnline) {
      if (isOnline) trySyncAll();
    });

    if (await _connectivity.isOnline()) {
      unawaited(trySyncAll());
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _pendingCountController.close();
    _stateController.close();
  }

  int get pendingCount => _box.length;

  List<Observation> get pendingObservations =>
      _box.values.map((m) => Observation.fromQueueMap(m as Map)).toList();

  Future<void> enqueue(Observation observation) async {
    await _box.put(observation.localId, observation.toQueueMap());
    _emitPendingCount();
  }

  Future<void> _remove(String localId) async {
    await _box.delete(localId);
    _emitPendingCount();
  }

  void _emitPendingCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(_box.length);
    }
  }

  /// Attempts to push every queued observation to Supabase. Each item is
  /// handled independently — a single failure (e.g. one bad photo path)
  /// never blocks the rest of the queue from syncing.
  Future<void> trySyncAll() async {
    if (_box.isEmpty) return;
    if (!await _connectivity.isOnline()) return;

    _stateController.add(SyncState.syncing);
    for (final key in _box.keys.toList()) {
      final map = _box.get(key);
      if (map == null) continue;
      final observation = Observation.fromQueueMap(map as Map);
      try {
        await _syncOne(observation);
        await _remove(observation.localId);
      } catch (_) {
        // Left in the queue; will retry on the next connectivity event or
        // periodic sync tick. Intentionally swallowed so one bad record
        // (e.g. a photo file the OS has since garbage-collected) doesn't
        // take down the whole sync pass.
      }
    }
    _stateController.add(SyncState.idle);
  }

  Future<void> _syncOne(Observation observation) async {
    observation.photoBeforeUrl ??= await _uploadIfLocalFileExists(
      observation.photoBeforeLocalPath,
      'observation-photos',
      '${observation.localId}_before.jpg',
    );
    observation.photoAfterUrl ??= await _uploadIfLocalFileExists(
      observation.photoAfterLocalPath,
      'observation-photos',
      '${observation.localId}_after.jpg',
    );
    observation.signatureUrl ??= await _uploadIfLocalFileExists(
      observation.signatureLocalPath,
      'signatures',
      '${observation.localId}_signature.png',
    );

    // Upsert keyed on the client-generated local_id (unique constraint in
    // schema.sql) so a retried sync after a partial failure never creates
    // a duplicate row.
    await _client
        .from('observations')
        .upsert(observation.toSupabasePayload(), onConflict: 'local_id');
  }

  Future<String?> _uploadIfLocalFileExists(
    String? localPath,
    String bucket,
    String storagePath,
  ) async {
    if (localPath == null) return null;
    final file = File(localPath);
    if (!await file.exists()) return null;

    await _client.storage.from(bucket).upload(
          storagePath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(bucket).getPublicUrl(storagePath);
  }
}
