import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_assignment.dart';
import 'package:kebun_sawit/mvc_dao/dao_observasi_tambahan.dart';
import 'package:kebun_sawit/mvc_models/assignment.dart';
import 'package:kebun_sawit/mvc_models/observasi_tambahan.dart';

class ObservasiDrilldownScreen extends StatefulWidget {
  const ObservasiDrilldownScreen({super.key});

  @override
  State<ObservasiDrilldownScreen> createState() => _ObservasiDrilldownScreenState();
}

class _ObservasiItem {
  final String estate;
  final String divisi;
  final String blok;
  final String baris;
  final String pohon;
  final String kategori;
  final String detail;
  final String catatan;
  final String petugas;
  final String createdAt;

  const _ObservasiItem({
    required this.estate,
    required this.divisi,
    required this.blok,
    required this.baris,
    required this.pohon,
    required this.kategori,
    required this.detail,
    required this.catatan,
    required this.petugas,
    required this.createdAt,
  });
}

class _ObservasiDrilldownScreenState extends State<ObservasiDrilldownScreen> {
  late Future<List<_ObservasiItem>> _future;
  final TextEditingController _searchController = TextEditingController();
  final int _pageSize = 10;
  int _currentPage = 1;
  List<_ObservasiItem> _allData = [];
  List<_ObservasiItem> _filteredData = [];

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_ObservasiItem>> _loadData() async {
    final observasi = await ObservasiTambahanDao().getAllZeroObservasi();
    final assignments = await AssignmentDao().getAllAssignment();

    Assignment? findAssignment(ObservasiTambahan o) {
      for (final a in assignments) {
        if (a.block == o.blok && a.rowNumber == o.baris) {
          return a;
        }
      }
      for (final a in assignments) {
        if (a.block == o.blok) return a;
      }
      return null;
    }

    return observasi.map((o) {
      final a = findAssignment(o);
      return _ObservasiItem(
        estate: (a?.estate.isNotEmpty ?? false) ? a!.estate : '-',
        divisi: (a?.division.isNotEmpty ?? false) ? a!.division : '-',
        blok: o.blok,
        baris: o.baris,
        pohon: o.pohon,
        kategori: o.kategori,
        detail: o.detail,
        catatan: o.catatan,
        petugas: o.petugas,
        createdAt: o.createdAt,
      );
    }).toList();
  }

  void _applySearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredData = List<_ObservasiItem>.from(_allData);
      } else {
        _filteredData = _allData.where((item) {
          return item.estate.toLowerCase().contains(q) ||
              item.divisi.toLowerCase().contains(q) ||
              item.blok.toLowerCase().contains(q) ||
              item.baris.toLowerCase().contains(q) ||
              item.pohon.toLowerCase().contains(q) ||
              item.kategori.toLowerCase().contains(q) ||
              item.detail.toLowerCase().contains(q) ||
              item.catatan.toLowerCase().contains(q) ||
              item.petugas.toLowerCase().contains(q);
        }).toList();
      }
      _currentPage = 1;
    });
  }

  int get _totalPages {
    if (_filteredData.isEmpty) return 1;
    return (_filteredData.length / _pageSize).ceil();
  }

  List<_ObservasiItem> get _pagedItems {
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
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Drilldown Observasi'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFB06E3D), Color(0xFFC58A5F)],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<_ObservasiItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi error: ${snapshot.error}'));
          }

          _allData = snapshot.data ?? const <_ObservasiItem>[];
          if (_filteredData.isEmpty && _searchController.text.isEmpty) {
            _filteredData = List<_ObservasiItem>.from(_allData);
          }

          if (_allData.isEmpty) {
            return const Center(
              child: Text('Belum ada data observasi pending untuk ditampilkan.'),
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
                child: TextField(
                  controller: _searchController,
                  onChanged: _applySearch,
                  decoration: InputDecoration(
                    hintText: 'Cari lokasi/kategori/detail/catatan/petugas...',
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
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB06E3D).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  item.kategori,
                                  style: const TextStyle(
                                    color: Color(0xFF9A5F33),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimestamp(item.createdAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6A8D84),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Estate ${item.estate} • Divisi ${item.divisi} • Blok ${item.blok}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF225A4D),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Baris: ${item.baris} • Pohon: ${item.pohon}'),
                          const SizedBox(height: 4),
                          Text('Detail: ${item.detail}'),
                          const SizedBox(height: 4),
                          Text('Catatan: ${item.catatan.isEmpty ? '-' : item.catatan}'),
                          const SizedBox(height: 4),
                          Text(
                            'Petugas: ${item.petugas}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
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

