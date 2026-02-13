// screens/widgets/w_reposition.dart

import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr.dart';
import 'package:kebun_sawit/mvc_dao/dao_spr_log.dart';
import 'package:uuid/uuid.dart';
import '../../mvc_models/spr.dart';
import '../../mvc_models/spr_log.dart';
import '../scr_models/reposition_result.dart';
import 'w_general.dart';
import 'w_popup_reposition.dart';
import '../../mvc_models/pohon.dart';

// --- WIDGET PEMBANTU UNTUK UI UTAMA (Dipisah dari build) ---
/// Widget utama untuk header lokasi (menggunakan fungsi dari config).
Container buildHeaderInfo(String teks) {
  return cfgContainer(
    double.infinity,
    0,
    15.0,
    20,
    cfgBoxDecoration(Colors.brown.shade100, 8.0, Colors.brown.shade800),
    Alignment.center,
    resText(TextAlign.left, teks, 16.0, FontStyle.normal, true, Colors.black),
  );
}

/// ðŸ—ºï¸ Widget untuk menampilkan pesan jika data kosong.
Widget buildEmptyState() {
  return Scaffold(
    appBar: AppBar(title: const Text('Peta Pohon')),
    body: const Center(child: Text('Tidak ada baris yang cocok.')),
  );
}

/// ðŸŒ³ Widget untuk menampilkan header baris (label Baris X).
Widget buildBarisHeader(
  BuildContext context,
  List<int> barisKeys,
  double columnWidth,
  String blok,
  String petugas, {
  Map<String, String>? barisMap,
  VoidCallback? onRefresh,
}) {
  return Row(
    children: barisKeys.map((b) {
      String jml = barisMap?[b.toString()] ?? '-';
      String nbaris = b.toString();
      return Container(
        width: columnWidth - 6,
        alignment: Alignment.center,
        margin: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFEFD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCEBE6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            buildCountSPR(
              context,
              jml,
              const Color(0xFFE6D6CE),
              0,
              blok,
              nbaris,
              petugas,
              onRefresh,
            ),
            const SizedBox(height: 5),
            buildCount('Baris $b', const Color(0xFFDDF2E6), 4.0),
          ],
        ),
      );
    }).toList(),
  );
}

Widget buildCount(String strTeks, Color clrBackground, double dbVer) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [clrBackground, const Color(0xFFCDE8DA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFBEDCCD)),
    ),
    padding: EdgeInsets.symmetric(vertical: dbVer, horizontal: 8),
    child: resText(
      TextAlign.center,
      strTeks,
      18.0,
      FontStyle.normal,
      true,
      const Color(0xFF1F6A5A),
    ),
  );
}

Widget buildCountSPR(
  BuildContext context,
  String strTeks,
  Color clrBackground,
  double dbVer,
  String blok,
  String nbaris,
  String petugas,
  VoidCallback? onRefresh,
) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        _showEditDialog(context, strTeks, blok, nbaris, petugas, onRefresh);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [clrBackground, const Color(0xFFD7C0B4)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFC9AFA2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.forest_rounded,
              size: 14,
              color: Color(0xFF5B3E35),
            ),
            const SizedBox(width: 4),
            Text(
              strTeks,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5B3E35),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _showEditDialog(
  BuildContext context,
  String strTeks,
  String blok,
  String baris,
  String petugas,
  VoidCallback? onRefresh,
) async {
  // ambil angka setelah "/"
  List<String> parts = strTeks.split("/");
  String angkaDepan = parts[0]; // "23"
  String angkaBelakang = parts[1]; // "25"

  TextEditingController controller = TextEditingController(text: angkaBelakang);

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Jumlah Pohon di Baris $baris"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: "Jumlah terkini"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              final uuid = Uuid().v4();
              String teks = controller.text;
              SPR spr = SPR(
                idSPR: uuid.toUpperCase(),
                blok: blok,
                nbaris: baris,
                sprAwal: angkaDepan,
                sprAkhir: teks,
                keterangan: 'Update dari dialog',
                petugas: petugas,
                flag: 0,
              );

              SPRLog sprLog = SPRLog(
                idLog: uuid.toUpperCase(),
                blok: blok,
                nbaris: baris,
                sprAwal: angkaDepan,
                sprAkhir: teks,
                keterangan: '-',
                petugas: petugas,
                flag: 0,
              );
              await SPRDao().sprTerkini(spr);
              await SPRLogDao().insertSPR(sprLog);

              // Check if widget is still mounted before using context
              if (context.mounted) {
                Navigator.pop(context);
              }

              if (onRefresh != null) onRefresh();
            },
            child: Text("OK"),
          ),
        ],
      );
    },
  );
}

