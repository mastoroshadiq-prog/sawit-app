import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_assignment.dart';
import 'package:kebun_sawit/mvc_dao/dao_reposisi.dart';
import 'package:kebun_sawit/mvc_models/assignment.dart';
import 'package:kebun_sawit/mvc_models/reposisi.dart';

class ReposisiDrilldownScreen extends StatefulWidget {
  const ReposisiDrilldownScreen({super.key});

  @override
  State<ReposisiDrilldownScreen> createState() => _ReposisiDrilldownScreenState();
}

class _ReposisiDetailItem {
  final String estate;
  final String divisi;
  final String blok;
  final String baris;
  final String npokok;
  final String perubahanTeks;
  final String keterangan;
  final String createdAt;

  const _ReposisiDetailItem({
    required this.estate,
    required this.divisi,
    required this.blok,
    required this.baris,
    required this.npokok,
    required this.perubahanTeks,
    required this.keterangan,
    required this.createdAt,
  });
}

class _ReposisiDrilldownScreenState extends State<ReposisiDrilldownScreen> {
  late Future<List<_ReposisiDetailItem>> _future;
  final TextEditingController _searchController = TextEditingController();
  final int _pageSize = 10;
  int _currentPage = 1;
  List<_ReposisiDetailItem> _allData = [];
  List<_ReposisiDetailItem> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<List<_ReposisiDetailItem>> _loadData() async {
    final reposisi = await ReposisiDao().getAllZeroReposisi();
    final assignments = await AssignmentDao().getAllAssignment();

    Assignment? findAssignment(Reposisi r) {
      for (final a in assignments) {
        if (a.block == r.blok && a.rowNumber == r.barisAwal) {
          return a;
        }
      }
      for (final a in assignments) {
        if (a.block == r.blok) return a;
      }
      return null;
    }

    return reposisi.map((r) {
      final a = findAssignment(r);
      final estate = (a?.estate.isNotEmpty ?? false) ? a!.estate : '-';
      final divisi = (a?.division.isNotEmpty ?? false) ? a!.division : '-';
      final perubahanTeks =
          'Pohon ${r.pohonAwal} baris ${r.barisAwal} dipetakan ke pohon ${r.pohonTujuan} baris ${r.barisTujuan}';
      return _ReposisiDetailItem(
        estate: estate,
        divisi: divisi,
        blok: r.blok,
        baris: r.barisAwal,
        npokok: r.pohonAwal,
        perubahanTeks: perubahanTeks,
        keterangan: r.keterangan,
        createdAt: r.createdAt,
      );
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredData = List<_ReposisiDetailItem>.from(_allData);
      } else {
        _filteredData = _allData.where((item) {
          return item.estate.toLowerCase().contains(q) ||
              item.divisi.toLowerCase().contains(q) ||
              item.blok.toLowerCase().contains(q) ||
              item.baris.toLowerCase().contains(q) ||
              item.npokok.toLowerCase().contains(q) ||
              item.keterangan.toLowerCase().contains(q) ||
              item.perubahanTeks.toLowerCase().contains(q);
        }).toList();
      }
      _currentPage = 1;
    });
  }

  int get _totalPages {
    if (_filteredData.isEmpty) return 1;
    return (_filteredData.length / _pageSize).ceil();
  }

  List<_ReposisiDetailItem> get _pagedItems {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drilldown Reposisi'),
        backgroundColor: const Color(0xFF8E6A8F),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<_ReposisiDetailItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          _allData = snapshot.data ?? const <_ReposisiDetailItem>[];
          if (_filteredData.isEmpty && _searchController.text.isEmpty) {
            _filteredData = List<_ReposisiDetailItem>.from(_allData);
          }

          if (_allData.isEmpty) {
            return const Center(
              child: Text('Belum ada data reposisi pending untuk ditampilkan.'),
            );
          }

          final pageItems = _pagedItems;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _applySearch,
                  decoration: InputDecoration(
                    hintText: 'Cari estate/divisi/blok/baris/npokok/detail...',
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
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: pageItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = pageItems[index];
                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estate ${item.estate} • Divisi ${item.divisi} • Blok ${item.blok}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 6),
                            Text('Baris: ${item.baris} • Npokok: ${item.npokok}'),
                            const SizedBox(height: 4),
                            Text('Perubahan: ${item.perubahanTeks}'),
                            const SizedBox(height: 4),
                            Text('Detail: ${item.keterangan}'),
                            const SizedBox(height: 4),
                            Text(
                              'Waktu input: ${_formatTimestamp(item.createdAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
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

