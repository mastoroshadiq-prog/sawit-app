// lib/screens/sync/sync_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:kebun_sawit/mvc_dao/dao_spr_log.dart';
import 'package:kebun_sawit/mvc_models/spr_log.dart';
import '../../mvc_dao/dao_audit_log.dart';
import '../../mvc_dao/dao_task_execution.dart';
import '../../mvc_dao/dao_kesehatan.dart';
import '../../mvc_dao/dao_reposisi.dart';
import '../../mvc_dao/dao_observasi_tambahan.dart';
import '../../mvc_dao/dao_sop.dart';
import '../../mvc_models/audit_log.dart';
import '../../mvc_models/execution.dart';
import '../../mvc_models/kesehatan.dart';
import '../../mvc_models/reposisi.dart';
import '../../mvc_models/observasi_tambahan.dart';
import '../../mvc_models/task_sop_check.dart';
import '../../mvc_libs/connection_utils.dart';
import '../../config/sync_source_config.dart';
import 'sync_models.dart';

/// Service untuk menangani sinkronisasi data
class SyncService {
  final String baseUrl = SyncSourceConfig.activeSyncPostUrl;

  // -----------------------------------------
  // FETCH DATA FROM SQLITE
  // -----------------------------------------

  /// Fetch data tugas dari SQLite
  Future<List<Map<String, dynamic>>> fetchTugasFromSqlite() async {
    await Future.delayed(const Duration(milliseconds: 800));
    List<TaskExecution> tasks = await TaskExecutionDao().getAllTaskExecByFlag();
    List<Map<String, dynamic>> allData = [];

    for (var task in tasks) {
      String date = task.taskDate;
      String dateTrimmed = date.substring(0, 23);
      final data = {
        "TARGET": "ITE",
        "PARAMS":
            "${task.id},"
            "${task.spkNumber},"
            "${task.taskName},"
            "${task.taskState},"
            "${task.petugas},"
            "$dateTrimmed,"
            "${task.keterangan},"
            "${task.imagePath}",
      };
      allData.add(data);
    }
    return allData;
  }

  Future<List<List<Map<String, dynamic>>>> fetchTugasFromSqliteX() async {
    await Future.delayed(const Duration(milliseconds: 800));
    List<TaskExecution> tasks = await TaskExecutionDao().getAllTaskExecByFlag();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;
    for (int i = 0; i < tasks.length; i += batchSize) {
      final end = (i + batchSize < tasks.length)
          ? i + batchSize
          : tasks.length;

      final batch = tasks.sublist(i, end).map((task) {
        String date = task.taskDate;
        String dateTrimmed = date.substring(0, 23);
        return {
          "TARGET": "ITE",
          "PARAMS":
              "${task.id},"
              "${task.spkNumber},"
              "${task.taskName},"
              "${task.taskState},"
              "${task.petugas},"
              "$dateTrimmed,"
              "${task.keterangan},"
              "${task.imagePath}",
        };
      }).toList();

      allBatchData.add(batch);
    }
    return allBatchData;
  }

  /// Fetch data kesehatan dari SQLite
  Future<List<Map<String, dynamic>>> fetchKesehatanFromSqlite() async {
    await Future.delayed(const Duration(milliseconds: 700));
    List<Kesehatan> health = await KesehatanDao().getAllByFlag();
    List<Map<String, dynamic>> allData = [];

    for (var kesehatan in health) {
      final dataB = {"TARGET": "UKP", "PARAMS": kesehatan.idTanaman};
      final dataA = {
        "TARGET": "IKP",
        "PARAMS":
            "${kesehatan.idKesehatan},"
            "${kesehatan.idTanaman},"
            "${kesehatan.statusAwal},"
            "${kesehatan.statusAkhir},"
            "${kesehatan.kodeStatus},"
            "${kesehatan.jenisPohon},"
            "${kesehatan.petugas}",
      };
      allData.add(dataB);
      allData.add(dataA);
    }
    return allData;
  }

  Future<List<List<Map<String, dynamic>>>> fetchKesehatanFromSqliteX() async {
    await Future.delayed(const Duration(milliseconds: 800));
    List<Kesehatan> sehats = await KesehatanDao().getAllZeroKesehatan();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;
    for (int i = 0; i < sehats.length; i += batchSize) {
      final end = (i + batchSize < sehats.length)
          ? i + batchSize
          : sehats.length;

      final batch = sehats.sublist(i, end).map((kesehatan) {
        return {
          "TARGET": "IKP",
          "PARAMS":
          "${kesehatan.idKesehatan},"
              "${kesehatan.idTanaman},"
              "${kesehatan.statusAwal},"
              "${kesehatan.statusAkhir},"
              "${kesehatan.kodeStatus},"
              "${kesehatan.jenisPohon},"
              "${kesehatan.petugas}",
        };
      }).toList();

      allBatchData.add(batch);
    }
    return allBatchData;
  }

