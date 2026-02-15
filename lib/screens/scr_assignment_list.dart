// screens/assignment_list_screen.dart
import 'package:flutter/material.dart';
import '../mvc_dao/dao_petugas.dart';
import '../../mvc_dao/dao_assignment.dart';
import '../../mvc_models/assignment.dart';
import '../../mvc_models/petugas.dart';
import '../../mvc_services/api_spk.dart';
import '../../mvc_services/sop_sync_service.dart';

class AssignmentListScreen extends StatefulWidget {
  const AssignmentListScreen({super.key});

  @override
  State<AssignmentListScreen> createState() => _AssignmentListScreen();
}

class _AssignmentListScreen extends State<AssignmentListScreen> {
  final AssignmentDao _assignmentDao = AssignmentDao();
  final PetugasDao _petugasDao = PetugasDao();
  final SopSyncService _sopSyncService = SopSyncService();

  List<Assignment> _assignments = [];
  Petugas? _petugas;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _petugas = await _petugasDao.getPetugas();
      _assignments = await _assignmentDao.getAllAssignment();
      if (mounted) setState(() {});
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _safeStr(dynamic v, {String fallback = ''}) {
    if (v == null) return fallback;
    final s = v.toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Assignment _mapAssignment(Map<String, dynamic> item, String username) {
    final id = _safeStr(item['id_task']);
    final spk = _safeStr(item['nomor_spk']);
    final task = _safeStr(item['nama_task'], fallback: 'TASK');
    final block = _safeStr(item['lokasi'], fallback: '-');
    return Assignment(
      id: id.isNotEmpty ? id : '$spk-$block-$task',
      spkNumber: spk,
      taskName: task,
      estate: _safeStr(item['estate'], fallback: '-'),
      division: _safeStr(item['divisi'], fallback: '-'),
      block: block,
      rowNumber: _safeStr(item['nbaris'], fallback: '0'),
      treeNumber: _safeStr(item['n_pokok'], fallback: '0'),
      petugas: username,
    );
  }

  Future<void> _refreshFromServer({bool silentWhenFail = false}) async {
    if (_isRefreshing) return;
    final user = _petugas ?? await _petugasDao.getPetugas();
    final username = (user?.akun ?? '').trim();
    if (username.isEmpty) {
      if (!silentWhenFail && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun petugas lokal tidak ditemukan.')),
        );
      }
      return;
    }

    setState(() => _isRefreshing = true);
    try {
      final result = await ApiSPK.getTask(username);
      if (result['success'] != true) {
        if (!silentWhenFail && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Refresh task gagal: ${result['message']}')),
          );
        }
        return;
      }

      final data = (result['data'] as List?) ?? const [];
      final mapped = data
          .whereType<Map>()
          .map((e) => _mapAssignment(Map<String, dynamic>.from(e), username))
          .toList();

      final byKey = <String, Assignment>{};
      for (final a in mapped) {
        final key = '${a.id}|${a.spkNumber}|${a.taskName}|${a.block}';
        byKey[key] = a;
      }
      final fresh = byKey.values.toList();

      await _assignmentDao.deleteAllAssignments();
      if (fresh.isNotEmpty) {
        await _assignmentDao.insertAssignmentsBatch(fresh);
      }

      _assignments = await _assignmentDao.getAllAssignment();
      await _sopSyncService.pullFromServerSafe(
        spkNumbers: _assignments.map((e) => e.spkNumber).toSet(),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!silentWhenFail && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Refresh task error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1F6A5A);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Daftar Tugas'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F6A5A), Color(0xFF2D8A73)],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshFromServer,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF1F7F5), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD6E7E2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_rounded, color: primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _petugas == null
                                  ? 'Task lokal'
                                  : 'Task untuk ${_petugas!.akun}',
                              style: const TextStyle(
                                color: Color(0xFF225A4D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${_assignments.length} item',
                              style: const TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Refresh dari server',
                            onPressed: _isRefreshing ? null : _refreshFromServer,
                            icon: _isRefreshing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (_assignments.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8EDF2)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.inbox_rounded, size: 42, color: Color(0xFF8AA59B)),
                            SizedBox(height: 10),
                            Text(
                              'Tidak ada data tugas',
                              style: TextStyle(
                                color: Color(0xFF4D7A6E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._assignments.asMap().entries.map((entry) {
                        final index = entry.key;
                        final assignment = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  '/goDetail',
                                  arguments: assignment,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE1EBE7)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 24,
                                          height: 24,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: const Color(0xFF1F6A5A),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF1F6A5A)
                                                    .withValues(alpha: 0.25),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            '${index + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1F6A5A).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            assignment.spkNumber,
                                            style: const TextStyle(
                                              color: Color(0xFF1F6A5A),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFF8AA59B),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      assignment.taskName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF225A4D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined,
                                            size: 15, color: Color(0xFF5E8479)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${assignment.division}/${assignment.block} • Baris ${assignment.rowNumber}',
                                            style: const TextStyle(
                                              color: Color(0xFF5E8479),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

