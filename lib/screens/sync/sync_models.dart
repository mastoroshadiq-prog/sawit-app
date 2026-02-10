// lib/screens/sync/sync_models.dart

/// Jenis batch data yang akan disinkronkan
enum BatchKind { tugas, kesehatan, reposisi, observasi, auditlog, sprlog }

/// State dari setiap batch data
enum BatchState { idle, fetching, ready, sending, success, failed }

/// Helper class untuk menyimpan informasi batch
class BatchInfo {
  final BatchKind kind;
  final String jenis;
  //final List<Map<String, dynamic>> items;
  final List<List<Map<String, dynamic>>> items;

  BatchInfo(this.kind, this.jenis, this.items);
}

/// Extension untuk mendapatkan label dari BatchKind
extension BatchKindExtension on BatchKind {
  String get label {
    switch (this) {
      case BatchKind.tugas:
        return "Status Tugas";
      case BatchKind.kesehatan:
        return "Status Kesehatan";
      case BatchKind.reposisi:
        return "Status Reposisi";
      case BatchKind.observasi:
        return "Observasi Tambahan";
      case BatchKind.auditlog:
        return "Audit Log";
      case BatchKind.sprlog:
        return "Stand_Per_Row Log";
    }
  }
}
