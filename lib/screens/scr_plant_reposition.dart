// screens/labs/scr_plant_health.dart
import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr.dart';
import 'package:kebun_sawit/mvc_models/spr.dart';
import 'package:kebun_sawit/screens/scr_models/reposition_result.dart';
import '../../screens/widgets/w_general.dart';
import '../../mvc_dao/dao_pohon.dart';
import '../../mvc_models/pohon.dart';
import '../../screens/widgets/w_reposition.dart';
import '../mvc_dao/dao_petugas.dart';
import '../mvc_models/petugas.dart';

class PlantRepositionScreen extends StatefulWidget {
  const PlantRepositionScreen({super.key});

  @override
  State<PlantRepositionScreen> createState() => _PlantRepositionScreen();
}

class _PlantRepositionScreen extends State<PlantRepositionScreen> {
  late Future<List<Pohon>> pohonFuture;
  late Petugas? petugas;
  late List<SPR> spr;
  //late Assignment assignment;
  String? divisi;
  String? blok;
  String? pengguna;
  List<SPR>? sprList;

  bool _isScrolling = false;

  int currentRow = 2; // row pusat
  late List<String> barisTerpilih; // baris aktif : state
  final Map<String, GlobalKey> _treeKeys = {};

  int? _toRowNum(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;

    final direct = int.tryParse(v);
    if (direct != null) return direct;

    final asDouble = double.tryParse(v);
    if (asDouble != null) return asDouble.round();

    final m = RegExp(r'(\d+)').firstMatch(v);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  @override
  void initState() {
    super.initState();
    pohonFuture = PohonDao().getAllPohon();
    _loadPetugas();
    _loadSPR();
    //petugas = await PetugasDao().getPetugas();
    //petugas = PetugasDao().getPetugas();
    //AuditLogDao().createLog("REPOSISI", "Membuka Halaman Reposisi");
  }

  Future<void> _loadPetugas() async {
    petugas = await PetugasDao().getPetugas();

    if (petugas != null) {
      setState(() {
        divisi = petugas!.divisi;
        blok = petugas!.blok;
        pengguna = petugas!.akun;
      });
    }
  }

  Future<void> _loadSPR() async {
    spr = await SPRDao().getAllSPR();
    if (spr.isNotEmpty) {
      setState(() {
        sprList = spr;
      });
    }
  }

  /// ðŸŒ² Fungsi pembantu untuk mengelompokkan data pohon berdasarkan baris yang dipilih.
  Map<int, List<Pohon>> groupByBaris(
    List<Pohon> pohonData,
    List<String> barisTerpilih,
  ) {
    final Map<int, List<Pohon>> grouped = {};
    final selectedRows = barisTerpilih
        .map((e) => _toRowNum(e) ?? -1)
        .where((e) => e > 0)
        .toSet();

    for (var p in pohonData) {
      final baris = _toRowNum(p.nbaris) ?? 0;
      if (selectedRows.contains(baris)) {
        grouped.putIfAbsent(baris, () => []).add(p);
      }
    }

    // Urutkan berdasarkan nomor pohon menurun (dari besar ke kecil)
    for (var k in grouped.keys) {
      grouped[k]!.sort((a, b) {
        final na = int.tryParse(a.npohon.trim()) ?? 0;
        final nb = int.tryParse(b.npohon.trim()) ?? 0;
        //return nb.compareTo(na);
        return na.compareTo(nb);
      });
    }

    // Urutkan key baris naik (misal 11, 12, 13)
    final sortedKeys = grouped.keys.toList()..sort();
    return {for (var k in sortedKeys) k: grouped[k]!};
  }

  Map<String, String> hitungSPR(
    String blok,
    List<String> barisTerpilih,
    List<SPR> sprList,
  ) {
    final Map<String, String> hasil = {};
    final targetBlok = blok.trim().toLowerCase();

    for (final p in barisTerpilih) {
      final targetBaris = _toRowNum(p);
      if (targetBaris == null) continue;

      SPR? item;
      for (final element in sprList) {
        final baris = _toRowNum(element.nbaris);
        final blokEq = element.blok.trim().toLowerCase() == targetBlok;
        if (blokEq && baris == targetBaris) {
          item = element;
          break;
        }
      }

      if (item != null) {
        hasil[p] = '${item.sprAwal}/${item.sprAkhir}';
      } else {
        hasil[p] = '-';
      }
    }

    return hasil;
  }

  String? getSprAkhirByFilter(
    List<SPR> sprList,
    String targetBlok,
    String targetBaris,
  ) {
    try {
      // Mencari item pertama yang cocok
      final item = sprList.firstWhere(
        (element) =>
            element.blok == targetBlok && element.nbaris == targetBaris,
      );
      return item.sprAkhir;
    } catch (e) {
      // Mengembalikan null jika tidak ditemukan
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    //assignment = ModalRoute.of(context)!.settings.arguments as Assignment;
    //petugas = ModalRoute.of(context)!.settings.arguments as Petugas;
    _rebuildBarisTerpilih("CHANGE DEPENDENCIES");
    _loadSPR();
    //_scrollToTarget(currentRow.toString(), result);
  }

  void _rebuildBarisTerpilih(String sumberData) {
    //print("ARAH DARI BUTTON : $sumberData - CURRENT ROW: $currentRow");
    if (currentRow < 1) {
      currentRow = 2;
    } else if (currentRow == 1) {
      currentRow = 2;
    }

    barisTerpilih = [
      (currentRow - 1).toString(),
      currentRow.toString(),
      (currentRow + 1).toString(),
    ];
  }

  // 1. Definisikan fungsi tersendiri
  void _scrollToTarget(String baris, int pohonIndex) {
    setState(() => _isScrolling = true); // Tampilkan loading
    // bungkus dalam PostFrameCallback agar menunggu build selesai
    Future.delayed(const Duration(milliseconds: 300), () {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final String targetSlotKey = "$baris-$pohonIndex";
        final key = _treeKeys[targetSlotKey];

        //print("Mencoba Scroll ke: $targetSlotKey");

        if (key != null && key.currentContext != null) {
          Scrollable.ensureVisible(
            key.currentContext!,
            duration: const Duration(milliseconds: 600),
            // Sedikit lebih lambat agar berdampak halus
            alignment: 0.5, // Posisikan di tengah layar
          );

          // Tunggu sampai durasi scroll selesai (700ms) baru hilangkan loading
          Future.delayed(const Duration(milliseconds: 700), () {
            if (mounted) setState(() => _isScrolling = false);
          });
        } else {
          if (mounted) setState(() => _isScrolling = false);
          debugPrint("Gagal Scroll: Key tidak ditemukan atau Context null");
        }
      });
    });
  }

