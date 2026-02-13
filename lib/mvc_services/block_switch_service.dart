import 'package:kebun_sawit/mvc_dao/dao_audit_log.dart';
import 'package:kebun_sawit/mvc_dao/dao_kesehatan.dart';
import 'package:kebun_sawit/mvc_dao/dao_observasi_tambahan.dart';
import 'package:kebun_sawit/mvc_dao/dao_petugas.dart';
import 'package:kebun_sawit/mvc_dao/dao_pohon.dart';
import 'package:kebun_sawit/mvc_dao/dao_reposisi.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr_log.dart';
import 'package:kebun_sawit/mvc_dao/dao_task_execution.dart';
import 'package:kebun_sawit/mvc_libs/active_block_store.dart';
import 'package:kebun_sawit/mvc_libs/connection_utils.dart';
import 'package:kebun_sawit/mvc_models/pohon.dart';
import 'package:kebun_sawit/mvc_models/spr.dart';
import 'package:kebun_sawit/screens/sync/sync_models.dart';
import 'package:kebun_sawit/screens/sync/sync_service.dart';
import 'package:kebun_sawit/mvc_services/api_pohon.dart';
import 'package:kebun_sawit/mvc_services/api_spr.dart';

class BlockSwitchResult {
  const BlockSwitchResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}

class BlockSwitchService {
  final SyncService _syncService = SyncService();

  Future<bool> hasUnsyncedData() async {
    final tugas = (await TaskExecutionDao().getAllTaskExecByFlag()).isNotEmpty;
    final kesehatan = (await KesehatanDao().getAllZeroKesehatan()).isNotEmpty;
    final reposisi = (await ReposisiDao().getAllZeroReposisi()).isNotEmpty;
    final observasi = (await ObservasiTambahanDao().getAllZeroObservasi()).isNotEmpty;
    final spr = (await SPRLogDao().getAllZeroSPRLog()).isNotEmpty;
    final audit = (await AuditLogDao().getAllZeroAuditLog()).isNotEmpty;
    return tugas || kesehatan || reposisi || observasi || spr || audit;
  }

  Future<BlockSwitchResult> _syncPendingDataToServer() async {
    final online = await ConnectionUtils.checkConnection();
    if (!online) {
      return const BlockSwitchResult(
        success: false,
        message: 'Tidak ada koneksi internet untuk sinkronisasi data pending',
      );
    }

    final batchTugas = await _syncService.fetchTugasFromSqliteX();
    final batchKesehatan = await _syncService.fetchKesehatanFromSqliteX();
    final batchReposisi = await _syncService.fetchReposisiBatchX();
    final batchObservasi = await _syncService.fetchObservasiBatchX();
    final batchSprLog = await _syncService.fetchSPRBatch();
    final batchAudit = await _syncService.fetchAuditLogBatchX();

    final tasks = <({BatchKind kind, String label, List<List<Map<String, dynamic>>> data})>[
      (kind: BatchKind.tugas, label: 'Status Tugas', data: batchTugas),
      (kind: BatchKind.kesehatan, label: 'Status Kesehatan', data: batchKesehatan),
      (kind: BatchKind.reposisi, label: 'Status Reposisi', data: batchReposisi),
      (kind: BatchKind.observasi, label: 'Observasi Tambahan', data: batchObservasi),
      (kind: BatchKind.sprlog, label: 'Stand Per Row', data: batchSprLog),
      (kind: BatchKind.auditlog, label: 'Audit Log', data: batchAudit),
    ];

    final hasAny = tasks.any((t) => t.data.isNotEmpty);
    if (!hasAny) {
      return const BlockSwitchResult(
        success: true,
        message: 'Tidak ada data pending untuk dikirim',
      );
    }

    for (final task in tasks) {
      if (task.data.isEmpty) continue;

      int subBatchCounter = 0;
      for (final subBatch in task.data) {
        subBatchCounter++;
        final raw = await _syncService.postJsonToServer(payload: subBatch);
        final result = ConnectionUtils().parseSqlError(raw);
        final lower = result.toLowerCase();
        final isOk =
            lower.contains('berhasil') || lower.contains('success') || !lower.contains('error');

        if (!isOk) {
          return BlockSwitchResult(
            success: false,
            message:
                'Gagal sync pending pada ${task.label} batch $subBatchCounter: $result',
          );
        }

        await _syncService.updateFlagsAfterSuccess(
          kind: task.kind,
          items: subBatch,
          label: '${task.label} (Batch $subBatchCounter)',
        );
      }
    }

    final remain = await hasUnsyncedData();
    if (remain) {
      return const BlockSwitchResult(
        success: false,
        message: 'Sinkronisasi pending belum tuntas, blok tidak dipindahkan',
      );
    }

    return const BlockSwitchResult(
      success: true,
      message: 'Sinkronisasi data pending berhasil',
    );
  }

