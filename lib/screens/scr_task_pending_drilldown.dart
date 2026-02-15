import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_assignment.dart';
import 'package:kebun_sawit/mvc_dao/dao_task_execution.dart';
import 'package:kebun_sawit/mvc_models/assignment.dart';
import 'package:kebun_sawit/mvc_models/execution.dart';

class TaskPendingDrilldownScreen extends StatefulWidget {
  const TaskPendingDrilldownScreen({super.key, this.showDone = false});

  final bool showDone;

  @override
  State<TaskPendingDrilldownScreen> createState() => _TaskPendingDrilldownScreenState();
}

class _TaskPendingItem {
  final String spk;
  final String taskName;
  final String taskState;
  final String petugas;
  final String taskDate;
  final String note;
  final String imagePath;
  final String estate;
  final String divisi;
  final String blok;
  final String baris;
  final String pohon;

  const _TaskPendingItem({
    required this.spk,
    required this.taskName,
    required this.taskState,
    required this.petugas,
    required this.taskDate,
    required this.note,
    required this.imagePath,
    required this.estate,
    required this.divisi,
    required this.blok,
    required this.baris,
    required this.pohon,
  });
}

enum _TaskExecFilter { pending, done }

class _TaskPendingDrilldownScreenState extends State<TaskPendingDrilldownScreen> {
  late Future<List<_TaskPendingItem>> _future;
  final TextEditingController _searchController = TextEditingController();
  final int _pageSize = 10;
  int _currentPage = 1;
  List<_TaskPendingItem> _allData = [];
  List<_TaskPendingItem> _filteredData = [];
  _TaskExecFilter _filter = _TaskExecFilter.pending;

  @override
  void initState() {
    super.initState();
    _filter = widget.showDone ? _TaskExecFilter.done : _TaskExecFilter.pending;
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_TaskPendingItem>> _loadData() async {
    final execs = _filter == _TaskExecFilter.pending
        ? await TaskExecutionDao().getPendingTaskExec()
        : await TaskExecutionDao().getDoneTaskExec();
    final assignments = await AssignmentDao().getAllAssignment();

    Assignment? findAssignment(TaskExecution e) {
      for (final a in assignments) {
        if (a.spkNumber == e.spkNumber && a.taskName == e.taskName) {
          return a;
        }
      }
      for (final a in assignments) {
        if (a.spkNumber == e.spkNumber) return a;
      }
      return null;
    }

    return execs.map((e) {
      final a = findAssignment(e);
      return _TaskPendingItem(
        spk: e.spkNumber,
        taskName: e.taskName,
        taskState: e.taskState,
        petugas: e.petugas,
        taskDate: e.taskDate,
        note: e.keterangan,
        imagePath: (e.imagePath ?? '').trim(),
        estate: a?.estate ?? '-',
        divisi: a?.division ?? '-',
        blok: a?.block ?? '-',
        baris: a?.rowNumber ?? '-',
        pohon: a?.treeNumber ?? '-',
      );
    }).toList();
  }

  Future<void> _reloadByFilter(_TaskExecFilter value) async {
    setState(() {
      _filter = value;
      _searchController.clear();
      _allData = [];
      _filteredData = [];
      _currentPage = 1;
      _future = _loadData();
    });
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredData = List<_TaskPendingItem>.from(_allData);
      } else {
        _filteredData = _allData.where((item) {
          return item.spk.toLowerCase().contains(q) ||
              item.taskName.toLowerCase().contains(q) ||
              item.taskState.toLowerCase().contains(q) ||
              item.petugas.toLowerCase().contains(q) ||
              item.estate.toLowerCase().contains(q) ||
              item.divisi.toLowerCase().contains(q) ||
              item.blok.toLowerCase().contains(q) ||
              item.baris.toLowerCase().contains(q) ||
              item.pohon.toLowerCase().contains(q) ||
              item.note.toLowerCase().contains(q);
        }).toList();
      }
      _currentPage = 1;
    });
  }

  int get _totalPages {
    if (_filteredData.isEmpty) return 1;
    return (_filteredData.length / _pageSize).ceil();
  }

  List<_TaskPendingItem> get _pagedItems {
    if (_filteredData.isEmpty) return const [];
    final safePage = _currentPage.clamp(1, _totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize > _filteredData.length)
        ? _filteredData.length
        : start + _pageSize;
    return _filteredData.sublist(start, end);
  }

  String _formatTimestamp(String raw) {
    if (raw.isEmpty) return '-';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _filter == _TaskExecFilter.pending;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: Text(isPending ? 'Drilldown Task Pending' : 'Drilldown Task Done'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isPending
                  ? const [Color(0xFF4E7FA8), Color(0xFF6597C0)]
                  : const [Color(0xFF3C8D7A), Color(0xFF54A792)],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<_TaskPendingItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          _allData = snapshot.data ?? const <_TaskPendingItem>[];
          if (_filteredData.isEmpty && _searchController.text.isEmpty) {
            _filteredData = List<_TaskPendingItem>.from(_allData);
          }

          if (_allData.isEmpty) {
            return Center(
              child: Text(
                isPending
                    ? 'Belum ada task pending untuk ditampilkan.'
                    : 'Belum ada task done untuk ditampilkan.',
              ),
            );
          }

          final pageItems = _pagedItems;
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EDF2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('PENDING'),
                            selected: isPending,
                            onSelected: (_) => _reloadByFilter(_TaskExecFilter.pending),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('DONE'),
                            selected: !isPending,
                            onSelected: (_) => _reloadByFilter(_TaskExecFilter.done),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      onChanged: _applySearch,
                      decoration: InputDecoration(
                        hintText: 'Cari SPK/task/status/lokasi/catatan...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _applySearch('');
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: pageItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = pageItems[index];
                    final hasPhoto = item.imagePath.isNotEmpty && item.imagePath != '-';
                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE1EBE7)),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isPending
                                            ? const Color(0xFF4E7FA8)
                                            : const Color(0xFF3C8D7A))
                                        .withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    item.taskState,
                                    style: TextStyle(
                                      color: isPending
                                          ? const Color(0xFF3E6B93)
                                          : const Color(0xFF2D7D6B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _formatTimestamp(item.taskDate),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6A8D84),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'SPK ${item.spk} • ${item.taskName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF225A4D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Status: ${item.taskState} • Petugas: ${item.petugas}'),
                            const SizedBox(height: 4),
                            Text(
                              'Lokasi: Estate ${item.estate} • Divisi ${item.divisi} • '
                              'Blok ${item.blok} • Baris ${item.baris} • Pohon ${item.pohon}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Catatan: ${item.note.isEmpty ? '-' : item.note}',
                            ),
                            const SizedBox(height: 4),
                            Text(
                              hasPhoto ? 'Foto: tersedia' : 'Foto: tidak ada',
                              style: TextStyle(
                                color: hasPhoto ? Colors.green.shade700 : Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Text('Page $_currentPage / $_totalPages'),
                    const Spacer(),
                    TextButton(
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                      child: const Text('Prev'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _currentPage < _totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