  /// Fetch data reposisi dari SQLite
  Future<List<Map<String, dynamic>>> fetchReposisiFromSqlite() async {
    await Future.delayed(const Duration(milliseconds: 900));
    List<Reposisi> repos = await ReposisiDao().getTenByFlag();
    List<Map<String, dynamic>> allData = [];

    for (var repo in repos) {
      final dataA = {
        "TARGET": "IRP",
        "PARAMS":
            "${repo.idReposisi},"
            "${repo.idTanaman},"
            "${repo.pohonAwal},"
            "${repo.barisAwal},"
            "${repo.pohonTujuan},"
            "${repo.barisTujuan},"
            "${repo.tipeRiwayat},"
            "${repo.keterangan},"
            "${repo.petugas}",
      };

      //final dataB = {
        //"TARGET": "URP",
        //"PARAMS": "${repo.idTanaman},${repo.pohonAwal},${repo.barisAwal}",
      //};

      //allData.add(dataB);
      allData.add(dataA);
    }
    return allData;
  }

  Future<List<Map<String, dynamic>>> fetchReposisiBatch() async {
    await Future.delayed(const Duration(milliseconds: 900));
    List<Map<String, dynamic>> allBatch = [];
    int batchSize = 10;
    int totalData = await ReposisiDao().countUnsyncedReposisi();
    int jumlahBatch = (totalData / batchSize).ceil();
    for (int i = 0; i < jumlahBatch; i++) {
      //print("Batch Reposisi ke-${i + 1} dari $jumlahBatch");
      // Ambil 10 data yang flag-nya masih 0
      //List<Reposisi> repos = await ReposisiDao().getTenByFlag();
      List<Reposisi> repos = await ReposisiDao().getAllReposisi();
      List<Map<String, dynamic>> batchData = [];
        List<List<Map<String, dynamic>>> allBatchData = [];
      const int batchSize = 10;
      for (int i = 0; i < repos.length; i += batchSize) {
        final end = (i + batchSize < repos.length)
            ? i + batchSize
            : repos.length;

        final batch = repos.sublist(i, end).map((repo) {
          return {
            "TARGET": "IRP",
            "PARAMS":
            "${repo.idReposisi},${repo.idTanaman},${repo.pohonAwal},${repo.barisAwal},"
                "${repo.pohonTujuan},${repo.barisTujuan},${repo.tipeRiwayat},${repo.keterangan},"
                "${repo.petugas},${repo.blok}",
          };
        }).toList();

        allBatchData.add(batch);
      }

      for (var repo in repos) {
        batchData.add({
          "TARGET": "IRP",
          "PARAMS":
          "${repo.idReposisi},${repo.idTanaman},${repo.pohonAwal},${repo.barisAwal},"
              "${repo.pohonTujuan},${repo.barisTujuan},${repo.tipeRiwayat},${repo.keterangan},"
              "${repo.petugas},${repo.blok}",
        });
      }
      allBatch.add({
        "batch_index": i,
        "data": batchData // List<Map> dimasukkan ke sini
      });
    }
    return allBatch;
  }

  Future<List<List<Map<String, dynamic>>>> fetchReposisiBatchX() async {
    await Future.delayed(const Duration(milliseconds: 900));
      List<Reposisi> repos = await ReposisiDao().getAllZeroReposisi();
      List<List<Map<String, dynamic>>> allBatchData = [];
      const int batchSize = 10;
      for (int i = 0; i < repos.length; i += batchSize) {
        final end = (i + batchSize < repos.length)
            ? i + batchSize
            : repos.length;

        final batch = repos.sublist(i, end).map((repo) {
          return {
            "TARGET": "IRP",
            "PARAMS":
            "${repo.idReposisi},${repo.idTanaman},${repo.pohonAwal},${repo.barisAwal},"
                "${repo.pohonTujuan},${repo.barisTujuan},${repo.tipeRiwayat},${repo.keterangan},"
                "${repo.petugas},${repo.blok}",
          };
        }).toList();

        allBatchData.add(batch);
      }

    return allBatchData;
  }

