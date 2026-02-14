import '../mvc_dao/dao_sop.dart';
import 'api_sop.dart';

class SopSyncService {
  final SopDao _dao = SopDao();

  Future<void> pullFromServerSafe({Set<String>? spkNumbers}) async {
    try {
      final masterRes = await ApiSop.getSopMaster(includeInactive: false);
      if (masterRes['success'] == true) {
        final rows = ((masterRes['data'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _dao.replaceSopMasterFromServer(rows);
      }

      final stepsRes = await ApiSop.getSopSteps();
      if (stepsRes['success'] == true) {
        final rows = ((stepsRes['data'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        await _dao.replaceSopStepsFromServer(rows);
      }

      final mergedMapRows = <String, Map<String, dynamic>>{};

      if (spkNumbers != null && spkNumbers.isNotEmpty) {
        for (final spk in spkNumbers) {
          final trimmed = spk.trim();
          if (trimmed.isEmpty) continue;
          final mapRes = await ApiSop.getTaskSopMap(spkNumber: trimmed);
          if (mapRes['success'] != true) continue;
          final rows = ((mapRes['data'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e));
          for (final r in rows) {
            final key = (r['mapId'] ?? '').toString().trim();
            if (key.isEmpty) continue;
            mergedMapRows[key] = r;
          }
        }
      } else {
        final mapRes = await ApiSop.getTaskSopMap();
        if (mapRes['success'] == true) {
          final rows = ((mapRes['data'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e));
          for (final r in rows) {
            final key = (r['mapId'] ?? '').toString().trim();
            if (key.isEmpty) continue;
            mergedMapRows[key] = r;
          }
        }
      }

      if (mergedMapRows.isNotEmpty) {
        await _dao.replaceTaskSopMapFromServer(mergedMapRows.values.toList());
      }
    } catch (_) {
      // SOP sync bersifat best-effort agar alur utama tidak terblokir.
    }
  }
}

