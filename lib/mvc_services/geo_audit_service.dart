import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../mvc_dao/dao_assignment.dart';
import '../mvc_dao/dao_petugas.dart';
import '../mvc_models/geo_audit_event.dart';
import '../mvc_libs/connection_utils.dart';

class GeoAuditService {
  GeoAuditService._();
  static final GeoAuditService _instance = GeoAuditService._();
  factory GeoAuditService() => _instance;

  static const String _queueKey = 'geo_audit_queue_v1';

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  String? _lastPostError;

  Future<void> captureAndQueueReposisiEvent({
    required String userId,
    required String blok,
    required String idTanaman,
    required String idReposisi,
    required String actionLabel,
    required String rowNumber,
    required String treeNumber,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final petugas = await PetugasDao().getPetugas();
    final relation = await _resolveAssignmentRelation(
      blok: blok,
      rowNumber: rowNumber,
      treeNumber: treeNumber,
      userId: userId,
    );

    final capture = await _captureGeoWithHybridPolicy();
    final event = GeoAuditEvent(
      eventId: const Uuid().v4().toUpperCase(),
      eventType: 'koreksi_temuan',
      eventTimeUtc: nowIso,
      userId: userId,
      deviceId: await _getDeviceId(),
      divisi: petugas?.divisi ?? '',
      blok: blok,
      spkNumber: relation.spkNumber,
      assignmentId: relation.assignmentId,
      idTanaman: idTanaman,
      idReposisi: idReposisi,
      actionLabel: actionLabel,
      latitude: capture.latitude,
      longitude: capture.longitude,
      accuracyM: capture.accuracyM,
      geoSource: capture.geoSource,
      geoStatus: capture.geoStatus,
      geoCapturedAtUtc: nowIso,
      appVersion: await _getAppVersion(),
    );

    await _enqueue(_QueuedGeoEvent(
      event: event,
      retryCount: 0,
      lastError: null,
      nextRetryAtUtc: nowIso,
    ));

    await flushPending();
  }

  Future<void> flushPending() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      debugPrint('GeoAuditService: env kosong, cek SUPABASE_URL/SUPABASE_ANON_KEY');
      return;
    }

    final queue = await _loadQueue();
    if (queue.isEmpty) return;

    final now = DateTime.now().toUtc();
    final List<_QueuedGeoEvent> nextQueue = [];
    for (final item in queue) {
      final scheduled = DateTime.tryParse(item.nextRetryAtUtc)?.toUtc();
      if (scheduled != null && scheduled.isAfter(now)) {
        nextQueue.add(item);
        continue;
      }

      final ok = await _postToSupabase(item.event);
      if (ok) {
        continue;
      }

      final retry = item.retryCount + 1;
      final backoffSec = min(600, 15 * pow(2, retry).toInt());
      nextQueue.add(item.copyWith(
        retryCount: retry,
        lastError: _lastPostError ?? 'POST_FAILED',
        nextRetryAtUtc:
            DateTime.now().toUtc().add(Duration(seconds: backoffSec)).toIso8601String(),
      ));
    }