  Future<List<List<Map<String, dynamic>>>> fetchSPRBatch() async {
    await Future.delayed(const Duration(milliseconds: 900));

    List<SPRLog> sprLog = await SPRLogDao().getAllZeroSPRLog();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;
    for (int i = 0; i < sprLog.length; i += batchSize) {
      final end = (i + batchSize < sprLog.length)
          ? i + batchSize
          : sprLog.length;

      final batch = sprLog.sublist(i, end).map((spr) {
        return {
          "TARGET": "ISPR",
          "PARAMS":
          "${spr.idLog},${spr.blok},${spr.nbaris},${spr.sprAwal},"
          "${spr.sprAkhir},${spr.keterangan},${spr.petugas}",
        };
      }).toList();

      allBatchData.add(batch);
    }

    return allBatchData;
  }

  Future<List<List<Map<String, dynamic>>>> fetchObservasiBatchX() async {
    await Future.delayed(const Duration(milliseconds: 700));

    List<ObservasiTambahan> observasi =
        await ObservasiTambahanDao().getAllZeroObservasi();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;

    for (int i = 0; i < observasi.length; i += batchSize) {
      final end =
          (i + batchSize < observasi.length) ? i + batchSize : observasi.length;

      final batch = observasi.sublist(i, end).map((o) {
        final createdAtTrimmed =
            o.createdAt.length >= 23 ? o.createdAt.substring(0, 23) : o.createdAt;
        return {
          "TARGET": "IOB",
          "PARAMS":
              "${o.idObservasi},${o.idTanaman},${o.blok},${o.baris},${o.pohon},"
                  "${o.kategori},${o.detail},${o.catatan},${o.petugas},$createdAtTrimmed",
        };
      }).toList();

      allBatchData.add(batch);
    }

    return allBatchData;
  }

  Future<List<List<Map<String, dynamic>>>> fetchSopCheckBatchX() async {
    await Future.delayed(const Duration(milliseconds: 600));

    List<TaskSopCheck> checks = await SopDao().getAllZeroChecks();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;

    for (int i = 0; i < checks.length; i += batchSize) {
      final end = (i + batchSize < checks.length) ? i + batchSize : checks.length;
      final batch = checks.sublist(i, end).map((c) {
        final checkedAtTrimmed =
            c.checkedAt.length >= 23 ? c.checkedAt.substring(0, 23) : c.checkedAt;
        return {
          'TARGET': 'ITSC',
          'PARAMS':
              '${c.checkId},${c.executionId},${c.assignmentId},${c.spkNumber},${c.sopId},${c.stepId},${c.isChecked},${c.note},${c.evidencePath ?? ''},$checkedAtTrimmed,${c.flag}',
        };
      }).toList();
      allBatchData.add(batch);
    }

    return allBatchData;
  }

  /// Fetch data audit log dari SQLite
  Future<List<Map<String, dynamic>>> fetchAuditLogFromSqlite() async {
    await Future.delayed(const Duration(milliseconds: 700));
    List<AuditLog> auditLogs = await AuditLogDao().getAllByFlag();
    List<Map<String, dynamic>> allData = [];

    for (var auditLog in auditLogs) {
      String date = auditLog.logDate;
      String dateTrimmed = date.substring(0, 23);
      final dataA = {
        "TARGET": "IAL",
        "PARAMS":
            "${auditLog.idAudit},"
            "${auditLog.userId},"
            "${auditLog.action},"
            "${auditLog.detail},"
            "$dateTrimmed,"
            "${auditLog.device}",
      };
      allData.add(dataA);
    }
    return allData;
  }

  Future<List<Map<String, dynamic>>> fetchAuditLogBatch() async {
    List<Map<String, dynamic>> allBatch = [];
    int batchSize = 10;
    int totalData = await AuditLogDao().countUnsyncedAuditLog();
    int jumlahBatch = (totalData / batchSize).ceil();
    for (int i = 0; i < jumlahBatch; i++) {
      List<AuditLog> auditLogs = await AuditLogDao().getAllByFlag();
      List<Map<String, dynamic>> batchData = [];
  
      for (var auditLog in auditLogs) {
        // Trim date aman jika string minimal 23 karakter
        String dateTrimmed = auditLog.logDate.length >= 23
            ? auditLog.logDate.substring(0, 23)
            : auditLog.logDate;

        batchData.add({
          "TARGET": "IAL",
          "PARAMS": "${auditLog.idAudit},${auditLog.userId},${auditLog.action},"
              "${auditLog.detail},$dateTrimmed,${auditLog.device}",
        });
      }

      allBatch.add({
        "batch_index": i,
        "data": batchData // List<Map> dimasukkan ke sini
      });

    }
    return allBatch;
  }

