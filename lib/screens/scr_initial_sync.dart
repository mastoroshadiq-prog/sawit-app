import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:kebun_sawit/mvc_libs/active_block_store.dart';
import 'package:kebun_sawit/mvc_dao/dao_reposisi.dart';
import 'package:kebun_sawit/mvc_services/api_blok.dart';
import 'package:kebun_sawit/mvc_services/api_spr.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mvc_dao/dao_assignment.dart';
import '../../mvc_dao/dao_pohon.dart';
import '../../mvc_services/api_pohon.dart';
import '../../mvc_services/api_spk.dart';
import '../../mvc_models/assignment.dart';
import '../../mvc_models/pohon.dart';
import '../../mvc_services/sop_sync_service.dart';
import '../mvc_dao/dao_spr.dart';
import '../mvc_models/spr.dart';

enum InitialSyncStep { resetData, spk, kesehatan, tanaman, spr, finalize }

extension InitialSyncStepX on InitialSyncStep {
  String get label {
    switch (this) {
      case InitialSyncStep.resetData:
        return 'Reset Data Lokal';
      case InitialSyncStep.spk:
        return 'Mengambil Data SPK';
      case InitialSyncStep.kesehatan:
        return 'Mengambil Riwayat Kesehatan';
      case InitialSyncStep.tanaman:
        return 'Mengambil Data Tanaman';
      case InitialSyncStep.spr:
        return 'Mengambil Data Stand Per Row';
      case InitialSyncStep.finalize:
        return 'Menyimpan data ke perangkat';
    }
  }
}

class InitialStepState {
  InitialStepState({
    required this.step,
    this.count = 0,
    this.done = false,
    this.running = false,
    this.errorMessage,
    this.startedAt,
    this.endedAt,
  });

  final InitialSyncStep step;
  int count;
  bool done;
  bool running;
  String? errorMessage;
  DateTime? startedAt;
  DateTime? endedAt;

  Map<String, dynamic> toJson() => {
    'count': count,
    'done': done,
    'running': running,
    'errorMessage': errorMessage,
    'startedAt': startedAt?.toIso8601String(),
    'endedAt': endedAt?.toIso8601String(),
  };

  static InitialStepState fromJson(InitialSyncStep step, Map<String, dynamic> json) {
    return InitialStepState(
      step: step,
      count: (json['count'] as num?)?.toInt() ?? 0,
      done: json['done'] == true,
      running: false,
      errorMessage: json['errorMessage'] as String?,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String)
          : null,
      endedAt: json['endedAt'] != null
          ? DateTime.tryParse(json['endedAt'] as String)
          : null,
    );
  }
}

class InitialSyncCheckpointStore {
  static const _kStateMap = 'init_sync_state_map_v1';
  static const _kLastFailed = 'init_sync_last_failed_v1';
  static const _kUpdatedAt = 'init_sync_updated_at_v1';

  Future<void> save(Map<InitialSyncStep, InitialStepState> states) async {
    final prefs = await SharedPreferences.getInstance();
    final map = <String, dynamic>{
      for (final e in states.entries) e.key.name: e.value.toJson(),
    };

    final failed = states.entries
        .where((e) => e.value.errorMessage != null && e.value.done == false)
        .map((e) => e.key.name)
        .cast<String?>()
        .firstWhere((e) => e != null, orElse: () => null);

    await prefs.setString(_kStateMap, jsonEncode(map));
    if (failed != null) {
      await prefs.setString(_kLastFailed, failed);
    } else {
      await prefs.remove(_kLastFailed);
    }
    await prefs.setString(_kUpdatedAt, DateTime.now().toIso8601String());
  }

  Future<Map<InitialSyncStep, InitialStepState>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStateMap);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return {};

    final result = <InitialSyncStep, InitialStepState>{};
    for (final step in InitialSyncStep.values) {
      final node = decoded[step.name];
      if (node is Map<String, dynamic>) {
        result[step] = InitialStepState.fromJson(step, node);
      }
    }
    return result;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStateMap);
    await prefs.remove(_kLastFailed);
    await prefs.remove(_kUpdatedAt);
  }
}