  Future<BlockSwitchResult> switchContextOnly(String newBlok) async {
    final normalized = newBlok.trim();
    if (normalized.isEmpty) {
      return const BlockSwitchResult(
        success: false,
        message: 'Blok tujuan tidak valid',
      );
    }

    await ActiveBlockStore.set(normalized);
    final petugas = await PetugasDao().getPetugas();
    if (petugas != null && petugas.akun.trim().isNotEmpty) {
      await PetugasDao().updateBlok(petugas.akun.trim(), normalized);
    }

    return BlockSwitchResult(
      success: true,
      message: 'Konteks blok aktif dipindahkan ke $normalized',
    );
  }

  Future<BlockSwitchResult> syncTargetBlockData({
    required String username,
    required String targetBlok,
  }) async {
    final normalized = targetBlok.trim();
    if (normalized.isEmpty) {
      return const BlockSwitchResult(
        success: false,
        message: 'Blok tujuan tidak valid',
      );
    }

    final pohonResult = await ApiPohon.getPohonByBlok(normalized);
    if (pohonResult['success'] != true) {
      return BlockSwitchResult(
        success: false,
        message: 'Gagal sync pohon: ${pohonResult['message']}',
      );
    }

    final pohonData = (pohonResult['data'] as List?) ?? const [];
    if (pohonData.isEmpty) {
      return BlockSwitchResult(
        success: false,
        message: 'Data pohon blok $normalized kosong',
      );
    }

    final sprResult = await ApiSPR.getSprBlok(normalized);
    if (sprResult['success'] != true) {
      return BlockSwitchResult(
        success: false,
        message: 'Gagal sync SPR: ${sprResult['message']}',
      );
    }

    final sprData = (sprResult['data'] as List?) ?? const [];
    if (sprData.isEmpty) {
      return BlockSwitchResult(
        success: false,
        message: 'Data SPR blok $normalized kosong',
      );
    }

    String asStr(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      final s = v.toString();
      return s.isEmpty ? fallback : s;
    }

    final List<Pohon> pohon = pohonData.map<Pohon>((item) {
      final map = item as Map;
      final objectIdVal = map['objectId'] ?? map['objectid'] ?? map['id_tanaman'];
      final objectIdStr = asStr(objectIdVal);
      final fallbackObjectId = [
        asStr(map['blok']),
        asStr(map['nbaris']),
        asStr(map['npohon']),
      ].join('-');

      return Pohon(
        blok: asStr(map['blok']),
        nbaris: asStr(map['nbaris']),
        npohon: asStr(map['npohon']),
        objectId: objectIdStr.isNotEmpty ? objectIdStr : fallbackObjectId,
        status: asStr(map['status'], fallback: '0'),
        nflag: asStr(map['nflag'], fallback: '0'),
      );
    }).toList();

    final List<SPR> spr = sprData.map<SPR>((item) {
      final map = item as Map;
      return SPR(
        idSPR: asStr(map['id_spr']),
        blok: asStr(map['blok']),
        nbaris: asStr(map['nbaris']),
        sprAwal: asStr(map['spr_awal'], fallback: '0'),
        sprAkhir: asStr(map['spr_akhir'], fallback: '0'),
        keterangan: '-',
        petugas: username,
        flag: 0,
      );
    }).toList();

    await PohonDao().deleteByBlok(normalized);
    await SPRDao().deleteByBlok(normalized);
    await PohonDao().insertPohonBatch(pohon);
    await SPRDao().insertSPRBatch(spr);

    final pohonLocal = (await PohonDao().getAllPohonByBlok(normalized)).length;
    final sprLocal = (await SPRDao().getByBlok(normalized)).length;
    if (pohonLocal == 0 || sprLocal == 0) {
      return BlockSwitchResult(
        success: false,
        message: 'Integrity check blok $normalized gagal (pohon:$pohonLocal, spr:$sprLocal)',
      );
    }

    await ActiveBlockStore.set(normalized);
    final petugas = await PetugasDao().getPetugas();
    if (petugas != null && petugas.akun.trim().isNotEmpty) {
      await PetugasDao().updateBlok(petugas.akun.trim(), normalized);
    }

    return BlockSwitchResult(
      success: true,
      message:
          'Blok aktif dipindah ke $normalized. Sync blok selesai (pohon:$pohonLocal, spr:$sprLocal)',
    );
  }

  Future<BlockSwitchResult> syncPendingThenSwitchBlock({
    required String username,
    required String targetBlok,
  }) async {
    final pendingResult = await _syncPendingDataToServer();
    if (!pendingResult.success) {
      return pendingResult;
    }

    final switchResult = await syncTargetBlockData(
      username: username,
      targetBlok: targetBlok,
    );

    if (!switchResult.success) {
      return switchResult;
    }

    return BlockSwitchResult(
      success: true,
      message: '${pendingResult.message}. ${switchResult.message}',
    );
  }
}