  // --- METODE BUILD UTAMA ---
  @override
  Widget build(BuildContext context) {
    // 1. Ambil data
    //Future <Petugas?> petugas = ModalRoute.of(context)!.settings.arguments as Petugas;
    //currentRow = int.parse(assignment.rowNumber);
    //int a = int.parse(assignment.rowNumber);

    return FutureBuilder<List<Pohon>>(
      future: pohonFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        //List<Pohon> pohonData = dummyPohonList;
        final pohonData = snapshot.data ?? [];

        //List<Pohon> pohonData = dummyPohonList;
        var grouped = groupByBaris(pohonData, barisTerpilih);

        // Jika jendela baris aktif menghasilkan kolom terlalu sedikit,
        // fallback ke 3 baris valid pertama dari data aktual.
        if (pohonData.isNotEmpty && grouped.keys.length < 2) {
          final sortedRows = pohonData
              .map((e) => _toRowNum(e.nbaris) ?? 0)
              .where((e) => e > 0)
              .toSet()
              .toList()
            ..sort();

          if (sortedRows.isNotEmpty) {
            final takeRows = sortedRows.take(3).toList();
            final fallbackRows = takeRows.map((e) => e.toString()).toList();
            grouped = groupByBaris(pohonData, fallbackRows);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                barisTerpilih = fallbackRows;
                currentRow = takeRows.length >= 2 ? takeRows[1] : takeRows.first;
              });
            });
          }
        }

        // 2. Cek status kosong
        if (grouped.isEmpty) {
          // Fallback: jika data pohon ada tapi 3 baris aktif saat ini tidak cocok,
          // pindahkan fokus ke baris valid terdekat agar layar tidak langsung "kosong".
          if (pohonData.isNotEmpty) {
            final sortedRows = pohonData
                .map((e) => int.tryParse(e.nbaris) ?? 0)
                .where((e) => e > 0)
                .toSet()
                .toList()
              ..sort();

            if (sortedRows.isNotEmpty) {
              final seedRow = sortedRows.first;
              final fallbackRows = [
                (seedRow - 1).toString(),
                seedRow.toString(),
                (seedRow + 1).toString(),
              ];
              grouped = groupByBaris(pohonData, fallbackRows);

              if (grouped.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (currentRow != seedRow) {
                    setState(() {
                      currentRow = seedRow;
                      barisTerpilih = fallbackRows;
                    });
                  }
                });
              }
            }
          }

          if (grouped.isEmpty) {
            return buildEmptyState();
          }
        }

        //final blok = petugas?.blok;
        //final barisMap = hitungJumlahPerBaris(pohonData, barisTerpilih, sprList!);
        final barisMap = hitungSPR(blok ?? '', barisTerpilih, sprList!);

        // 3. Hitung dimensi
        final barisKeys = grouped.keys.toList();
        //print("BARIS TERPILIH : $barisKeys");
        final maxLength = grouped.values
            .map((v) => v.length)
            .reduce((a, b) => a > b ? a : b);

        final screenWidth = MediaQuery.of(context).size.width;
        final double borderTotalWidth = barisKeys.length * 2.0;
        // Sesuaikan dengan jumlah baris yang ada
        final columnWidth =
            (screenWidth - 24 - borderTotalWidth) / barisKeys.length;

        //print("HALLO : $currentRow");
        //final String divisi = petugas.divisi;
        //final String blok = petugas.blok;
        //final String pengguna = petugas.akun;

        // 4. Bangun UI utama
        return Scaffold(
          //appBar: cfgAppBar('${assignment.division}/${assignment.block}', Colors.brown.shade900),
          appBar: cfgAppBar('$divisi/$blok', Colors.brown.shade900),
          body: Stack(
            children: [
              Padding(
                //padding: const EdgeInsets.all(12),
                padding: const EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: 0,
                  bottom: 2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Header Info Lokasi (dipisah ke fungsi)
                    buildHeaderInfo(
                      context,
                      onPrev: () {
                        setState(() {
                          currentRow--;
                          _rebuildBarisTerpilih("PREV BUTTON");
                          _loadSPR();
                        });
                      },
                      onRepo: () {
                        setState(() {
                          currentRow = 2;
                          _rebuildBarisTerpilih("REPOSISI BUTTON");
                          _loadSPR();
                        });
                      },
                      onNext: () {
                        setState(() {
                          currentRow++;
                          _rebuildBarisTerpilih("NEXT BUTTON");
                          _loadSPR();
                        });
                      },
                    ),
                    //buildPage(context),
                    const SizedBox(height: 2),
                    // Header baris (dipisah ke fungsi)
                    buildBarisHeader(
                      context,
                      barisKeys,
                      columnWidth,
                      blok ?? '',
                      pengguna ?? '',
                      barisMap: barisMap,
                      onRefresh: () {
                        setState(() {
                          _rebuildBarisTerpilih("SPR REFRESH BUTTON");
                          _loadSPR();
                        });
                      },
                    ),

                    // Pola Hexagonal (dipisah ke fungsi)
                    buildHexagonalTreeGrid(
                      context,
                      grouped,
                      barisKeys,
                      maxLength,
                      columnWidth,
                      pengguna ?? '',
                      blok ?? '',
                      treeKeys: _treeKeys,
                      //onChanged: () {
                      onChanged: (ReposisiResult result) {
                        setState(() {
                          // trigger rebuild
                          pohonFuture = PohonDao().getAllPohon();

                          //print("REFRESH REPOSISI $currentRow");
                          //print("ID Tanaman : ${result.idTanaman}");
                          //print("Baris Awal: ${result.barisAwal}");
                          //print("Flag: ${result.flag}");

                          _rebuildBarisTerpilih(
                            "ON CHANGED CALLBACK : Pohon Awal ${result.pohonAwal} -> Baris ${result.barisAwal}",
                          );

                          // ðŸ”¹ Scroll ke widget
                          _scrollToTarget(
                            currentRow.toString(),
                            result.pohonIndex,
                          );
                        });
                      }, // Onchanged
                    ), // BuildHexagonalTreeGrid
                  ],
                ),
              ),

              // Layer Loading Overlay
              if (_isScrolling)
                Container(
                  color: Colors.black, // Efek blur/transparan
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        //const Text("Menyelaraskan Posisi..."),
                        resText(
                          TextAlign.left,
                          "Tunggu..",
                          18,
                          FontStyle.normal,
                          true,
                          Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          //body:
        );
      },
    );
  }
}

