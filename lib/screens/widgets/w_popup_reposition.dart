// screens/widgets/w_popup_action.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kebun_sawit/mvc_dao/dao_pohon.dart';
import '../../mvc_dao/dao_reposisi.dart';
import '../../mvc_dao/dao_observasi_tambahan.dart';
import '../../mvc_models/reposisi.dart';
import '../../mvc_models/observasi_tambahan.dart';
import 'package:uuid/uuid.dart';
import '../../mvc_dao/dao_audit_log.dart';
import '../scr_models/reposition_result.dart';
import 'w_general.dart';
import '../../mvc_models/pohon.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ReposisiResult?> showPopup(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  bool? isVirtual,
}) {
  return showDialog<ReposisiResult>(
    context: context,
    builder: (dialogContext) => _buildPopupDialog(
      dialogContext,
      pohon,
      petugas,
      pohonIndex,
      isVirtual: isVirtual,
    ),
  );
}

class _PopupPresetStore {
  static const _kMode = 'popup_last_mode_v1';
  static const _kLabel = 'popup_last_label_v1';
  static const _kObservasi = 'popup_last_observasi_v1';

  Future<void> save({
    required _PopupMode mode,
    required String label,
    required List<String> observasi,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode.name);
    await prefs.setString(_kLabel, label);
    await prefs.setString(_kObservasi, jsonEncode(observasi));
  }

  Future<({
    _PopupMode? mode,
    String? label,
    List<String> observasi,
  })> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_kMode);
    final label = prefs.getString(_kLabel);
    final rawObservasi = prefs.getString(_kObservasi);

    _PopupMode? mode;
    for (final m in _PopupMode.values) {
      if (m.name == modeName) {
        mode = m;
        break;
      }
    }

    List<String> observasi = const [];
    if (rawObservasi != null && rawObservasi.isNotEmpty) {
      final decoded = jsonDecode(rawObservasi);
      if (decoded is List) {
        observasi = decoded.map((e) => e.toString()).toList();
      }
    }

    return (mode: mode, label: label, observasi: observasi);
  }
}

/// ⚙️ Widget Dialog Popup Aksi Pohon (Memisahkan dari popupDialog)
AlertDialog _buildPopupDialog(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  bool? isVirtual,
}) {
  return AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    // Atur batas tepi layar :
    insetPadding: const EdgeInsets.symmetric(horizontal: 40),
    title: Column(
      children: [
        _buildPopupTitle(
          pohon.npohon,
          pohon.nbaris,
          pohon.status,
          pohon.objectId,
        ), // Dipisah
        const SizedBox(height: 12),
      ],
    ),
    //content: _buildPopupContent(context, assignment),
    content: SizedBox(
      width: 350, // 🔥 lebar dialog diatur di sini
      child: _buildPopupContent(
        context,
        pohon,
        petugas,
        pohonIndex,
        isVirtual: isVirtual,
      ),
    ),
  );
}

/// 📝 Bagian Judul Popup Dialog
Widget _buildPopupTitle(
  String npohon,
  String nbaris,
  String pStatus,
  String objectId,
) {
  //int a = int.parse(pohon.status) - 1;
  int a = int.parse(pStatus) - 1;
  return Column(
    children: [
      ResText(
        'Pohon $npohon / Baris $nbaris',
        25.0,
        FontStyle.normal,
        true,
        Colors.green.shade900,
      ),
      ResText(
        'Status: ${a.toString()} / OBJECTID: $objectId',
        15.0,
        FontStyle.normal,
        true,
        Colors.green.shade900,
      ),
    ],
  );
}

