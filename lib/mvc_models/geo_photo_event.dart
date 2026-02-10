class GeoPhotoEvent {
  final String photoId;
  final String eventTimeUtc;
  final String userId;
  final String deviceId;
  final String divisi;
  final String blok;
  final String? spkNumber;
  final String? assignmentId;
  final String idTanaman;
  final String idReposisi;
  final String actionLabel;
  final String localPath;
  final String mimeType;
  final int fileSize;
  final String uploadStatus;
  final String? storagePath;
  final String? publicUrl;
  final String appVersion;

  const GeoPhotoEvent({
    required this.photoId,
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
    required this.localPath,
    required this.mimeType,
    required this.fileSize,
    required this.uploadStatus,
    required this.storagePath,
    required this.publicUrl,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'photo_id': photoId,
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
      'local_path': localPath,
      'mime_type': mimeType,
      'file_size': fileSize,
      'upload_status': uploadStatus,
      'storage_path': storagePath,
      'public_url': publicUrl,
      'app_version': appVersion,
    };
  }

  factory GeoPhotoEvent.fromJson(Map<String, dynamic> map) {
    return GeoPhotoEvent(
      photoId: map['photo_id']?.toString() ?? '',
      eventTimeUtc: map['event_time_utc']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      deviceId: map['device_id']?.toString() ?? '',
      divisi: map['divisi']?.toString() ?? '',
      blok: map['blok']?.toString() ?? '',
      spkNumber: map['spk_number']?.toString(),
      assignmentId: map['assignment_id']?.toString(),
      idTanaman: map['id_tanaman']?.toString() ?? '',
      idReposisi: map['id_reposisi']?.toString() ?? '',
      actionLabel: map['action_label']?.toString() ?? '',
      localPath: map['local_path']?.toString() ?? '',
      mimeType: map['mime_type']?.toString() ?? 'image/jpeg',
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      uploadStatus: map['upload_status']?.toString() ?? 'queued',
      storagePath: map['storage_path']?.toString(),
      publicUrl: map['public_url']?.toString(),
      appVersion: map['app_version']?.toString() ?? '-',
    );
  }

  GeoPhotoEvent copyWith({
    String? uploadStatus,
    String? storagePath,
    String? publicUrl,
  }) {
    return GeoPhotoEvent(
      photoId: photoId,
      eventTimeUtc: eventTimeUtc,
      userId: userId,
      deviceId: deviceId,
      divisi: divisi,
      blok: blok,
      spkNumber: spkNumber,
      assignmentId: assignmentId,
      idTanaman: idTanaman,
      idReposisi: idReposisi,
      actionLabel: actionLabel,
      localPath: localPath,
      mimeType: mimeType,
      fileSize: fileSize,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      storagePath: storagePath ?? this.storagePath,
      publicUrl: publicUrl ?? this.publicUrl,
      appVersion: appVersion,
    );
  }
}