class NetworkQualityResult {
  const NetworkQualityResult({
    required this.ok,
    required this.downloadMbps,
    required this.latencyMs,
    required this.message,
  });

  final bool ok;
  final double downloadMbps;
  final int latencyMs;
  final String message;
}

class IntegrityCheckResult {
  const IntegrityCheckResult({
    required this.ok,
    required this.message,
    this.failedStep,
  });

  final bool ok;
  final String message;
  final InitialSyncStep? failedStep;
}


class InitialSyncPage extends StatefulWidget {
  final Object username;
  final Object blok;
  final String? selectedBlok;
  const InitialSyncPage({
    super.key,
    required this.username,
    required this.blok,
    this.selectedBlok,
  });

  @override
  State<InitialSyncPage> createState() => _InitialSyncPageState();
}

class _InitialSyncPageState extends State<InitialSyncPage> {
  final SopSyncService _sopSyncService = SopSyncService();
  double progress = 0.0;
  String currentStep = "";
  bool isSyncing = false;
  late Object username;
  late Object blok;
  String? activeBlok;
  bool _blokDialogShown = false;
  late Map<InitialSyncStep, InitialStepState> stepStates;
  final _checkpointStore = InitialSyncCheckpointStore();
  bool _isCheckingNetwork = false;
  NetworkQualityResult? _networkQuality;

  static const double _minDownloadMbps = 0.5;
  static const int _maxLatencyMs = 700;

  List<InitialSyncStep> get orderedSteps => InitialSyncStep.values;

