class GeoAuditEvent {
  final String eventId;
  final String eventType;
  final String eventTimeUtc;
  final String userId;
  final String deviceId;
  final String divisi;
  final String blok;
  final String? spkNumber;
  final String? assignmentId;
  final String idTanaman;
  final String? idReposisi;
  final String actionLabel;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final String geoSource;
  final String geoStatus;
  final String geoCapturedAtUtc;
  final String appVersion;

  const GeoAuditEvent({
    required this.eventId,
    required this.eventType,
    required this.eventTimeUtc,
    required this.userId,
    required this.deviceId,
    required this.divisi,
    required this.blok,
    required this.spkNumber,
    required this.assignmentId,
    required this.idTanaman,
    required this.idReposisi,
    required this.actionLabel,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    required this.geoSource,
    required this.geoStatus,
    required this.geoCapturedAtUtc,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'event_type': eventType,
      'event_time_utc': eventTimeUtc,
      'user_id': userId,
      'device_id': deviceId,
      'divisi': divisi,
      'blok': blok,
      'spk_number': spkNumber,
      'assignment_id': assignmentId,
      'id_tanaman': idTanaman,
      'id_reposisi': idReposisi,
      'action_label': actionLabel,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
      'geo_source': geoSource,
      'geo_status': geoStatus,
      'geo_captured_at_utc': geoCapturedAtUtc,
      'app_version': appVersion,
    };
  }

  factory GeoAuditEvent.fromJson(Map<String, dynamic> map) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return GeoAuditEvent(
      eventId: map['event_id']?.toString() ?? '',
      eventType: map['event_type']?.toString() ?? 'koreksi_temuan',
      eventTimeUtc: map['event_time_utc']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      deviceId: map['device_id']?.toString() ?? '',
      divisi: map['divisi']?.toString() ?? '',
      blok: map['blok']?.toString() ?? '',
      spkNumber: map['spk_number']?.toString(),
      assignmentId: map['assignment_id']?.toString(),
      idTanaman: map['id_tanaman']?.toString() ?? '',
      idReposisi: map['id_reposisi']?.toString(),
      actionLabel: map['action_label']?.toString() ?? '',
      latitude: toDouble(map['latitude']),
      longitude: toDouble(map['longitude']),
      accuracyM: toDouble(map['accuracy_m']),
      geoSource: map['geo_source']?.toString() ?? 'none',
      geoStatus: map['geo_status']?.toString() ?? 'unavailable',
      geoCapturedAtUtc: map['geo_captured_at_utc']?.toString() ?? '',
      appVersion: map['app_version']?.toString() ?? '-',
    );
  }
}

