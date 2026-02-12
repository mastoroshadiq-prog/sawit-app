// lib/screens/scr_sync_action.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../mvc_libs/connection_utils.dart';
import 'sync/sync_models.dart';
import 'sync/sync_service.dart';
import 'sync/sync_widgets.dart';

class SyncPage extends StatefulWidget {
  const SyncPage({super.key});

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _BatchTask {
  final BatchKind kind;
  final String label;
  final List<List<Map<String, dynamic>>> data;
  _BatchTask(this.kind, this.label, this.data);
}

class _SyncPageState extends State<SyncPage> {
  // -----------------------------
  // SERVICES & COLORS
  // -----------------------------
  final SyncService _syncService = SyncService();

  final Color primary = Colors.green.shade700;
  final Color secondary = Colors.green.shade200;
  final Color accent = Colors.green.shade50;
  final Color textColor = Colors.green.shade900;
  final Color progressBg = Colors.green.shade100;
  final Color successColor = Colors.green.shade400;

  // -----------------------------
  // STATE
  // -----------------------------
  bool isFetching = false;
  bool isSending = false;

  // Store data per batch
  //List<Map<String, dynamic>> batchTugas = [];
  //List<Map<String, dynamic>> batchKesehatan = [];
  //List<Map<String, dynamic>> batchReposisi = [];
  //List<Map<String, dynamic>> batchSPRlog = [];
  //List<Map<String, dynamic>> batchAuditlog = [];

  List<List<Map<String, dynamic>>> batchTugas = [];
  List<List<Map<String, dynamic>>> batchKesehatan = [];
  List<List<Map<String, dynamic>>> batchReposisi = [];
  List<List<Map<String, dynamic>>> batchObservasi = [];
  List<List<Map<String, dynamic>>> batchSPRlog = [];
  List<List<Map<String, dynamic>>> batchAuditlog = [];

  // State per batch
  Map<BatchKind, BatchState> states = {
    BatchKind.tugas: BatchState.idle,
    BatchKind.kesehatan: BatchState.idle,
    BatchKind.reposisi: BatchState.idle,
    BatchKind.observasi: BatchState.idle,
    BatchKind.auditlog: BatchState.idle,
    BatchKind.sprlog: BatchState.idle,
  };

  // Messages per batch after send
  Map<BatchKind, String> resultMessages = {
    BatchKind.tugas: "",
    BatchKind.kesehatan: "",
    BatchKind.reposisi: "",
    BatchKind.observasi: "",
    BatchKind.auditlog: "",
    BatchKind.sprlog: "",
  };

  // Progress tracking
  double fetchProgress = 0.0;
  String fetchLabel = "";
  double sendProgress = 0.0;
  String sendLabel = "";

  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _wasInternetAvailable = true;
  bool _isInternetRestoreDialogOpen = false;

