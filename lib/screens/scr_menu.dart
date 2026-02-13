// screens/assignment_list_screen.dart
import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_petugas.dart';
import 'package:kebun_sawit/mvc_models/laporan.dart';
import 'package:kebun_sawit/mvc_dao/dao_kesehatan.dart';
import 'package:kebun_sawit/mvc_dao/dao_observasi_tambahan.dart';
import 'package:kebun_sawit/mvc_dao/dao_reposisi.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr_log.dart';
import 'package:kebun_sawit/mvc_dao/dao_task_execution.dart';
import 'package:kebun_sawit/mvc_dao/dao_audit_log.dart';
import 'package:kebun_sawit/mvc_libs/active_block_store.dart';
import 'package:kebun_sawit/mvc_services/api_blok.dart';
import 'package:kebun_sawit/mvc_services/block_switch_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kebun_sawit/screens/scr_reposisi_drilldown.dart';
import '../mvc_libs/pdf_preview.dart';
import '../screens/widgets/w_general.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreen();
}

class _MenuScreen extends State<MenuScreen> {
  //late Future<Petugas?> petugas;
  //late Future<List<Assignment>> assignmentFuture;
  late final InformasiUmum infoUmum;
  late final RingkasanAktivitas ringkasan;
  late final List<RekapPekerjaan> listRekapPekerjaan;
  late final KesehatanTanaman kesehatanTanaman;
  String catatanLapangan = 'Tidak ada catatan tambahan.';
  bool fotoTerlampir = false;
  bool dokumentasiVisualTersedia = false;
  late final ValidasiPengesahan validasi;
  late final InformasiSistem infoSistem;
  late final RekapPekerjaan rekapPekerjaan;
  late Future<_FieldSummary> _summaryFuture;
  String _appVersionLabel = '-';
  bool _isSwitchingBlock = false;
  String _activeDivisi = '-';
  String _activeBlok = '-';

  static const List<String> _hari = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  static const List<String> _bulan = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  String _tanggalHariIniLabel() {
    final now = DateTime.now();
    final hari = _hari[now.weekday - 1];
    final tanggal = now.day.toString().padLeft(2, '0');
    final bulan = _bulan[now.month - 1];
    final tahun = now.year;
    return '$hari, $tanggal $bulan $tahun';
  }

  @override
  void initState() {
    super.initState();
    _summaryFuture = _loadFieldSummary();
    _loadAppVersion();
    _loadActiveContext();
    ActiveBlockStore.notifier.addListener(_onActiveBlockChanged);
    // Future dibuat sekali di initState
    // assignmentFuture = AssignmentDao().getAllAssignment();  // ambil data SQLite
    // petugas = PetugasDao().getPetugas();

    infoUmum = InformasiUmum(
        tanggalLaporan: DateTime.now().toIso8601String(),
        namaPetugas: 'namaPetugas',
        idPetugas: 'idPetugas',
        jabatan: 'jabatan',
        estateDivisi: 'estateDivisi'
    );

    ringkasan = RingkasanAktivitas(
        totalSpkDiterima: 10,
        spkSelesai: 8,
        spkDitunda: 2,
        totalPohonDitangani: 150,
        statusUmum: 'Sebagian'
    );

    rekapPekerjaan = RekapPekerjaan(
      noSpk: 'SPK001',
      jenisPekerjaan: 'Pemupukan',
      lokasiBlok: 'Blok A1',
      status: 'Selesai',
    );

    listRekapPekerjaan = [rekapPekerjaan];

    kesehatanTanaman = KesehatanTanaman(
      kesehatanJumlah: 150,
      kesehatanKeterangan: 'Sehat',
      reposisiJumlah: 5,
      reposisiKeterangan: 'Ditemukan',
    );

    validasi = ValidasiPengesahan(
      dibuatNama: '',
      dibuatId: '',
      dibuatTanggal: DateTime.now().toIso8601String(),
      diperiksaNama: '',
      diperiksaJabatan: '',
      diperiksaTanggal: '',
      catatanPemeriksa: '',
    );

    infoSistem = InformasiSistem(
      idLaporan: 'LAP123456',
      waktuGenerate: DateTime.now().toIso8601String(),
      perangkat: 'Android Device',
      statusSinkronisasi: 'Belum'
    );
  }

  @override
  void dispose() {
    ActiveBlockStore.notifier.removeListener(_onActiveBlockChanged);
    super.dispose();
  }

  void _onActiveBlockChanged() {
    _loadActiveContext();
  }

