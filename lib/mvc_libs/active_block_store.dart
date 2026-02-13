import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveBlockStore {
  static const String _key = 'active_blok';
  static bool _loaded = false;

  static final ValueNotifier<String?> notifier = ValueNotifier<String?>(null);

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = (prefs.getString(_key) ?? '').trim();
    notifier.value = raw.isEmpty ? null : raw;
    _loaded = true;
  }

  static Future<String?> get() async {
    await ensureLoaded();
    return notifier.value;
  }

  static Future<void> set(String value) async {
    final normalized = value.trim();
    final prefs = await SharedPreferences.getInstance();
    if (normalized.isEmpty) {
      await prefs.remove(_key);
      notifier.value = null;
    } else {
      await prefs.setString(_key, normalized);
      notifier.value = normalized;
    }
    _loaded = true;
  }
}