// --- BUILD HEADER INFO WIDGET ---
Widget buildHeaderInfo(
  BuildContext context, {
  required VoidCallback onPrev,
  required VoidCallback onRepo,
  required VoidCallback onNext,
}) {
  // Style tombol yang berubah warna saat ditekan
  ButtonStyle customButtonStyle({bool isCenter = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.brown.shade50, // Warna dasar
      foregroundColor: Colors.brown.shade900, // Warna teks/ikon
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isCenter ? 4 : 8),
      ),
    ).copyWith(
      // LOGIKA PERUBAHAN WARNA SAAT DIKLIK
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.orange.shade300; // Warna kontras saat ditekan
        }
        return Colors.teal.shade800; // Warna kembali semula
      }),
    );
  }

  return Container(
    padding: const EdgeInsets.all(8),
    //width: double.infinity,
    height: 60,
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(0),
      border: Border(
        bottom: BorderSide(
          color: Colors.brown.shade800,
          width: 3.0, // atur ketebalan di sini
        ),
      ),
    ),
    child: Row(
      //crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        //const SizedBox(width: 8),
        // 1. TOMBOL PREV (<<)
        Expanded(
          flex: 1,
          child: ElevatedButton(
            style: customButtonStyle(),
            onPressed: onPrev,
            child: const Text(
              "<<",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25.0,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 2. TOMBOL REPOSISI (Tanpa Ikon)
        Expanded(
          flex: 2,
          child: ElevatedButton(
            style: customButtonStyle(isCenter: true),
            onPressed: onRepo,
            child: const Text(
              "POSISI AWAL",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16.0,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        // 3. TOMBOL NEXT (>>)
        Expanded(
          flex: 1,
          child: ElevatedButton(
            style: customButtonStyle(),
            onPressed: onNext,
            child: const Text(
              ">>",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 25.0,
              ),
            ),
          ),
        ),

        // GARIS DI BAWAH KONTEN
        const Divider(
          height: 1, // Jarak yang ditempati divider
          thickness: 2, // Tebal garis fisik
          color: Colors.black, // Warna garis
        ),
      ],
    ),
  );
}