/// ðŸŒ¿ Widget untuk menampilkan pola pohon heksagonal dalam ScrollView.
//=================================================================
Widget buildHexagonalTreeGrid(
  BuildContext context,
  Map<int, List<Pohon>> grouped,
  List<int> barisKeys,
  int maxLength,
  double columnWidth,
  String petugas,
  String blok, {
  required Map<String, GlobalKey> treeKeys,
  required void Function(ReposisiResult result) onChanged,
}) {
  return Expanded(
    child: Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(barisKeys.length, (index) {
            final baris = barisKeys[index];
            final pohonList = grouped[baris] ?? [];

            // 1. TENTUKAN TARGET SLOT: Minimal 25 atau sesuai jumlah data asli
            // Kita menggunakan urutan list, bukan ID pohon lagi.
            final int targetSlots = pohonList.length < 32
                ? 32
                : pohonList.length;

            // 2. BUAT MAP BERDASARKAN INDEKS (0, 1, 2...)
            final Map<int, Pohon> pohonMap = {
              for (int i = 0; i < pohonList.length; i++) i: pohonList[i],
            };

            final bool startWithTree = baris.isOdd;

            return Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.green.shade500, width: 2),
                ),
              ),
              child: SizedBox(
                width: columnWidth,
                child: Column(
                  children: List.generate(targetSlots * 2, (i) {
                    final bool isTreeSlot = startWithTree ? i.isEven : i.isOdd;
                    final int pohonIndex = i ~/ 2; // Menghasilkan 0, 1, 2...

                    // Koordinat unik untuk auto-scroll
                    final String slotKey = "$baris-$pohonIndex";
                    treeKeys.putIfAbsent(slotKey, () => GlobalKey());

                    // A. JIKA SLOT KOSONG (SPACER HEKSAGONAL)
                    if (!isTreeSlot) {
                      return _buildEmptyTree();
                    }

                    // B. PROSES SLOT POHON (IF-ELSE INDEKS)
                    if (pohonMap.containsKey(pohonIndex)) {
                      // --- POHON NYATA ---
                      final pohon = pohonMap[pohonIndex]!;

                      // finalNumber sekarang murni berdasarkan urutan visual (1, 2, 3...)
                      // Jika ingin menampilkan nomor asli di label, gunakan int.tryParse(pohon.npohon)
                      int finalLabelNumber = pohonIndex + 1;

                      return _buildTreeButton(
                        context,
                        pohon,
                        petugas,
                        pohonIndex,
                        onChanged,
                        finalLabelNumber, // Angka yang muncul di layar
                        key: treeKeys[slotKey],
                        isVirtual: false,
                      );
                    } else {
                      // --- POHON VIRTUAL ---
                      // Terjadi jika pohonIndex > pohonList.length
                      int finalLabelNumber = pohonIndex + 1;

                      final virtual = Pohon.virtual(
                        blok,
                        baris,
                        finalLabelNumber,
                      );

                      return _buildTreeButton(
                        context,
                        virtual,
                        petugas,
                        pohonIndex,
                        onChanged,
                        finalLabelNumber,
                        key: treeKeys[slotKey],
                        isVirtual: true,
                      );
                    }
                  }),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
//=================================================================

/// POHON AKTIF: ikon di dalam lingkaran, label nomor di bawah
Widget _buildTreeButton(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex,
  void Function(ReposisiResult result) onChanged,
  int nomor, {
  Key? key,
  bool? isVirtual = false,
}) {
  //int a = int.parse(pohon.status) - 1;
  //String labelPohon = pohon.npohon;
  //String labelPohon = nomor.toString();
  String labelPohon = '${pohonIndex + 1}/${nomor.toString()}';
  String iconPath = 'assets/icons/normal.png';
  String? overlayIconPath;
  String? overlayText;
  Color overlayBorderColor = Colors.red;
  Color overlayTextBadgeColor = Colors.black;
  double overlayIconSize = 30;
  double overlayBadgeSize = 44;
  Color color = Colors.green.shade50; // default
  Color borderColor = Colors.green.shade400;

  if (pohon.nflag == '0') {
    iconPath = 'assets/icons/normal.png';
  } else if (pohon.nflag == '1') {
    iconPath = 'assets/icons/miring-kanan.png';
  } else if (pohon.nflag == '2') {
    iconPath = 'assets/icons/miring-kiri.png';
  } else if (pohon.nflag == '3') {
    iconPath = 'assets/icons/kenthosan.png';
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '4') {
    iconPath = 'assets/icons/ditebang.png';
  } else if (pohon.nflag == '5') {
    iconPath = 'assets/icons/infek-gano.png';
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '6') {
    iconPath = 'assets/icons/miring-kanan.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = null;
    overlayBorderColor = Colors.red.shade500;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '7') {
    iconPath = 'assets/icons/miring-kiri.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = null;
    overlayBorderColor = Colors.red.shade500;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '8') {
    iconPath = 'assets/icons/normal.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = null;
    overlayBorderColor = Colors.red.shade500;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '10') {
    iconPath = 'assets/icons/miring-kanan.png';
    overlayIconPath = 'assets/icons/palm.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    overlayIconSize = 34;
    overlayBadgeSize = 52;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '11') {
    iconPath = 'assets/icons/miring-kiri.png';
    overlayIconPath = 'assets/icons/palm.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    overlayIconSize = 34;
    overlayBadgeSize = 52;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '12') {
    iconPath = 'assets/icons/normal.png';
    overlayIconPath = 'assets/icons/palm.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    overlayIconSize = 34;
    overlayBadgeSize = 52;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '13') {
    iconPath = 'assets/icons/miring-kanan.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '14') {
    iconPath = 'assets/icons/miring-kiri.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '15') {
    iconPath = 'assets/icons/normal.png';
    overlayIconPath = 'assets/icons/infek-gano.png';
    overlayText = 'S';
    overlayBorderColor = Colors.red.shade500;
    overlayTextBadgeColor = Colors.red.shade600;
    color = Colors.red.shade50;
    borderColor = Colors.red.shade500;
  } else if (pohon.nflag == '9') {
    iconPath = 'assets/icons/kosong.png';
  }

  const double buttonSize = 90;
  final double iconSize = buttonSize * 0.8;

  return GestureDetector(
    key: key, // <-- key implementation
    onTap: () async {
      final ReposisiResult? result = await showPopup(
        context,
        pohon,
        petugas,
        pohonIndex,
        isVirtual: isVirtual ?? false,
      );
      if (result != null && result.success) {
        onChanged(result); // â¬… kirim data ke parent
      }
    },
    child: Container(
      padding: const EdgeInsets.all(0),
      margin: const EdgeInsets.all(0),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 4, right: 4, top: 0, bottom: 0),
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: borderColor, width: 3),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(child: cfgImageAsset(iconPath, iconSize, iconSize)),
                if (overlayIconPath != null)
                  Positioned(
                    left: 2,
                    top: 4,
                    child: Container(
                      width: overlayBadgeSize,
                      height: overlayBadgeSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: overlayBorderColor, width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(child: cfgImageAsset(overlayIconPath, overlayIconSize, overlayIconSize)),
                          if (overlayText != null)
                            Positioned(
                              bottom: 1,
                              right: 2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: overlayTextBadgeColor.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  overlayText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 0),
          resText(
            TextAlign.left,
            labelPohon,
            18,
            FontStyle.normal,
            true,
            Colors.black,
          ),
        ],
      ),
    ),
    //child:
  );
}

/// POHON KOSONG: X di tengah, label "-" di bawah
Widget _buildEmptyTree() {
  return Column(
    children: [
      Container(
        margin: const EdgeInsets.all(4),
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          //border: Border.all(color: Colors.grey.shade400, width: 3),
          border: Border.all(color: Colors.transparent, width: 3),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ResText(' ', 40, FontStyle.normal, false, Colors.grey),
      ),
      const SizedBox(height: 4),
      ResText(' ', 18, FontStyle.normal, true, Colors.black),
    ],
  );
}