/// 📃 Bagian Konten Aksi (list prop A, B, C) di Popup Dialog
SingleChildScrollView _buildPopupContent(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  bool? isVirtual,
}) {
  final presetStore = _PopupPresetStore();
  _PopupMode selectedMode = _PopupMode.koreksi;
  _TreeStatusOption? selectedOption;
  final Set<String> selectedObservasi = <String>{};
  final TextEditingController catatanController = TextEditingController();

  return SingleChildScrollView(
    child: StatefulBuilder(
      builder: (context, setState) => Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final preset = await presetStore.load();
                if (!context.mounted) return;

                setState(() {
                  if (preset.mode != null) {
                    selectedMode = preset.mode!;
                  }
                  selectedOption = null;
                  final options = _buildTreeStatusOptions(
                    selectedMode,
                    pohon,
                    petugas,
                    pohonIndex,
                    isVirtual: isVirtual ?? false,
                  );
                  if (preset.label != null) {
                    for (final op in options) {
                      if (op.label == preset.label) {
                        selectedOption = op;
                        break;
                      }
                    }
                  }

                  selectedObservasi
                    ..clear()
                    ..addAll(preset.observasi);
                });
              },
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Preset Terakhir'),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('KOREKSI'),
                selected: selectedMode == _PopupMode.koreksi,
                onSelected: (_) => setState(() {
                  selectedMode = _PopupMode.koreksi;
                  selectedOption = null;
                }),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('TEMUAN (G)'),
                selected: selectedMode == _PopupMode.temuan,
                onSelected: (_) => setState(() {
                  selectedMode = _PopupMode.temuan;
                  selectedOption = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          cfgWrap(
            WrapAlignment.center,
            _buildTreeStatusOptions(
              selectedMode,
              pohon,
              petugas,
              pohonIndex,
              isVirtual: isVirtual ?? false,
            )
                .map(
                  (option) => _buildSelectableTreeStatusButton(
                    label: option.label,
                    iconPath: option.iconPath,
                    borderColor: option.borderColor,
                    isSelected: selectedOption?.label == option.label,
                    onTap: () => setState(() => selectedOption = option),
                  ),
                )
                .toList(),
          ),
          if (selectedMode == _PopupMode.temuan) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Observasi Tambahan (Vegetatif):',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _observasiVegetatifOptions.map((item) {
                final selected = selectedObservasi.contains(item);
                return FilterChip(
                  label: Text(item),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        selectedObservasi.add(item);
                      } else {
                        selectedObservasi.remove(item);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: catatanController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Catatan Observasi (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (selectedOption != null)
            Text(
              'Pilihan: ${selectedOption!.label}',
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              cfgElevatedButton(
                Colors.blueAccent.shade700,
                Colors.black,
                0,
                0,
                5.0,
                cfgPadding(
                  24.0,
                  8.0,
                  resText(
                    TextAlign.left,
                    'Simpan',
                    16,
                    FontStyle.normal,
                    true,
                    Colors.white,
                  ),
                ),
                () async {
                  if (selectedOption == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih status terlebih dahulu.'),
                      ),
                    );
                    return;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Konfirmasi Simpan'),
                      content: Text('Yakin simpan perubahan "${selectedOption!.label}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Tidak'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Ya'),
                        ),
                      ],
                    ),
                  );

                  if (confirm != true) {
                    return;
                  }

                  await presetStore.save(
                    mode: selectedMode,
                    label: selectedOption!.label,
                    observasi: selectedObservasi.toList(),
                  );

                  final result = await _syncPlantReposition(
                    pohon.blok,
                    pohonIndex,
                    selectedOption!.label,
                    pohon.objectId,
                    pohon.npohon,
                    pohon.nbaris,
                    petugas,
                    selectedOption!.isVirtual,
                    observasiLabels: selectedObservasi.toList(),
                    observasiNote: catatanController.text.trim(),
                    simpanObservasi: selectedMode == _PopupMode.temuan,
                  );

                  if (context.mounted) {
                    Navigator.pop(context, result);
                  }
                },
              ),
              const SizedBox(width: 20),
              cfgElevatedButton(
                Colors.green.shade800,
                Colors.black,
                0,
                0,
                5.0,
                cfgPadding(
                  24.0,
                  8.0,
                  resText(
                    TextAlign.left,
                    'Batal',
                    16,
                    FontStyle.normal,
                    true,
                    Colors.white,
                  ),
                ),
                () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

List<_TreeStatusOption> _buildTreeStatusOptions(
  _PopupMode mode,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  required bool isVirtual,
}) {
  // parameter tetap dipertahankan untuk kompatibilitas signature pemanggilan
  // ignore: unused_local_variable
  final _ = (pohon, petugas, pohonIndex);

  if (mode == _PopupMode.temuan) {
    return [
      _TreeStatusOption(
        label: 'G',
        iconPath: 'assets/icons/infek-gano.png',
        borderColor: Colors.deepOrange,
        isVirtual: isVirtual,
      ),
    ];
  }

  return [
    _TreeStatusOption(
      label: 'MIRING\nKIRI',
      iconPath: 'assets/icons/miring-kiri.png',
      borderColor: Colors.purple,
      isVirtual: isVirtual,
    ),
    _TreeStatusOption(
      label: 'MIRING\nKANAN',
      iconPath: 'assets/icons/miring-kanan.png',
      borderColor: Colors.blue,
      isVirtual: isVirtual,
    ),
    _TreeStatusOption(
      label: 'TEGAK',
      iconPath: 'assets/icons/normal.png',
      borderColor: Colors.green,
      isVirtual: isVirtual,
    ),
    _TreeStatusOption(
      label: 'KOSONG',
      iconPath: 'assets/icons/ditebang.png',
      borderColor: Colors.brown,
      isVirtual: isVirtual,
    ),
    _TreeStatusOption(
      label: 'KENTHOS',
      iconPath: 'assets/icons/kenthosan.png',
      borderColor: Colors.orange,
      isVirtual: isVirtual,
    ),
  ];
}

enum _PopupMode { koreksi, temuan }

Widget _buildSelectableTreeStatusButton({
  required String label,
  required String iconPath,
  required Color borderColor,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      InkWell(
        onTap: onTap,

        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(2),
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? Colors.green.shade700 : borderColor,
                  width: isSelected ? 4 : 2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.green.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(child: cfgImageAsset(iconPath, 60, 60)),
            ),
            const SizedBox(height: 10),
            resText(
              TextAlign.center,
              label,
              18.0,
              FontStyle.normal,
              true,
              Colors.black,
            ),
          ],
        ),
      ),
    ],
  );
}