  String _normBlock(String v) => v.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    username = widget.username;
    blok = widget.blok;
    activeBlok = widget.selectedBlok ?? widget.blok.toString();
    stepStates = {
      for (final s in orderedSteps) s: InitialStepState(step: s),
    };
    _bootstrapSync();
  }

  Future<void> _bootstrapSync() async {
    final storedActiveBlok = await ActiveBlockStore.get();
    if (storedActiveBlok != null && storedActiveBlok.trim().isNotEmpty) {
      activeBlok = storedActiveBlok.trim();
    }

    await _ensureSelectedBlok();
    if (!mounted) return;

    final networkReady = await _ensureNetworkReady(showSnackBar: false);
    if (!mounted || !networkReady) {
      setState(() {
        currentStep = 'Bandwidth/jaringan tidak memadai untuk proses sinkronisasi';
      });
      return;
    }

    final loaded = await _checkpointStore.load();
    if (!mounted) return;

    if (loaded.isNotEmpty) {
      setState(() {
        for (final s in orderedSteps) {
          stepStates[s] = loaded[s] ?? InitialStepState(step: s);
        }
        progress = _computeProgress();
        final failed = _firstFailedStep();
        currentStep = failed != null ? 'Gagal di ${failed.label}' : 'Siap melanjutkan sinkronisasi';
      });
      return;
    }

    _startSync();
  }

  Future<void> _ensureSelectedBlok() async {
    if (_blokDialogShown) return;
    _blokDialogShown = true;

    final user = username.toString();
    final result = await ApiBlok.getBlokList(user);
    if (!mounted) return;

    if (result['success'] != true) {
      activeBlok = widget.blok.toString();
      return;
    }

    final list = (result['data'] as List?) ?? const [];
    if (list.isEmpty) {
      activeBlok = widget.blok.toString();
      return;
    }

    final uniqueBlocks = <String, Map<String, String>>{};
    for (final row in list) {
      if (row is! Map) continue;
      final kode = (row['blok'] ?? '').toString().trim();
      if (kode.isEmpty) continue;

      uniqueBlocks.putIfAbsent(kode, () {
        return {
          'blok': kode,
          'blok_name': (row['blok_name'] ?? kode).toString(),
          'estate': (row['estate'] ?? '-').toString(),
          'divisi': (row['divisi'] ?? '-').toString(),
        };
      });
    }

    final blocks = uniqueBlocks.values.toList();
    if (blocks.isEmpty) {
      activeBlok = widget.blok.toString();
      return;
    }

    String current = (activeBlok ?? '').trim();
    if (current.isEmpty || !uniqueBlocks.containsKey(current)) {
      current = blocks.first['blok'] ?? widget.blok.toString();
    }

    final selected = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        String tempValue = current;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Pilih Blok Kerja'),
            content: SizedBox(
              width: 320,
              child: DropdownButtonFormField<String>(
                initialValue: tempValue,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Blok',
                  border: OutlineInputBorder(),
                ),
                items: blocks.map((m) {
                  final kode = (m['blok'] ?? '').toString();
                  final nama = (m['blok_name'] ?? kode).toString();
                  return DropdownMenuItem<String>(
                    value: kode,
                    child: Text('$kode - $nama'),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setLocal(() => tempValue = v);
                },
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(tempValue),
                child: const Text('Gunakan Blok Ini'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    activeBlok = (selected ?? current).trim();
    await ActiveBlockStore.set(activeBlok ?? '');
  }

  Future<IntegrityCheckResult> _runPostSyncIntegrityCheck() async {
    final selectedBlok = _normBlock(activeBlok ?? blok.toString());

    final assignmentLocal = (await AssignmentDao().getAllAssignment()).length;
    final pohonLocal = (await PohonDao().getAllPohonByBlok(selectedBlok)).length;
    final sprLocal = (await SPRDao().getByBlok(selectedBlok)).length;

    final assignmentExpected = stepStates[InitialSyncStep.spk]?.count ?? 0;
    final pohonExpected = stepStates[InitialSyncStep.tanaman]?.count ?? 0;
    final sprExpected = stepStates[InitialSyncStep.spr]?.count ?? 0;

    final issues = <String>[];
    InitialSyncStep? failedStep;

    if (assignmentExpected > 0 && assignmentLocal < assignmentExpected) {
      issues.add('SPK lokal $assignmentLocal < expected $assignmentExpected');
      failedStep ??= InitialSyncStep.spk;
    }
    if (pohonExpected > 0 && pohonLocal < pohonExpected) {
      issues.add('Pohon $selectedBlok: lokal $pohonLocal < expected $pohonExpected');
      failedStep ??= InitialSyncStep.tanaman;
    }
    if (sprExpected > 0 && sprLocal < sprExpected) {
      issues.add('SPR $selectedBlok: lokal $sprLocal < expected $sprExpected');
      failedStep ??= InitialSyncStep.spr;
    }

    // Guard kritikal untuk mencegah user lanjut dengan data blok kosong.
    if (pohonLocal == 0) {
      issues.add('Data pohon blok $selectedBlok kosong');
      failedStep ??= InitialSyncStep.tanaman;
    }
    if (sprLocal == 0) {
      issues.add('Data SPR blok $selectedBlok kosong');
      failedStep ??= InitialSyncStep.spr;
    }

    if (issues.isNotEmpty) {
      return IntegrityCheckResult(
        ok: false,
        message: issues.join(' | '),
        failedStep: failedStep,
      );
    }

    return IntegrityCheckResult(
      ok: true,
      message:
          'Integrity OK - SPK:$assignmentLocal, Pohon($selectedBlok):$pohonLocal, SPR($selectedBlok):$sprLocal',
      failedStep: null,
    );
  }

  Future<NetworkQualityResult> _measureNetworkQuality() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      return const NetworkQualityResult(
        ok: false,
        downloadMbps: 0,
        latencyMs: 0,
        message: 'Tidak ada koneksi internet',
      );
    }

    int latencyMs;
    try {
      final latencyWatch = Stopwatch()..start();
      await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      latencyWatch.stop();
      latencyMs = latencyWatch.elapsedMilliseconds;
    } catch (_) {
      return const NetworkQualityResult(
        ok: false,
        downloadMbps: 0,
        latencyMs: 999,
        message: 'Jaringan tidak stabil (latensi gagal diukur)',
      );
    }

    double downloadMbps = 0;
    try {
      final uri = Uri.parse('${ApiSPK.baseUrl}/wfs.jsp?r=apk.task&q=${username.toString()}');
      final dlWatch = Stopwatch()..start();
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      dlWatch.stop();

      if (response.statusCode >= 400) {
        return NetworkQualityResult(
          ok: false,
          downloadMbps: 0,
          latencyMs: latencyMs,
          message: 'Server tidak merespons normal (${response.statusCode})',
        );
      }

      final bytes = response.bodyBytes.length;
      final sec = math.max(dlWatch.elapsedMilliseconds / 1000.0, 0.001);
      downloadMbps = (bytes * 8) / (sec * 1000 * 1000);
    } catch (_) {
      return NetworkQualityResult(
        ok: false,
        downloadMbps: 0,
        latencyMs: latencyMs,
        message: 'Gagal mengukur bandwidth unduh',
      );
    }

    final ok = downloadMbps >= _minDownloadMbps && latencyMs <= _maxLatencyMs;
    return NetworkQualityResult(
      ok: ok,
      downloadMbps: downloadMbps,
      latencyMs: latencyMs,
      message: ok
          ? 'Jaringan memadai untuk sinkronisasi'
          : 'Bandwidth/jaringan tidak memadai untuk sinkronisasi',
    );
  }

  Future<bool> _ensureNetworkReady({required bool showSnackBar}) async {
    if (!mounted) return false;
    setState(() => _isCheckingNetwork = true);

    final result = await _measureNetworkQuality();
    if (!mounted) return false;

    setState(() {
      _networkQuality = result;
      _isCheckingNetwork = false;
    });

    if (result.ok) return true;

    // Snackbar warning bandwidth dinonaktifkan sesuai kebutuhan UX terbaru.

    // Sesuai kebijakan baru: hanya warning, proses sync tetap lanjut tanpa konfirmasi.
    return true;
  }

  double _computeProgress() {
    final done = stepStates.values.where((s) => s.done).length;
    return orderedSteps.isEmpty ? 0.0 : done / orderedSteps.length;
  }

  InitialSyncStep? _firstFailedStep() {
    for (final step in orderedSteps) {
      final st = stepStates[step];
      if (st != null && st.done == false && st.errorMessage != null) return step;
    }
    return null;
  }

  Future<void> _startSync({InitialSyncStep? startFrom}) async {
    if (isSyncing) return;
    final networkReady = await _ensureNetworkReady(showSnackBar: true);
    if (!networkReady) return;

    final startIndex = startFrom == null ? 0 : orderedSteps.indexOf(startFrom);
    final failedBeforeRun = _firstFailedStep();
    debugPrint(
      '[InitialSync][start] startFrom=${startFrom?.name ?? 'null'} startIndex=$startIndex failedBefore=${failedBeforeRun?.name ?? 'none'} doneBefore=${stepStates.values.where((e) => e.done).length}/${orderedSteps.length}',
    );
    setState(() {
      isSyncing = true;
      for (int i = startIndex; i < orderedSteps.length; i++) {
        final step = orderedSteps[i];
        final state = stepStates[step]!;
        state.done = false;
        state.running = false;
        state.count = 0;
        state.errorMessage = null;
        state.startedAt = null;
        state.endedAt = null;
      }
      progress = _computeProgress();
    });

    for (int i = startIndex; i < orderedSteps.length; i++) {
      final step = orderedSteps[i];
      final state = stepStates[step]!;
      debugPrint(
        '[InitialSync][step.begin] step=${step.name} done=${state.done} err=${state.errorMessage}',
      );

      setState(() {
        currentStep = step.label;
        state.running = true;
        state.startedAt = DateTime.now();
        state.errorMessage = null;
      });

      try {
        final count = await _runActionByStep(step);
        setState(() {
          state.running = false;
          state.done = true;
          state.count = count;
          state.endedAt = DateTime.now();
          progress = _computeProgress();
          currentStep = 'Selesai: ${step.label}';
        });
        debugPrint(
          '[InitialSync][step.success] step=${step.name} count=$count doneNow=${stepStates.values.where((e) => e.done).length}/${orderedSteps.length}',
        );
      } catch (e) {
        setState(() {
          state.running = false;
          state.done = false;
          state.errorMessage = e.toString();
          state.endedAt = DateTime.now();
          currentStep = 'Gagal: ${step.label}';
          progress = _computeProgress();
        });
        debugPrint(
          '[InitialSync][step.failed] step=${step.name} err=${state.errorMessage} doneNow=${stepStates.values.where((e) => e.done).length}/${orderedSteps.length}',
        );
        await _checkpointStore.save(stepStates);
        if (!mounted) return;
        setState(() => isSyncing = false);
        return;
      }

      await _checkpointStore.save(stepStates);
    }

    final notDoneSteps = orderedSteps.where((s) => stepStates[s]?.done != true).map((s) => s.name).toList();
    debugPrint(
      '[InitialSync][finish] startFrom=${startFrom?.name ?? 'null'} done=${stepStates.values.where((e) => e.done).length}/${orderedSteps.length} notDone=$notDoneSteps',
    );

    final integrity = await _runPostSyncIntegrityCheck();
    if (!integrity.ok) {
      final failed = integrity.failedStep ?? InitialSyncStep.finalize;
      final failedState = stepStates[failed]!;
      setState(() {
        failedState.done = false;
        failedState.errorMessage = 'Integrity check gagal: ${integrity.message}';
        failedState.endedAt = DateTime.now();
        isSyncing = false;
        currentStep = 'Gagal validasi data lokal';
        progress = _computeProgress();
      });
      await _checkpointStore.save(stepStates);
      return;
    }

    debugPrint('[InitialSync][integrity] ${integrity.message}');

    await _checkpointStore.clear();
    if (!mounted) return;
    setState(() => isSyncing = false);
    debugPrint('[InitialSync][navigate] to=/menu');
    Navigator.pushReplacementNamed(context, "/menu");
  }

  Future<int> _runActionByStep(InitialSyncStep step) async {
    switch (step) {
      case InitialSyncStep.resetData:
        await _deleteALL();
        return 0;
      case InitialSyncStep.spk:
        return _syncSPK();
      case InitialSyncStep.kesehatan:
        return _syncKesehatan();
      case InitialSyncStep.tanaman:
        return _syncTanaman();
      case InitialSyncStep.spr:
        return _syncSPRBlok();
      case InitialSyncStep.finalize:
        await Future.delayed(const Duration(milliseconds: 200));
        return 0;
    }
  }

  Future<void> _deleteALL() async {
    try {
      // Cek dulu data lokal yang belum tersinkron sebelum menghapus apapun.
      final unsyncedCount = await ReposisiDao().countUnsyncedReposisi();
      if (unsyncedCount > 0) {
        debugPrint(
          "Lewati reset data: masih ada $unsyncedCount data reposisi belum sinkron.",
        );
        return;
      }

      // Hapus semua data petugas
      //await PetugasDao().deleteAllWorkers();

      // Hapus semua data assignment
      await AssignmentDao().deleteAllAssignments();

      // Hapus semua data pohon
      await PohonDao().deleteAllPohon();
      debugPrint("Data pohon berhasil dibersihkan.");

      await SPRDao().deleteAll();

      //print("Semua data berhasil dihapus.");
    } catch (e) {
      //print("Gagal menghapus data: $e");
    }
  }

  // ---------------------------------------------------------
  // STEP 1 â€” Ambil & Simpan SPK
  // ---------------------------------------------------------
  Future<int> _syncSPK() async {
    final result = await ApiSPK.getTask(username.toString());

    if (!result['success']) {
      throw Exception("API SPK gagal: ${result['message']}");
    }

    String asStr(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      return v.toString();
    }

    final data = result['data'];
    final List<Assignment> assignments = (data as List).map<Assignment>((item) {
      return Assignment(
        id: asStr(item['id_task']),
        spkNumber: asStr(item['nomor_spk']),
        taskName: asStr(item['nama_task']),
        estate: asStr(item['estate'], fallback: '-'),
        division: asStr(item['divisi'], fallback: '-'),
        block: asStr(item['lokasi']),
        rowNumber: asStr(item['nbaris'], fallback: '0'),
        treeNumber: asStr(item['n_pokok'], fallback: '0'),
        petugas: username.toString(),
      );
    }).toList();


    final inserted = await AssignmentDao().insertAssignmentsBatch(assignments);
    if (inserted <= 0) throw Exception("Insert SPK gagal");

    await _sopSyncService.pullFromServerSafe(
      spkNumbers: assignments.map((e) => e.spkNumber).toSet(),
    );

    return assignments.length;
  }

  // ---------------------------------------------------------
  // STEP 2 â€” Ambil & simpan Riwayat Kesehatan (contoh dummy)
  // ---------------------------------------------------------
  Future<int> _syncKesehatan() async {
    // Nanti ganti dengan API kesehatan
    await Future.delayed(const Duration(milliseconds: 300));
    return 0;
  }

  // ---------------------------------------------------------
  // STEP 3 â€” Ambil & simpan Data Tanaman (contoh dummy)
  // ---------------------------------------------------------
  Future<int> _syncTanaman() async {
    // API tanaman
    int unsyncedCount = await ReposisiDao().countUnsyncedReposisi();
    if (unsyncedCount == 0) {
      final selectedBlok = _normBlock(activeBlok ?? blok.toString());
      final result = await ApiPohon.getPohonByBlok(selectedBlok);

      if (!result['success']) {
        throw Exception("API Pohon gagal: ${result['message']}");
      }

      final data = result['data'];
      if (data is List && data.isEmpty) {
        final selected = selectedBlok;
        throw Exception("Data pohon kosong untuk blok $selected");
      }

      String asStr(dynamic v, {String fallback = ''}) {
        if (v == null) return fallback;
        return v.toString();
      }

      final List<Pohon> pohons = (data as List).map<Pohon>((item) {
        final objectIdVal =
            item['objectId'] ?? item['objectid'] ?? item['id_tanaman'];
        final objectIdStr = asStr(objectIdVal);
        final blokFromApi = _normBlock(asStr(item['blok'], fallback: selectedBlok));
        final fallbackObjectId = [
          blokFromApi,
          asStr(item['nbaris']),
          asStr(item['npohon']),
        ].join('-');

        return Pohon(
          blok: blokFromApi,
          nbaris: asStr(item['nbaris']),
          npohon: asStr(item['npohon']),
          objectId: objectIdStr.isNotEmpty ? objectIdStr : fallbackObjectId,
          status: asStr(item['status'], fallback: '0'),
          nflag: asStr(item['nflag'], fallback: '0'),
        );
      }).where((p) => p.blok == selectedBlok).toList();

      if (pohons.isEmpty) {
        throw Exception(
          "Data pohon blok $selectedBlok tidak ditemukan setelah normalisasi blok",
        );
      }

      await PohonDao().deleteByBlok(selectedBlok);

      final inserted = await PohonDao().insertPohonBatch(pohons);
      if (inserted <= 0) throw Exception("Insert POHON gagal");
      return pohons.length;
    } else {
      // Jika masih ada data, berikan peringatan
      debugPrint("Masih ada $unsyncedCount data reposisi yang belum sinkron.");
      return 0;
    }

    //await Future.delayed(const Duration(milliseconds: 300));
  }

  // ---------------------------------------------------------
  // STEP 4 â€” Ambil & Simpan Data Stand Per Row
  // ---------------------------------------------------------
  Future<int> _syncSPRBlok() async {
    final selectedBlok = _normBlock(activeBlok ?? blok.toString());
    final result = await ApiSPR.getSprBlok(selectedBlok);

    if (!result['success']) {
      throw Exception("API SPR gagal: ${result['message']}");
    }

    String asStr(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      return v.toString();
    }

    final data = result['data'];
    final List<SPR> spr = (data as List).map<SPR>((item) {
      final blokFromApi = _normBlock(asStr(item['blok'], fallback: selectedBlok));
      return SPR(
        idSPR: asStr(item['id_spr']),
        blok: blokFromApi,
        nbaris: asStr(item['nbaris']),
        sprAwal: asStr(item['spr_awal'], fallback: '0'),
        sprAkhir: asStr(item['spr_akhir'], fallback: '0'),
        keterangan: '-',
        petugas: username.toString(),
        flag: 0,
      );
    }).where((s) => s.blok == selectedBlok).toList();

    if (spr.isEmpty) {
      throw Exception('Data SPR kosong untuk blok $selectedBlok');
    }

    await SPRDao().deleteByBlok(selectedBlok);

    final inserted = await SPRDao().insertSPRBatch(spr);
    if (inserted <= 0) throw Exception("Insert SPR gagal");
    return spr.length;
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final failedStep = _firstFailedStep();

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1B3C2E), Color(0xFF2E5A3B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0x14FFFFFF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Sinkronisasi Data",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Menyiapkan data awal untuk aktivitas lapangan",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: (_networkQuality?.ok ?? false)
                        ? const Color(0xFF1E5F4D).withValues(alpha: 0.35)
                        : const Color(0xFF8B2C2C).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (_networkQuality?.ok ?? false)
                          ? const Color(0xFF8FCE00).withValues(alpha: 0.6)
                          : Colors.redAccent.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isCheckingNetwork)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                          ),
                        )
                      else
                        Icon(
                          (_networkQuality?.ok ?? false) ? Icons.check_circle : Icons.error,
                          color: (_networkQuality?.ok ?? false)
                              ? const Color(0xFF8FCE00)
                              : Colors.redAccent,
                          size: 18,
                        ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isCheckingNetwork
                              ? 'Mengecek kualitas jaringan...'
                              : ((_networkQuality?.ok ?? false)
                                  ? (_networkQuality?.message ?? 'Jaringan memadai untuk sinkronisasi')
                                  : 'Perhatian Bandwidth kurang memadai untuk tahapan Sync'),
                          style: TextStyle(
                            color: (_networkQuality?.ok ?? false)
                                ? Colors.white
                                : Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_networkQuality != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Download ${_networkQuality!.downloadMbps.toStringAsFixed(2)} Mbps • Latensi ${_networkQuality!.latencyMs} ms '
                        '(min ${_minDownloadMbps.toStringAsFixed(1)} Mbps, max $_maxLatencyMs ms)',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0x26FFFFFF),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8FCE00)),
                  ),
                ),

                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      '${stepStates.values.where((e) => e.done).length}/${orderedSteps.length} step',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: orderedSteps.map((step) {
                      final st = stepStates[step]!;
                      final icon = st.running
                          ? Icons.sync
                          : st.done
                              ? Icons.check_circle
                              : st.errorMessage != null
                                  ? Icons.error
                                  : Icons.circle_outlined;
                      final color = st.running
                          ? const Color(0xFF8FCE00)
                          : st.done
                              ? Colors.white38
                              : st.errorMessage != null
                                  ? Colors.redAccent
                                  : Colors.white;
                      final isWaiting = !st.running && !st.done && st.errorMessage == null;
                      final isHighlighted = st.running || isWaiting;
                      final rowHighlightColor = st.running
                          ? const Color(0xFF8FCE00).withValues(alpha: 0.20)
                          : isWaiting
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.transparent;
                      final subtitle = st.errorMessage != null
                          ? st.errorMessage!
                          : st.running
                              ? 'Sedang proses...'
                          : st.done
                              ? 'Sukses • ${st.count} item'
                              : 'Menunggu';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: rowHighlightColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              st.running
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          Color(0xFF8FCE00),
                                        ),
                                      ),
                                    )
                                  : Icon(icon, color: color, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.label,
                                      style: TextStyle(
                                        color: st.running
                                            ? const Color(0xFFB7F542)
                                            : isWaiting
                                                ? Colors.white
                                            : st.done
                                                ? Colors.white38
                                                : Colors.white,
                                        fontSize: isHighlighted ? 15 : 13,
                                        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: st.running
                                            ? const Color(0xFFA8F02F)
                                            : isWaiting
                                                ? Colors.white
                                            : st.done
                                                ? Colors.white38
                                                : Colors.white70,
                                        fontSize: isHighlighted ? 13 : 11,
                                        fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  currentStep,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                if (!isSyncing && failedStep != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _startSync(startFrom: failedStep),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      child: const Text('ULANG STEP GAGAL'),
                    ),
                  ),

                const SizedBox(height: 16),
                const Text(
                  "Jangan tutup aplikasi selama proses berlangsung",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

