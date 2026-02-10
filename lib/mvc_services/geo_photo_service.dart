import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../mvc_dao/dao_assignment.dart';
import '../mvc_dao/dao_petugas.dart';
import '../mvc_models/geo_photo_event.dart';

class GeoPhotoService {
  GeoPhotoService._();
  static final GeoPhotoService _instance = GeoPhotoService._();
  factory GeoPhotoService() => _instance;

  static const String _queueKey = 'geo_photo_queue_v1';

  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  static const String _bucketName = String.fromEnvironment(
    'SUPABASE_BUCKET_AUDIT_PHOTO',
    defaultValue: 'audit-photo',
  );

  String? _lastError;

  Future<void> captureAndQueuePhoto({
    required String userId,
    required String blok,
    required String idTanaman,
    required String idReposisi,
    required String actionLabel,
    required String rowNumber,
    required String treeNumber,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      debugPrint('GeoPhotoService: file tidak ditemukan $localPath');
      return;
    }

    final bytes = await file.length();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final petugas = await PetugasDao().getPetugas();
    final relation = await _resolveAssignmentRelation(
      blok: blok,
      rowNumber: rowNumber,
      treeNumber: treeNumber,
      userId: userId,
    );

    final event = GeoPhotoEvent(
      photoId: const Uuid().v4().toUpperCase(),
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
      localPath: localPath,
      mimeType: 'image/jpeg',
      fileSize: bytes,
      uploadStatus: 'queued',
      storagePath: null,
      publicUrl: null,
      appVersion: await _getAppVersion(),
    );

    await _enqueue(_QueuedPhotoItem(
      event: event,
      retryCount: 0,
      lastError: null,
      nextRetryAtUtc: nowIso,
    ));

    await flushPending();
  }

  Future<void> flushPending() async {
    if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
      debugPrint('GeoPhotoService: env kosong, cek SUPABASE_URL/SUPABASE_ANON_KEY');
      return;
    }

    final queue = await _loadQueue();
    if (queue.isEmpty) return;

    final now = DateTime.now().toUtc();
    final List<_QueuedPhotoItem> nextQueue = [];
    for (final item in queue) {
      final scheduled = DateTime.tryParse(item.nextRetryAtUtc)?.toUtc();
      if (scheduled != null && scheduled.isAfter(now)) {
        nextQueue.add(item);
        continue;
      }

      final uploaded = await _uploadFile(item.event);
      if (uploaded == null) {
        final retry = item.retryCount + 1;
        final backoffSec = min(600, 15 * pow(2, retry).toInt());
        nextQueue.add(item.copyWith(
          retryCount: retry,
          lastError: _lastError ?? 'UPLOAD_FAILED',
          nextRetryAtUtc: DateTime.now()
              .toUtc()
              .add(Duration(seconds: backoffSec))
              .toIso8601String(),
        ));
        continue;
      }

      final metadata = item.event.copyWith(
        uploadStatus: 'uploaded',
        storagePath: uploaded.storagePath,
        publicUrl: uploaded.publicUrl,
      );

      final okMeta = await _insertMetadata(metadata);
      if (!okMeta) {
        final retry = item.retryCount + 1;
        final backoffSec = min(600, 15 * pow(2, retry).toInt());
        nextQueue.add(item.copyWith(
          retryCount: retry,
          lastError: _lastError ?? 'INSERT_META_FAILED',
          nextRetryAtUtc: DateTime.now()
              .toUtc()
              .add(Duration(seconds: backoffSec))
              .toIso8601String(),
        ));
      }
    }

    await _saveQueue(nextQueue);
  }

  Future<_UploadResult?> _uploadFile(GeoPhotoEvent event) async {
    try {
      final normalizedBase = _supabaseUrl.endsWith('/')
          ? _supabaseUrl.substring(0, _supabaseUrl.length - 1)
          : _supabaseUrl;

      final file = File(event.localPath);
      if (!await file.exists()) {
        _lastError = 'FILE_NOT_FOUND';
        return null;
      }

      final objectPath =
          'koreksi/${event.blok}/${event.idTanaman}/${event.photoId}.jpg';
      final url = Uri.parse(
        '$normalizedBase/storage/v1/object/$_bucketName/$objectPath',
      );
      final bytes = await file.readAsBytes();

      final res = await http.post(
        url,
        headers: {
          'apikey': _supabaseAnonKey,
          'Authorization': 'Bearer $_supabaseAnonKey',
          'Content-Type': 'image/jpeg',
          'x-upsert': 'true',
        },
        body: bytes,
      );

      final ok = res.statusCode >= 200 && res.statusCode < 300;
      if (!ok) {
        _lastError = 'STORAGE_HTTP ${res.statusCode}: ${res.body}';
        debugPrint('GeoPhotoService upload gagal => $_lastError');
        return null;
      }

      final publicUrl =
          '$normalizedBase/storage/v1/object/public/$_bucketName/$objectPath';
      _lastError = null;
      return _UploadResult(storagePath: objectPath, publicUrl: publicUrl);
    } catch (e) {
      _lastError = 'STORAGE_EXCEPTION: $e';
      debugPrint('GeoPhotoService upload exception => $_lastError');
      return null;
    }
  }

  Future<bool> _insertMetadata(GeoPhotoEvent event) async {
    try {
      final normalizedBase = _supabaseUrl.endsWith('/')
          ? _supabaseUrl.substring(0, _supabaseUrl.length - 1)
          : _supabaseUrl;
      final url = Uri.parse('$normalizedBase/rest/v1/audit_geo_photo');
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
        _lastError = 'META_HTTP ${res.statusCode}: ${res.body}';
        debugPrint('GeoPhotoService metadata gagal => $_lastError');
      } else {
        _lastError = null;
      }
      return ok;
    } catch (e) {
      _lastError = 'META_EXCEPTION: $e';
      debugPrint('GeoPhotoService metadata exception => $_lastError');
      return false;
    }
  }

  Future<void> _enqueue(_QueuedPhotoItem item) async {
    final queue = await _loadQueue();
    queue.add(item);
    await _saveQueue(queue);
  }

  Future<List<_QueuedPhotoItem>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => _QueuedPhotoItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> _saveQueue(List<_QueuedPhotoItem> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _queueKey,
      jsonEncode(queue.map((e) => e.toJson()).toList()),
    );
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

class _UploadResult {
  final String storagePath;
  final String publicUrl;

  const _UploadResult({
    required this.storagePath,
    required this.publicUrl,
  });
}

class _QueuedPhotoItem {
  final GeoPhotoEvent event;
  final int retryCount;
  final String? lastError;
  final String nextRetryAtUtc;

  const _QueuedPhotoItem({
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

  factory _QueuedPhotoItem.fromJson(Map<String, dynamic> map) {
    return _QueuedPhotoItem(
      event: GeoPhotoEvent.fromJson(Map<String, dynamic>.from(
        map['event'] as Map,
      )),
      retryCount: (map['retry_count'] as num?)?.toInt() ?? 0,
      lastError: map['last_error']?.toString(),
      nextRetryAtUtc: map['next_retry_at_utc']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
    );
  }

  _QueuedPhotoItem copyWith({
    int? retryCount,
    String? lastError,
    String? nextRetryAtUtc,
  }) {
    return _QueuedPhotoItem(
      event: event,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      nextRetryAtUtc: nextRetryAtUtc ?? this.nextRetryAtUtc,
    );
  }
}