  Future<void> _loadActiveContext() async {
    final petugas = await PetugasDao().getPetugas();
    final divisiRaw = (petugas?.divisi ?? '-').trim();
    final blokStore = ((await ActiveBlockStore.get()) ?? '').trim();
    final blokRaw = blokStore.isNotEmpty ? blokStore : (petugas?.blok ?? '-').trim();

    if (!mounted) return;
    setState(() {
      _activeDivisi = divisiRaw.isEmpty ? '-' : divisiRaw;
      _activeBlok = blokRaw.isEmpty ? '-' : blokRaw;
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersionLabel = '${info.version}+${info.buildNumber}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appVersionLabel = '-';
      });
    }
  }

  Future<_FieldSummary> _loadFieldSummary() async {
    final tugasPending = (await TaskExecutionDao().getAllTaskExecByFlag()).length;
    final kesehatanPending = (await KesehatanDao().getAllZeroKesehatan()).length;
    final reposisiPending = (await ReposisiDao().getAllZeroReposisi()).length;
    final observasiPending =
        (await ObservasiTambahanDao().getAllZeroObservasi()).length;

    return _FieldSummary(
      tugasPending: tugasPending,
      kesehatanPending: kesehatanPending,
      reposisiPending: reposisiPending,
      observasiPending: observasiPending,
    );
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _summaryFuture = _loadFieldSummary();
    });
    await _summaryFuture;
  }

  Future<void> _openSwitchBlockDialog() async {
    if (_isSwitchingBlock) return;

    final petugas = await PetugasDao().getPetugas();
    final username = (petugas?.akun ?? '').trim();
    if (username.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data user lokal tidak ditemukan')),
      );
      return;
    }

    final listResult = await ApiBlok.getBlokList(username);
    if (!mounted) return;
    if (listResult['success'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ambil daftar blok: ${listResult['message']}')),
      );
      return;
    }

    final rows = (listResult['data'] as List?) ?? const [];
    final options = <String>[];
    for (final row in rows) {
      if (row is! Map) continue;
      final blok = (row['blok'] ?? '').toString().trim();
      if (blok.isEmpty) continue;
      if (!options.contains(blok)) options.add(blok);
    }

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar blok kosong untuk user ini')),
      );
      return;
    }

    final active = ((await ActiveBlockStore.get()) ?? '').trim();
    if (!mounted) return;
    var selected = active.isNotEmpty && options.contains(active) ? active : options.first;

    if (!context.mounted) return;
    final target = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Pindah Blok Aktif'),
            content: DropdownButtonFormField<String>(
              initialValue: selected,
              items: options
                  .map((b) => DropdownMenuItem<String>(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setLocal(() => selected = v);
              },
              decoration: const InputDecoration(
                labelText: 'Blok Tujuan',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(selected),
                child: const Text('Lanjut'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || target == null) return;
    final targetBlok = target.trim();
    if (targetBlok.isEmpty || targetBlok == active) {
      return;
    }

    final svc = BlockSwitchService();
    final hasPending = await svc.hasUnsyncedData();
    if (!mounted) return;

    if (hasPending) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Data Pending Belum Sync'),
          content: Text(
            'Masih ada data transaksi belum terkirim. '
            'Pindah blok sekarang berisiko mencampur konteks kerja.\n\n'
            'Jika lanjut, aplikasi akan otomatis sinkronisasi pending dulu, '
            'baru pindah ke blok $targetBlok.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sync & Pindah Blok'),
            ),
          ],
        ),
      );

      if (proceed != true || !mounted) return;
    }

    bool doSyncTarget = false;
    if (!hasPending) {
      final withSync = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Sinkronisasi Blok Tujuan'),
          content: Text(
            'Ingin sinkronisasi data blok $targetBlok sekarang?\n\n'
            'YA = fetch pohon+SPR blok tujuan (incremental).\n'
            'TIDAK = hanya pindah konteks blok aktif.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('TIDAK'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('YA, SYNC'),
            ),
          ],
        ),
      );

      if (!mounted || withSync == null) return;
      doSyncTarget = withSync;
    }

    setState(() => _isSwitchingBlock = true);
    BlockSwitchResult result;
    try {
      if (hasPending) {
        result = await svc.syncPendingThenSwitchBlock(
          username: username,
          targetBlok: targetBlok,
        );
      } else if (doSyncTarget) {
        result = await svc.syncTargetBlockData(
          username: username,
          targetBlok: targetBlok,
        );
      } else {
        result = await svc.switchContextOnly(targetBlok);
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitchingBlock = false);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    if (result.success) {
      await _refreshDashboard();
    }
  }

  Future<void> _openKoreksiTemuanAndRefresh() async {
    await Navigator.pushNamed(context, '/reposisi');
    if (!mounted) return;
    await _refreshDashboard();
    await _loadActiveContext();
  }

  Future<bool> _hasPendingSyncData() async {
    final tugas = (await TaskExecutionDao().getAllTaskExecByFlag()).isNotEmpty;
    final kesehatan = (await KesehatanDao().getAllZeroKesehatan()).isNotEmpty;
    final reposisi = (await ReposisiDao().getAllZeroReposisi()).isNotEmpty;
    final observasi = (await ObservasiTambahanDao().getAllZeroObservasi()).isNotEmpty;
    final spr = (await SPRLogDao().getAllZeroSPRLog()).isNotEmpty;
    final audit = (await AuditLogDao().getAllZeroAuditLog()).isNotEmpty;
    return tugas || kesehatan || reposisi || observasi || spr || audit;
  }

  Future<void> _handleSignOut() async {
    final hasPending = await _hasPendingSyncData();
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text(
          hasPending
              ? 'Masih ada data pending yang belum sync. Jika sign out sekarang, data lokal tetap disimpan di perangkat dan akan dilanjutkan saat login user yang sama.\n\nLanjut sign out?'
              : 'Keluar dari akun saat ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    await ActiveBlockStore.set('');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _menuItems(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Menu Utama'),
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F6A5A),
                const Color(0xFF2D8A73),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF1F7F5), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD6E7E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/icons/palm.png',
                        width: 22,
                        height: 22,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Akses Cepat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF225A4D),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pilih fitur untuk sinkronisasi, laporan, dan operasional lapangan.',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF4D7A6E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Versi aplikasi: $_appVersionLabel',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6A8D84),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _isSwitchingBlock ? null : _openSwitchBlockDialog,
                      icon: _isSwitchingBlock
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Pindah Blok Dinamis'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF225A4D),
                        side: BorderSide(color: const Color(0xFF225A4D).withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<_FieldSummary>(
              future: _summaryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8EDF2)),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 10),
                        Text('Menyiapkan status lapangan...'),
                      ],
                    ),
                  );
                }

                final s = snapshot.data!;
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE8EDF2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Hari Ini',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF225A4D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _tanggalHariIniLabel(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4D7A6E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F6A5A).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF1F6A5A).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              '$_activeDivisi : $_activeBlok',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF1F6A5A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _statusChip(
                              label: 'Task Pending',
                              value: s.tugasPending,
                              color: const Color(0xFF4E7FA8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statusChip(
                              label: 'Kesehatan',
                              value: s.kesehatanPending,
                              color: const Color(0xFF3C8D7A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _statusChip(
                              label: 'Reposisi',
                              value: s.reposisiPending,
                              color: const Color(0xFF8E6A8F),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ReposisiDrilldownScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _statusChip(
                              label: 'Observasi',
                              value: s.observasiPending,
                              color: const Color(0xFFB06E3D),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: menuItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.92, end: 1),
                      duration: Duration(milliseconds: 260 + (index * 90)),
                      curve: Curves.easeOutBack,
                      builder: (context, value, child) => Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.scale(scale: value, child: child),
                      ),
                      child: _buildMenuItem(
                        context,
                        icon: item.icon,
                        label: item.label,
                        iconColor: Colors.white,
                        circleColor: item.color,
                        onTap: item.onTap,
                      ),
                    );
                  },
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  List<_MenuAction> _menuItems(BuildContext context) {
    return [
      _MenuAction(
        icon: Icons.cloud_upload_rounded,
        label: 'SYNC',
        color: const Color(0xFF3C8D7A),
        onTap: cfgNavigator(
          context: context,
          action: 'push',
          routeName: '/syncPage',
        ),
      ),
      _MenuAction(
        icon: Icons.picture_as_pdf_rounded,
        label: 'REPORT',
        color: const Color(0xFF4E7FA8),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PreviewLaporanPdf(
                infoUmum: infoUmum,
                ringkasan: ringkasan,
                rekapPekerjaan: listRekapPekerjaan,
                kesehatanTanaman: kesehatanTanaman,
                catatanLapangan: catatanLapangan,
                fotoTerlampir: fotoTerlampir,
                dokumentasiVisualTersedia: dokumentasiVisualTersedia,
                validasi: validasi,
                infoSistem: infoSistem,
              ),
            ),
          );
        },
      ),
      _MenuAction(
        icon: Icons.assignment_rounded,
        label: 'TASK LIST',
        color: const Color(0xFF5B74A8),
        onTap: cfgNavigator(
          context: context,
          action: 'push',
          routeName: '/assignments',
        ),
      ),
      _MenuAction(
        icon: Icons.forest,
        label: 'KOREKSI & TEMUAN',
        color: const Color(0xFF8E6A8F),
        onTap: _openKoreksiTemuanAndRefresh,
      ),
    ];
  }

  // Helper Widget untuk membuat setiap item menu (Card)
  Widget _buildMenuItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        required Color iconColor,
        required Color circleColor,
      }) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.0),
      ),
      color: const Color(0xFFFBFCFD),
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8EDF2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // *** Bagian Ikon di dalam Lingkaran ***
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle, // Membuat bentuk lingkaran
                  boxShadow: [
                    BoxShadow(
                      color: circleColor.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: 36,
                  color: iconColor, // Warna ikon (misalnya, putih)
                ),
              ),
              // **************************************
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip({
    required String label,
    required int value,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Text(
                  '$value',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, size: 16, color: color.withValues(alpha: 0.9)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldSummary {
  final int tugasPending;
  final int kesehatanPending;
  final int reposisiPending;
  final int observasiPending;

  const _FieldSummary({
    required this.tugasPending,
    required this.kesehatanPending,
    required this.reposisiPending,
    required this.observasiPending,
  });
}

class _MenuAction {
  _MenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}