  Future<List<List<Map<String, dynamic>>>> fetchAuditLogBatchX() async {
    await Future.delayed(const Duration(milliseconds: 900));

    List<AuditLog> auditLog = await AuditLogDao().getAllZeroAuditLog();
    List<List<Map<String, dynamic>>> allBatchData = [];
    const int batchSize = 10;
    for (int i = 0; i < auditLog.length; i += batchSize) {
      final end = (i + batchSize < auditLog.length)
          ? i + batchSize
          : auditLog.length;

      final batch = auditLog.sublist(i, end).map((audit) {
        String dateTrimmed = audit.logDate.length >= 23
            ? audit.logDate.substring(0, 23)
            : audit.logDate;
        return {
          "TARGET": "IAL",
          "PARAMS": "${audit.idAudit},${audit.userId},${audit.action},"
              "${audit.detail},$dateTrimmed,${audit.device}",
        };
      }).toList();

      allBatchData.add(batch);
    }

    return allBatchData;
  }

  // -----------------------------------------
  // NETWORK: POST TO SERVER
  // -----------------------------------------

  /// Post JSON data ke server
  Future<String> postJsonToServer({
    required List<Map<String, dynamic>> payload,
    //required List<List<Map<String, dynamic>>> allBatchData,
  }) async {
    //String results = ""; // Penampung hasil setiap batch
    //for (int i = 0; i < allBatchData.length; i++) {
      //List<Map<String, dynamic>> payload = allBatchData[i];
      try {
        final encoded = jsonEncode(payload);
        final fullUrl = "$baseUrl?j=${Uri.encodeComponent(encoded)}";
        final response = await http.post(
          Uri.parse(fullUrl),
          headers: {"Accept": "application/json"},
        );

        //print("POST URL: $fullUrl");
        // print("RESPONSE CODE: ${response.body}");

        if (response.statusCode == 200) {
          // ekstrak bracket paling luar jika ada (safety)
          final body = ConnectionUtils().parseSqlError(response.body);
          final regex = RegExp(r"\[(.*)\]", dotAll: true);
          final match = regex.firstMatch(body);
          if (match != null) {
            return "[${match.group(1)}]";
            //results = "[${match.group(1)}]";
          }
          return body;
        } else {
          return "UPS...ERROR:${response.statusCode}!\n"
              "Ada gangguan pada server.\n"
              "Coba ulang beberapa saat lagi.";
          //results = "UPS...ERROR:${response.statusCode}!\n"
              //"Ada gangguan pada server.\n"
              //"Coba ulang beberapa saat lagi.";
        }
      } catch (e) {
        return "ERROR: ${e.toString()}";
        //results = "ERROR: ${e.toString()}";
      }
    //}

    //return results;
  }

  // -----------------------------------------
  // UPDATE FLAGS AFTER SUCCESS
  // -----------------------------------------

  /// Update flag di SQLite setelah berhasil sync
  Future<void> updateFlagsAfterSuccess({
    required BatchKind kind,
    required List<Map<String, dynamic>> items,
    required String label,
  }) async {
    String status = "Berhasil Sinkronisasi $label ke Server";

    switch (kind) {
      case BatchKind.tugas:
        await AuditLogDao().createLog("SYNC_DATA", status);
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await TaskExecutionDao().updateFlag(id);
        }
        break;

      case BatchKind.kesehatan:
        await AuditLogDao().createLog("SYNC_DATA", status);
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await KesehatanDao().updateFlag(id);
        }
        break;

      case BatchKind.reposisi:
        await AuditLogDao().createLog("SYNC_DATA", status);
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await ReposisiDao().updateFlag(id);
        }
        break;

      case BatchKind.observasi:
        await AuditLogDao().createLog("SYNC_DATA", status);
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await ObservasiTambahanDao().updateFlag(id);
        }
        break;

      case BatchKind.auditlog:
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await AuditLogDao().updateFlag(id);
        }
        break;

      case BatchKind.sprlog:
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await SPRLogDao().updateFlag(id);
        }
        break;

      case BatchKind.sopcheck:
        await AuditLogDao().createLog("SYNC_DATA", status);
        for (var map in items) {
          final id = map['PARAMS'].toString().split(',')[0];
          await SopDao().updateCheckFlag(id, 1);
        }
        break;
    }
  }

  /// Log error ke audit log
  Future<void> logError({
    required BatchKind kind,
    required String label,
  }) async {
    String status = "Gagal Sinkronisasi $label ke Server";
    await AuditLogDao().createLog("SYNC_DATA", status);
  }
}