class _TreeStatusOption {
  const _TreeStatusOption({
    required this.label,
    required this.iconPath,
    required this.borderColor,
    required this.isVirtual,
  });

  final String label;
  final String iconPath;
  final Color borderColor;
  final bool isVirtual;
}

Future<ReposisiResult> _syncPlantReposition(
  String blok,
  int pohonIndex,
  String label,
  String idTanaman,
  String pohonAwal,
  String barisAwal,
  String strPetugas,
  bool isVirtual,
  {List<String> observasiLabels = const <String>[],
  String observasiNote = '',
  bool simpanObservasi = false,
  }
) async {
  String pohonTujuan =
      pohonAwal; // Untuk reposisi, pohon tujuan sama dengan pohon awal
  String barisTujuan = barisAwal; // Untuk reposisi, baris
  String strKet = 'Normal';
  String tipeRiwayat = 'N';
  String nFlag = '0';
  switch (label) {
    case 'TEGAK':
      //barisTujuan = (int.parse(barisAwal) - 1).toString();
      strKet = 'TEGAK';
      tipeRiwayat = 'N';
      nFlag = '0';
      break;
    case 'MIRING\nKANAN':
      barisTujuan = (int.parse(barisAwal) + 1).toString();
      strKet = 'MIRING KANAN';
      tipeRiwayat = 'R';
      nFlag = '1';
      break;
    case 'MIRING\nKIRI':
      barisTujuan = (int.parse(barisAwal) - 1).toString();
      strKet = 'MIRING KIRI';
      tipeRiwayat = 'L';
      nFlag = '2';
      break;
    case 'KENTHOS':
      strKet = 'KENTHOS';
      tipeRiwayat = 'K';
      nFlag = '3';
      break;
    case 'KOSONG':
      strKet = 'KOSONG';
      tipeRiwayat = 'C';
      nFlag = '4';
      break;
    case 'G':
      strKet = 'GANODERMA';
      tipeRiwayat = 'G';
      nFlag = '5';
      break;
  }

  bool isHasil;
  final uuid = Uuid().v4();
  final reposisi = Reposisi(
    idReposisi: '${uuid.toUpperCase()}-$blok', // ID akan di-generate otomatis
    idTanaman: idTanaman, // Isi dengan ID pohon yang sesuai
    pohonAwal: pohonAwal, // Isi dengan pohon awal
    barisAwal: barisTujuan, // Isi dengan baris awal
    pohonTujuan: pohonTujuan, // Isi dengan pohon tujuan
    barisTujuan: barisAwal, // Isi dengan baris tujuan
    keterangan: strKet, // Isi dengan keterangan jika ada
    petugas: strPetugas, // Isi dengan nama petugas
    tipeRiwayat: tipeRiwayat,
    flag: 0,
    blok: blok,
    createdAt: DateTime.now().toIso8601String(),
  );

  // Simpan data kesehatan ke database
  final hasil = await ReposisiDao().insertReposisi(reposisi);
  if (hasil > 0) {
    // insert berhasil
    await AuditLogDao().createLog(
      "INSERT_REPOSISI",
      "Berhasil Melakukan Reposisi Pohon ID: $idTanaman-$strKet",
    );

    if (simpanObservasi && observasiLabels.isNotEmpty) {
      final nowIso = DateTime.now().toIso8601String();
      for (final item in observasiLabels) {
        final observasi = ObservasiTambahan(
          idObservasi: '${const Uuid().v4().toUpperCase()}-$blok',
          idTanaman: idTanaman,
          blok: blok,
          baris: barisAwal,
          pohon: pohonAwal,
          kategori: 'VEGETATIF',
          detail: item,
          catatan: observasiNote,
          petugas: strPetugas,
          createdAt: nowIso,
          flag: 0,
        );
        await ObservasiTambahanDao().insertObservasi(observasi);
      }

      await AuditLogDao().createLog(
        'INSERT_OBSERVASI',
        'Berhasil Menyimpan ${observasiLabels.length} observasi tambahan pohon ID: $idTanaman',
      );
    }

    if (isVirtual) {
      if (['0', '3', '4', '5', '6', '7', '8'].contains(nFlag)) {
        final pohon = Pohon(
          blok: blok,
          nbaris: barisTujuan,
          npohon: pohonAwal,
          objectId: idTanaman,
          status: "1",
          nflag: nFlag,
        );
        await PohonDao().insertPohon(pohon);
      } else {
        await PohonDao().updateStatusPohon(
          barisTujuan,
          nFlag,
          pohonAwal,
          barisAwal,
        );
      }
    } else if (!isVirtual) {
      await PohonDao().updateStatusPohonByObjectId(
        idTanaman,
        nFlag,
        pohonAwal,
        barisAwal,
      );
    }
    //print("Berhasil : Tutup Pop UP");
    isHasil = true;
  } else {
    // insert gagal
    //print("Insert gagal");
    await AuditLogDao().createLog(
      "INSERT_REPOSISI",
      "Gagal Melakukan Reposisi Pohon ID: $idTanaman-$strKet",
    );
    //print("Gagal : Tutup Pop UP");
    isHasil = false;
  }
  return ReposisiResult(
    idTanaman: idTanaman,
    message: '',
    flag: nFlag,
    barisAwal: barisAwal,
    pohonAwal: pohonAwal,
    success: isHasil,
    pohonIndex: pohonIndex,
  );
}

const List<String> _observasiVegetatifOptions = [
  'Kurang unsur hara',
  'Kondisi gambut',
  'Defisiensi air',
  'Serangan hama',
  'Indikasi penyakit daun',
  'Pertumbuhan terhambat',
];