  @override
  void initState() {
    super.initState();
    isFetching = false;
    isSending = false;
    _initConnectivityWatcher();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivityWatcher() async {
    _wasInternetAvailable = await ConnectionUtils.checkConnection();

    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((_) async {
      final nowConnected = await ConnectionUtils.checkConnection();
      if (!mounted) return;

      if (!_wasInternetAvailable && nowConnected) {
        _onInternetRestored();
      }

      _wasInternetAvailable = nowConnected;
    });
  }

  bool _hasPendingDataToSync() {
    return batchTugas.isNotEmpty ||
        batchKesehatan.isNotEmpty ||
        batchReposisi.isNotEmpty ||
        batchObservasi.isNotEmpty ||
        batchSPRlog.isNotEmpty ||
        batchAuditlog.isNotEmpty;
  }

  Future<void> _onInternetRestored() async {
    if (!mounted || isSending || isFetching) return;
    if (!_hasPendingDataToSync()) return;
    if (_isInternetRestoreDialogOpen) return;

    _isInternetRestoreDialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Koneksi Internet"),
        content: const Text(
          "koneksi internet tersedia, silakan lakukan sync segera..",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendAllBatchesX();
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );

    _isInternetRestoreDialogOpen = false;
  }

  // -----------------------------------------
  // AUTO FETCH ALL BATCHES
  // -----------------------------------------
  Future<void> _autoFetchAllBatches() async {
    setState(() {
      isFetching = true;
      fetchProgress = 0.0;
      fetchLabel = "Mulai mengumpulkan data...";
      states[BatchKind.tugas] = BatchState.fetching;
    });

    // 1/4 - tugas
    setState(() => fetchLabel = "Mengumpulkan Data â€” Status Tugas");
    final tugas = await _syncService.fetchTugasFromSqliteX();
    setState(() {
      batchTugas = tugas;
      states[BatchKind.tugas] = BatchState.ready;
      fetchProgress = 1 / 6;
    });

    // 2/4 - kesehatan
    setState(() {
      states[BatchKind.kesehatan] = BatchState.fetching;
      fetchLabel = "Mengumpulkan Data â€” Status Kesehatan";
    });
    final kesehatan = await _syncService.fetchKesehatanFromSqliteX();
    setState(() {
      batchKesehatan = kesehatan;
      states[BatchKind.kesehatan] = BatchState.ready;
      fetchProgress = 2 / 6;
    });

    // 3/4 - reposisi
    setState(() {
      states[BatchKind.reposisi] = BatchState.fetching;
      fetchLabel = "Mengumpulkan Data â€” Status Reposisi";
    });
    //final reposisi = await _syncService.fetchReposisiFromSqlite();
   //final reposisi = await _syncService.fetchReposisiBatch();
   final reposisi = await _syncService.fetchReposisiBatchX();
    setState(() {
      batchReposisi = reposisi;
      states[BatchKind.reposisi] = BatchState.ready;
      fetchProgress = 3 / 6;
    });

    // 4/6 - observasi tambahan
    setState(() {
      states[BatchKind.observasi] = BatchState.fetching;
      fetchLabel = "Mengumpulkan Data — Observasi Tambahan";
    });
    final observasi = await _syncService.fetchObservasiBatchX();
    setState(() {
      batchObservasi = observasi;
      states[BatchKind.observasi] = BatchState.ready;
      fetchProgress = 4 / 6;
    });

    // 5/6 - Stand Per Row
    setState(() {
      states[BatchKind.sprlog] = BatchState.fetching;
      fetchLabel = "Mengumpulkan Data â€” Stand Per Row Log";
    });
    final sprlog = await _syncService.fetchSPRBatch();
    debugPrint("Jumlah Batch SPRlog: ${sprlog.length}");
    setState(() {
      batchSPRlog = sprlog;
      states[BatchKind.sprlog] = BatchState.ready;
      fetchProgress = 5 / 6;
    });

    // 6/6 - auditlog
    setState(() {
      states[BatchKind.auditlog] = BatchState.fetching;
      fetchLabel = "Mengumpulkan Data â€” Status Auditlog";
    });
    //final auditlog = await _syncService.fetchAuditLogFromSqlite();
    final auditlog = await _syncService.fetchAuditLogBatchX();
    setState(() {
      batchAuditlog = auditlog;
      states[BatchKind.auditlog] = BatchState.ready;
      fetchProgress = 1.0;
    });

    // Selesai
    setState(() {
      isFetching = false;
      fetchLabel = "Pengumpulan data selesai";
    });
  }

  // -----------------------------------------
  // SEND ALL BATCHES
  // -----------------------------------------

  // -----------------------------------------
// SEND ALL BATCHES (REFACTORED)
// -----------------------------------------
  Future<void> _sendAllBatchesX() async {
    setState(() {
      isSending = true;
      sendProgress = 0.0;
      sendLabel = "Mulai pengiriman data...";
      resultMessages.updateAll((key, value) => "");
      // Reset state hanya jika sebelumnya ready atau failed
      states.updateAll((key, value) =>
      (value == BatchState.ready || value == BatchState.failed) ? BatchState.idle : value
      );
    });

    // Definisikan daftar batch yang akan diproses
    // Struktur: Kind, Label, Data (List of Batches)
    final List<_BatchTask> tasks = [
      _BatchTask(BatchKind.tugas, "Status Tugas", batchTugas),
      _BatchTask(BatchKind.kesehatan, "Status Kesehatan", batchKesehatan),
      _BatchTask(BatchKind.reposisi, "Status Reposisi", batchReposisi),
      _BatchTask(BatchKind.observasi, "Observasi Tambahan", batchObservasi),
      _BatchTask(BatchKind.sprlog, "Stand Per Row", batchSPRlog),
      _BatchTask(BatchKind.auditlog, "Audit Log", batchAuditlog),
    ];

    // Hitung total kategori yang memiliki data untuk progress bar
    final tasksToProcess = tasks.where((t) => t.data.isNotEmpty).toList();
    int completedTasks = 0;

    for (var task in tasksToProcess) {
      if (!mounted) return;

      setState(() {
        states[task.kind] = BatchState.sending;
        sendLabel = "Mengirim ${task.label}...";
      });

      int subBatchCounter = 0;
      bool categorySuccess = true;
      String lastError = "";

      // Loop melalui sub-batch (List<Map<String, dynamic>>)
      for (var subBatch in task.data) {
        subBatchCounter++;

        try {
          final dataRespon = await _syncService.postJsonToServer(payload: subBatch);
          String result = ConnectionUtils().parseSqlError(dataRespon);

          bool isOk = result.toLowerCase().contains("berhasil") ||
              result.toLowerCase().contains("success") ||
              !result.toLowerCase().contains("error");

          if (isOk) {
            // Update flag di SQLite per sub-batch
            await _syncService.updateFlagsAfterSuccess(
              kind: task.kind,
              items: subBatch,
              label: "${task.label} (Batch $subBatchCounter)",
            );
          } else {
            categorySuccess = false;
            lastError = result;
            break; // Hentikan sub-batch kategori ini jika gagal
          }
        } catch (e) {
          categorySuccess = false;
          lastError = e.toString();
          break;
        }
      }

      // Update status akhir per kategori
      setState(() {
        if (categorySuccess) {
          states[task.kind] = BatchState.success;
          resultMessages[task.kind] = "Berhasil mengirim ${task.data.length} batch.";
        } else {
          states[task.kind] = BatchState.failed;
          resultMessages[task.kind] = "Gagal pada batch $subBatchCounter: $lastError";
          // Jika koneksi putus total, Anda bisa memilih untuk stop semua task di sini
        }

        completedTasks++;
        sendProgress = completedTasks / tasksToProcess.length;
      });

      // Beri jeda sedikit agar UI tidak kaku
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      isSending = false;
      sendLabel = "Pengiriman selesai";
    });

    _showSummaryDialog();
  }