    await _saveQueue(nextQueue);
  }

  Future<int> pendingCount() async {
    final queue = await _loadQueue();
    return queue.length;
  }

  Future<String?> lastError() async {
    final queue = await _loadQueue();
    if (queue.isEmpty) return null;
    return queue.last.lastError;
  }

  Future<bool> _postToSupabase(GeoAuditEvent event) async {
    try {
      final normalizedBase = _supabaseUrl.endsWith('/')
          ? _supabaseUrl.substring(0, _supabaseUrl.length - 1)
          : _supabaseUrl;
      final url = Uri.parse(
        '$normalizedBase/rest/v1/audit_geo_event',
      );
      final res = await http.post(
        url,
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Prefer': 'return=minimal',
        },
        body: jsonEncode([event.toJson()]),
      );
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _lastPostError = 'HTTP ${res.statusCode}: ${res.body}';
        debugPrint('GeoAuditService POST gagal => $_lastPostError');
      } else {
        _lastPostError = null;
      }
      return ok;
    } catch (e) {
      _lastPostError = 'EXCEPTION: $e';
      debugPrint('GeoAuditService POST exception => $_lastPostError');
      return false;
    }
  }

  Future<void> _enqueue(_QueuedGeoEvent item) async {
    final queue = await _loadQueue();
    queue.add(item);
    await _saveQueue(queue);
  }

  Future<List<_QueuedGeoEvent>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => _QueuedGeoEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _saveQueue(List<_QueuedGeoEvent> queue) async {
    final prefs = await SharedPreferences.getInstance();
    final data = queue.map((e) => e.toJson()).toList();
    await prefs.setString(_queueKey, jsonEncode(data));
  }

  Future<({String? spkNumber, String? assignmentId})> _resolveAssignmentRelation({
    required String blok,
    required String rowNumber,
    required String treeNumber,
    required String userId,
  }) async {
    final assignments = await AssignmentDao().getAllAssignment();
    for (final a in assignments) {
      final match = a.block == blok &&
          a.rowNumber == rowNumber &&
          a.treeNumber == treeNumber &&
          (a.petugas == userId || a.petugas.isEmpty);
      if (match) {
        return (spkNumber: a.spkNumber, assignmentId: a.id);
      }
    }

    for (final a in assignments) {
      if (a.block == blok) {
        return (spkNumber: a.spkNumber, assignmentId: a.id);
      }
    }

    return (spkNumber: null, assignmentId: null);
  }

  Future<_GeoCaptureResult> _captureGeoWithHybridPolicy() async {
    final online = await ConnectionUtils.checkConnection();
    if (online) {
      final live = await _getCurrentPosition();
      if (live != null) {
        return _GeoCaptureResult(
          latitude: live.latitude,
          longitude: live.longitude,
          accuracyM: live.accuracy,
          geoSource: 'gps_live',
          geoStatus: 'valid',
        );
      }

      return const _GeoCaptureResult(
        latitude: null,
        longitude: null,
        accuracyM: null,
        geoSource: 'none',
        geoStatus: 'unavailable',
      );
    }

    final last = await _getLastKnownPosition();
    if (last != null) {
      return _GeoCaptureResult(
        latitude: last.latitude,
        longitude: last.longitude,
        accuracyM: last.accuracy,
        geoSource: 'last_known',
        geoStatus: 'fallback_offline',
      );
    }

    return const _GeoCaptureResult(
      latitude: null,
      longitude: null,
      accuracyM: null,
      geoSource: 'none',
      geoStatus: 'unavailable',
    );
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final ready = await _ensurePermission();
      if (!ready) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _getLastKnownPosition() async {
    try {
      final ready = await _ensurePermission();
      if (!ready) return null;
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) return false;
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }

  Future<String> _getDeviceId() async {
    try {
      final info = DeviceInfoPlugin();
      final android = await info.androidInfo;
      final id = android.id;
      if (id.isNotEmpty) return id;
      return '${android.brand}-${android.model}-${android.device}';
    } catch (_) {
      return 'unknown-device';
    }
  }

  Future<String> _getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return '-';
    }
  }
}

class _GeoCaptureResult {
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String geoSource;
  final String geoStatus;

  const _GeoCaptureResult({
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.geoSource,
    required this.geoStatus,
  });
}

class _QueuedGeoEvent {
  final GeoAuditEvent event;
  final int retryCount;
  final String? lastError;
  final String nextRetryAtUtc;

  const _QueuedGeoEvent({
    required this.event,
    required this.retryCount,
    required this.lastError,
    required this.nextRetryAtUtc,
  });

  Map<String, dynamic> toJson() {
    return {
      'event': event.toJson(),
      'retry_count': retryCount,
      'last_error': lastError,
      'next_retry_at_utc': nextRetryAtUtc,
    };
  }

  factory _QueuedGeoEvent.fromJson(Map<String, dynamic> map) {
    return _QueuedGeoEvent(
      event: GeoAuditEvent.fromJson(Map<String, dynamic>.from(
        map['event'] as Map,
      )),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
      nextRetryAtUtc: map['next_retry_at_utc']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  _QueuedGeoEvent copyWith({
    int? retryCount,
    String? lastError,
    String? nextRetryAtUtc,
  }) {
    return _QueuedGeoEvent(
      event: event,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      nextRetryAtUtc: nextRetryAtUtc ?? this.nextRetryAtUtc,
    );
  }
}

