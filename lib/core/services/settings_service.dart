import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Tiny local-only key-value store (Hive) for user-editable app settings —
/// currently just the HSE emergency hotline number, which ships with a
/// placeholder and needs to be set to the real site contact before
/// production use. Deliberately simple: no network, no sync, just a single
/// persisted string on-device, editable from the About screen.
class SettingsService {
  static const String boxName = 'app_settings';
  static const String _hotlineKey = 'emergency_hotline';

  /// Obvious placeholder on purpose — the About screen nudges toward
  /// replacing it, and this value alone should never be dialed for real.
  static const String defaultHotline = '+900000000';

  late final Box _box;

  /// Widgets that need to react live to a change (rare — most reads just
  /// take the current value at the moment they need it) can wrap this in a
  /// ValueListenableBuilder.
  final ValueNotifier<String> hotlineNumber = ValueNotifier(defaultHotline);

  Future<void> init() async {
    _box = await Hive.openBox(boxName);
    hotlineNumber.value = (_box.get(_hotlineKey) as String?) ?? defaultHotline;
  }

  Future<void> setHotlineNumber(String number) async {
    await _box.put(_hotlineKey, number);
    hotlineNumber.value = number;
  }
}