  // --- FUNGSI HELPER UNTUK REPOSISI (LOOPING) ---
// ignore: unused_element
  Future<void> _processReposisiInBatches() async {
    bool hasMore = true;
    int batchCounter = 1;
    int totalDataTerkirim = 0;

    while (hasMore) {
      // Ambil data dari SQLite (limit 10 di DAO)
      //final List<Map<String, dynamic>> currentItems = await _syncService.fetchReposisiBatch();
      final List<List<Map<String, dynamic>>> currentItems = await _syncService.fetchReposisiBatchX();
      if (currentItems.isEmpty) {
        hasMore = false;
        // Jika ini loop pertama dan sudah kosong, set idle
        if (batchCounter == 1) setState(() => states[BatchKind.reposisi] = BatchState.idle);
        break;
      }

      debugPrint("Jumlah Batch ${currentItems.length}");

      //for (var batch in currentItems) {
      for (int i = 0; i < currentItems.length; i++) {

        List<Map<String, dynamic>> dataPerBatch = currentItems[i];
        // Jika ingin memproses item di dalam batchData tersebut:
        for (var item in dataPerBatch) {
          debugPrint("Target: ${item["TARGET"]}, Params: ${item["PARAMS"]}");
        }
        setState(() {
          states[BatchKind.reposisi] = BatchState.sending;
          sendLabel = "Mengirim Reposisi (Batch #$batchCounter)...";
        });

        final dataRespon = await _syncService.postJsonToServer(payload: dataPerBatch);
        debugPrint("Reposisi Batch #$batchCounter Response: $dataRespon");
        String result = ConnectionUtils().parseSqlError(dataRespon);

        bool ok = result.toLowerCase().contains("berhasil") ||
            result.toLowerCase().contains("success") ||
            !result.toLowerCase().contains("error");

        if (ok) {
          // PENTING: Update flag ke 1 supaya data ini tidak muncul lagi di fetchReposisiBatch berikutnya
          await _syncService.updateFlagsAfterSuccess(
            kind: BatchKind.reposisi,
            items: dataPerBatch,
            label: "Reposisi Batch $batchCounter",
          );

          totalDataTerkirim += (dataPerBatch.length ~/ 1); // Dibagi 2 karena 1 repo = 2 maps (URP & IRP)
          batchCounter++;

          // Jika data yang diambil kurang dari 10, berarti ini batch terakhir
          if (dataPerBatch.length < 10) { // 10 maps = 10 record Reposisi
            hasMore = false;
          }
        } else {
          // Jika gagal, hentikan loop agar tidak terjadi infinite loop pada data error
          setState(() {
            states[BatchKind.reposisi] = BatchState.failed;
            resultMessages[BatchKind.reposisi] = "Gagal pada batch $batchCounter: $result";
          });
          hasMore = false;
          return;
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }// while (hasMore)

    if (states[BatchKind.reposisi] != BatchState.failed) {
      setState(() {
        states[BatchKind.reposisi] = BatchState.success;
        resultMessages[BatchKind.reposisi] = "Berhasil mengirim $totalDataTerkirim data reposisi.";
      });
    }
  }

  // AUDITLOG PROCESSING
// ignore: unused_element
  Future<void> _processAuditLogInBatches() async {
    bool hasMore = true;
    int batchCounter = 1;
    int totalTerkirim = 0;

    while (hasMore) {
      //final List<Map<String, dynamic>> currentItems = await _syncService.fetchAuditLogBatch();
      final List<List<Map<String, dynamic>>> currentItems = await _syncService.fetchAuditLogBatchX();
      if (currentItems.isEmpty) {
        hasMore = false;
        if (batchCounter == 1) setState(() => states[BatchKind.auditlog] = BatchState.idle);
        break;
      }

      //for (var batch in currentItems) {
      for (int i = 0; i < currentItems.length; i++) {
        List<Map<String, dynamic>> dataPerBatch = currentItems[i];

        setState(() {
          states[BatchKind.auditlog] = BatchState.sending;
          sendLabel = "Mengirim Audit Log (Batch #$batchCounter)...";
        });

        final dataRespon = await _syncService.postJsonToServer(payload: dataPerBatch);
        String result = ConnectionUtils().parseSqlError(dataRespon);

        bool ok = result.toLowerCase().contains("berhasil") ||
            result.toLowerCase().contains("success") ||
            !result.toLowerCase().contains("error");

        if (ok) {
          await _syncService.updateFlagsAfterSuccess(
            kind: BatchKind.auditlog,
            items: dataPerBatch,
            label: "Audit Log Batch $batchCounter",
          );

          totalTerkirim += dataPerBatch.length;
          batchCounter++;

          // Jika data yang didapat kurang dari limit (misal limit DAO adalah 10)
          if (dataPerBatch.length < 10) hasMore = false;
        } else {
          setState(() {
            states[BatchKind.auditlog] = BatchState.failed;
            resultMessages[BatchKind.auditlog] = "Gagal pada batch $batchCounter: $result";
          });
          hasMore = false;
          return;
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }// while (hasMore)

    if (states[BatchKind.auditlog] != BatchState.failed) {
      setState(() {
        states[BatchKind.auditlog] = BatchState.success;
        resultMessages[BatchKind.auditlog] = "Berhasil mengirim $totalTerkirim data audit log.";
      });
    }
  }

  // -----------------------------------------
  // DIALOGS
  // -----------------------------------------
  void _showSummaryDialog() {
    final successCount = states.values
        .where((s) => s == BatchState.success)
        .length;
    final failCount = states.values.where((s) => s == BatchState.failed).length;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_done, color: Colors.green),
            SizedBox(width: 8),
            Text("Ringkasan Pengiriman"),
          ],
        ),
        content: Text(
          "Selesai.\nSukses: $successCount batch\nGagal: $failCount batch\n\nCek detail respons pada tiap batch.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  void _showNoConnectionDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: navigator.context,
      builder: (c) => AlertDialog(
        title: const Text("Peringatan"),
        content: const Text("Tidak ada koneksi internet"),
        actions: [
          TextButton(onPressed: () => navigator.pop(), child: const Text("OK")),
        ],
      ),
    );
  }

  void _showConfirmSendDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Konfirmasi Kirim"),
        content: const Text("Kirim data yang sudah siap ke server sekarang?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              final isConnected = await ConnectionUtils.checkConnection();
              if (!isConnected) {
                _showNoConnectionDialog();
              } else {
                if (!mounted) return;
                Navigator.of(context).pop();
                _sendAllBatchesX();
              }
            },
            child: const Text("Kirim"),
          ),
        ],
      ),
    );
  }

  // -----------------------------------------
  // BUTTON HANDLERS
  // -----------------------------------------
  Future<void> _onSendPressedWithCheck() async {
    final isConnected = await ConnectionUtils.checkConnection();
    if (!isConnected) {
      _showNoConnectionDialog();
      return;
    }
    _showConfirmSendDialog();
  }

  void _onFetchPressed() {
    setState(() {
      resultMessages.updateAll((key, value) => "");
      states.updateAll((key, value) => BatchState.idle);
      batchTugas.clear();
      batchKesehatan.clear();
      batchReposisi.clear();
      batchObservasi.clear();
      batchSPRlog.clear();
      batchAuditlog.clear();
    });
    _autoFetchAllBatches();
  }

  // -----------------------------------------
  // UI BUILDING
  // -----------------------------------------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSending,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: accent,
        appBar: AppBar(
          backgroundColor: primary,
          title: const Text("Sinkronisasi Data Tugas"),
        ),
        body: Stack(
          children: [
            _buildMainContent(),
            if (isSending)
              SendingOverlay(
                sendProgress: sendProgress,
                sendLabel: sendLabel,
                primary: primary,
                progressBg: progressBg,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildFetchButton(),
            const SizedBox(height: 14),
            FetchProgressSection(
              isFetching: isFetching,
              fetchProgress: fetchProgress,
              fetchLabel: fetchLabel,
              primary: primary,
              progressBg: progressBg,
              textColor: textColor,
            ),
            const SizedBox(height: 18),
            BatchDataCard(
              states: states,
              tugasCount: batchTugas.length,
              kesehatanCount: batchKesehatan.length,
              reposisiCount: batchReposisi.length,
              observasiCount: batchObservasi.length,
              auditlogCount: batchAuditlog.length,
              sprlogCount: batchSPRlog.length,
              secondary: secondary,
              textColor: textColor,
            ),
            const SizedBox(height: 18),
            _buildActionArea(),
            const SizedBox(height: 12),
            _buildResultDetails(),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchButton() {
    final canFetch = !isFetching && !isSending;

    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: canFetch ? _onFetchPressed : null,
      icon: const Icon(Icons.refresh),
      label: const Text(
        "AMBIL DATA",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildActionArea() {
    final canSend =
        !isFetching &&
        (batchTugas.isNotEmpty ||
            batchKesehatan.isNotEmpty ||
            batchReposisi.isNotEmpty ||
            batchObservasi.isNotEmpty ||
            batchSPRlog.isNotEmpty ||
            batchAuditlog.isNotEmpty) &&
        !isSending;

    return Column(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: canSend ? _onSendPressedWithCheck : null,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text(
            "KIRIM KE SERVER",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
        if (!canSend)
          Text(
            isFetching
                ? "Menunggu pengumpulan data selesai..."
                : "Tidak ada data untuk dikirim",
            style: TextStyle(color: textColor.withValues(alpha: 0.8)),
          ),
      ],
    );
  }

  Widget _buildResultDetails() {
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: [
            BatchResultPanel(
              kind: BatchKind.tugas,
              message: resultMessages[BatchKind.tugas] ?? "",
              state: states[BatchKind.tugas] ?? BatchState.idle,
              successColor: successColor,
            ),
            const SizedBox(height: 8),
            BatchResultPanel(
              kind: BatchKind.kesehatan,
              message: resultMessages[BatchKind.kesehatan] ?? "",
              state: states[BatchKind.kesehatan] ?? BatchState.idle,
              successColor: successColor,
            ),
            const SizedBox(height: 8),
            BatchResultPanel(
              kind: BatchKind.reposisi,
              message: resultMessages[BatchKind.reposisi] ?? "",
              state: states[BatchKind.reposisi] ?? BatchState.idle,
              successColor: successColor,
            ),
            const SizedBox(height: 8),
            BatchResultPanel(
              kind: BatchKind.observasi,
              message: resultMessages[BatchKind.observasi] ?? "",
              state: states[BatchKind.observasi] ?? BatchState.idle,
              successColor: successColor,
            ),
            const SizedBox(height: 8),
            BatchResultPanel(
              kind: BatchKind.sprlog,
              message: resultMessages[BatchKind.sprlog] ?? "",
              state: states[BatchKind.sprlog] ?? BatchState.idle,
              successColor: successColor,
            ),
            const SizedBox(height: 8),
            BatchResultPanel(
              kind: BatchKind.auditlog,
              message: resultMessages[BatchKind.auditlog] ?? "",
              state: states[BatchKind.auditlog] ?? BatchState.idle,
              successColor: successColor,
            ),
          ],
        ),
      ),
    );
  }
}

