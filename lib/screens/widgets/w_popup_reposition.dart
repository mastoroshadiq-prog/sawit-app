// screens/widgets/w_popup_action.dart
import 'dart:async';

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
import '../../mvc_services/geo_audit_service.dart';
import '../../mvc_services/geo_photo_service.dart';
import '../../mvc_services/photo_crypto_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ReposisiResult?> showPopup(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  required int displayTreeNumber,
  bool? isVirtual,
}) {
  return showDialog<ReposisiResult>(
    context: context,
    builder: (dialogContext) => _buildPopupDialog(
      dialogContext,
      pohon,
      petugas,
      pohonIndex,
      displayTreeNumber: displayTreeNumber,
      isVirtual: isVirtual,
    ),
  );
}

class _PopupPresetStore {
  static const _kMode = 'popup_last_mode_v2';
  static const _kLabel = 'popup_last_label_v2';

  Future<void> save({
    required _PopupMode mode,
    required String label,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMode, mode.name);
    await prefs.setString(_kLabel, label);
  }

  Future<({
    _PopupMode? mode,
    String? label,
  })> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeName = prefs.getString(_kMode);
    final label = prefs.getString(_kLabel);

    _PopupMode? mode;
    for (final m in _PopupMode.values) {
      if (m.name == modeName) {
        mode = m;
        break;
      }
    }

    return (mode: mode, label: label);
  }
}

/// ⚙️ Widget Dialog Popup Aksi Pohon (Memisahkan dari popupDialog)
AlertDialog _buildPopupDialog(
  BuildContext context,
  Pohon pohon,
  String petugas,
  int pohonIndex, {
  required int displayTreeNumber,
  bool? isVirtual,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final dialogWidth = (screenWidth * 0.9).clamp(380.0, 560.0);
  return AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    // Atur batas tepi layar :
    insetPadding: const EdgeInsets.symmetric(horizontal: 16),
    title: Column(
      children: [
        _buildPopupTitle(
          displayTreeNumber.toString(),
          pohon.nbaris,
          pohon.status,
          pohon.objectId,
        ), // Dipisah
        const SizedBox(height: 12),
      ],
    ),
    //content: _buildPopupContent(context, assignment),
    content: SizedBox(
      width: dialogWidth,
      child: _buildPopupContent(
        context,
        pohon,
        petugas,
        pohonIndex,
        displayTreeNumber: displayTreeNumber,
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
  required int displayTreeNumber,
  bool? isVirtual,
}) {
  final presetStore = _PopupPresetStore();
  _PopupMode selectedMode = _PopupMode.koreksi;
  _TreeStatusOption? selectedKoreksiOption;
  final Set<String> selectedTemuanLabels = <String>{};
  XFile? photoFile;
  String? encryptedPhotoPath;

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
                        if (selectedMode == _PopupMode.koreksi) {
                          selectedKoreksiOption = op;
                        } else {
                          selectedTemuanLabels.add(op.label);
                        }
                        break;
                      }
                    }
                  }

                  final canUseTemuan = selectedKoreksiOption != null &&
                      selectedKoreksiOption!.label != 'KOSONG' &&
                      selectedKoreksiOption!.label != 'KENTHOS';
                  if (!canUseTemuan && selectedMode == _PopupMode.temuan) {
                    selectedMode = _PopupMode.koreksi;
                  }
                });
              },
              icon: const Icon(Icons.history, size: 16),
              label: const Text('Preset Terakhir'),
            ),
          ),
          const SizedBox(height: 10),
          if (selectedKoreksiOption != null &&
              (selectedKoreksiOption!.label == 'KOSONG' ||
                  selectedKoreksiOption!.label == 'KENTHOS'))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Temuan dinonaktifkan untuk koreksi KOSONG/KENTHOS.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('KOREKSI'),
                selected: selectedMode == _PopupMode.koreksi,
                onSelected: (_) => setState(() => selectedMode = _PopupMode.koreksi),
              ),
              const SizedBox(width: 10),
              ChoiceChip(
                label: const Text('TEMUAN'),
                selected: selectedMode == _PopupMode.temuan,
                onSelected: (_) {
                  final canUseTemuan = selectedKoreksiOption != null &&
                      selectedKoreksiOption!.label != 'KOSONG' &&
                      selectedKoreksiOption!.label != 'KENTHOS';
                  if (!canUseTemuan) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Pilih koreksi (selain KOSONG/KENTHOS) sebelum menambah temuan.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => selectedMode = _PopupMode.temuan);
                },
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
                    isSelected: selectedMode == _PopupMode.koreksi
                        ? selectedKoreksiOption?.label == option.label
                        : selectedTemuanLabels.contains(option.label),
                    onTap: () => setState(() {
                      if (selectedMode == _PopupMode.koreksi) {
                        selectedKoreksiOption = option;
                        final canUseTemuan = selectedKoreksiOption != null &&
                            selectedKoreksiOption!.label != 'KOSONG' &&
                            selectedKoreksiOption!.label != 'KENTHOS';
                        if (!canUseTemuan) {
                          selectedTemuanLabels.clear();
                          if (selectedMode == _PopupMode.temuan) {
                            selectedMode = _PopupMode.koreksi;
                          }
                        }
                      } else {
                        final canUseTemuan = selectedKoreksiOption != null &&
                            selectedKoreksiOption!.label != 'KOSONG' &&
                            selectedKoreksiOption!.label != 'KENTHOS';
                        if (!canUseTemuan) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Temuan tidak tersedia untuk KOSONG/KENTHOS.',
                              ),
                            ),
                          );
                          return;
                        }

                        if (selectedTemuanLabels.contains(option.label)) {
                          selectedTemuanLabels.remove(option.label);
                        } else {
                          selectedTemuanLabels.add(option.label);
                        }
                      }
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final shot = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 80,
                      maxWidth: 1920,
                    );
                    if (!context.mounted) return;
                    if (shot != null) {
                      final encrypted = await PhotoCryptoService()
                          .encryptFileAtRest(shot.path);
                      setState(() {
                        photoFile = shot;
                        encryptedPhotoPath = encrypted;
                      });
                    }
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Ambil Foto (Opsional)'),
                ),
                if (photoFile != null)
                  Text(
                    'Foto siap: ${photoFile!.name}',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (selectedKoreksiOption != null || selectedTemuanLabels.isNotEmpty)
            Text(
              'Pilihan: ${[
                if (selectedKoreksiOption != null) selectedKoreksiOption!.label,
                ...selectedTemuanLabels,
              ].join(', ')}',
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
                  if (selectedKoreksiOption == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pilih koreksi terlebih dahulu.'),
                      ),
                    );
                    return;
                  }

                  final canUseTemuan = selectedKoreksiOption != null &&
                      selectedKoreksiOption!.label != 'KOSONG' &&
                      selectedKoreksiOption!.label != 'KENTHOS';
                  if (!canUseTemuan && selectedTemuanLabels.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Temuan tidak boleh dipilih untuk KOSONG/KENTHOS.'),
                      ),
                    );
                    return;
                  }

                  final primaryOption = selectedKoreksiOption!;
                  final combinedLabels = <String>[
                    selectedKoreksiOption!.label,
                    ...selectedTemuanLabels,
                  ];

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Konfirmasi Simpan'),
                      content: Text('Yakin simpan perubahan "${combinedLabels.join(', ')}"?'),
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

                  if (context.mounted) {
                    showDialog<void>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  try {
                    await presetStore.save(
                      mode: selectedMode,
                      label: selectedMode == _PopupMode.koreksi
                          ? primaryOption.label
                          : (selectedTemuanLabels.isNotEmpty
                              ? selectedTemuanLabels.first
                              : primaryOption.label),
                    );

                    final result = await _syncPlantReposition(
                      pohon.blok,
                      pohonIndex,
                      primaryOption.label,
                      pohon.objectId,
                      pohon.npohon,
                      pohon.nbaris,
                      petugas,
                      primaryOption.isVirtual,
                      attributeLabels: combinedLabels,
                      displayPohon: displayTreeNumber.toString(),
                    );

                    unawaited(
                      GeoAuditService().captureAndQueueReposisiEvent(
                        userId: petugas,
                        blok: pohon.blok,
                        idTanaman: pohon.objectId,
                        idReposisi: result.idReposisi,
                        actionLabel: combinedLabels.join('+'),
                        rowNumber: pohon.nbaris,
                        treeNumber: pohon.npohon,
                      ),
                    );

                    if (photoFile != null) {
                      unawaited(
                        GeoPhotoService().captureAndQueuePhoto(
                          userId: petugas,
                          blok: pohon.blok,
                          idTanaman: pohon.objectId,
                          idReposisi: result.idReposisi,
                          actionLabel: combinedLabels.join('+'),
                          rowNumber: pohon.nbaris,
                          treeNumber: pohon.npohon,
                          localPath: encryptedPhotoPath ?? photoFile!.path,
                        ),
                      );
                    }

                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                      Navigator.pop(context, result);
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.of(context, rootNavigator: true).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal simpan: $e')),
                      );
                    }
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
      _TreeStatusOption(
        label: 'SISIPAN',
        iconPath: 'assets/icons/palm.png',
        borderColor: Colors.red,
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
              child: Center(
                child: label == 'SISIPAN'
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          cfgImageAsset('assets/icons/palm.png', 60, 60),
                          Positioned(
                            bottom: 4,
                            right: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : cfgImageAsset(iconPath, 60, 60),
              ),
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
  List<String> attributeLabels = const <String>[],
  String? displayPohon,
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
    case 'SISIPAN':
      strKet = 'SISIPAN';
      tipeRiwayat = 'S';
      nFlag = '0';
      break;
  }

  final hasGanoderma = attributeLabels.contains('G');
  final hasSisipan = attributeLabels.contains('SISIPAN');

  if (hasGanoderma && hasSisipan) {
    if (nFlag == '1') {
      nFlag = '13'; // G + SISIPAN + MIRING KANAN
    } else if (nFlag == '2') {
      nFlag = '14'; // G + SISIPAN + MIRING KIRI
    } else if (nFlag == '0') {
      nFlag = '15'; // G + SISIPAN + TEGAK
    } else {
      nFlag = '15';
    }
  } else if (hasGanoderma) {
    if (nFlag == '1') {
      nFlag = '6'; // G + MIRING KANAN
    } else if (nFlag == '2') {
      nFlag = '7'; // G + MIRING KIRI
    } else if (nFlag == '0') {
      nFlag = '8'; // G + TEGAK/SISIPAN
    } else if (nFlag != '5') {
      nFlag = '5';
    }
  }

  // SISIPAN tetap dicatat sebagai atribut.
  // Untuk visual nflag, ketika bersamaan dengan G, prioritas visual tetap ke status G.
  if (hasSisipan && !hasGanoderma) {
    if (nFlag == '1') {
      nFlag = '10'; // SISIPAN + MIRING KANAN
    } else if (nFlag == '2') {
      nFlag = '11'; // SISIPAN + MIRING KIRI
    } else if (nFlag == '0') {
      nFlag = '12'; // SISIPAN + TEGAK
    }
  }

  bool isHasil;
  final uuid = Uuid().v4();
  final generatedReposisiId = '${uuid.toUpperCase()}-$blok';
  final reposisi = Reposisi(
    idReposisi: generatedReposisiId, // ID akan di-generate otomatis
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

    if (attributeLabels.isNotEmpty) {
      final nowIsoAttr = DateTime.now().toIso8601String();
      for (final item in attributeLabels.toSet()) {
        final observasiAttr = ObservasiTambahan(
          idObservasi: '${const Uuid().v4().toUpperCase()}-$blok',
          idTanaman: idTanaman,
          blok: blok,
          baris: barisAwal,
          pohon: pohonAwal,
          kategori: 'ATRIBUT',
          detail: item,
          catatan: observasiNote,
          petugas: strPetugas,
          createdAt: nowIsoAttr,
          flag: 0,
        );
        await ObservasiTambahanDao().insertObservasi(observasiAttr);
      }
    }

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
      if (['0', '3', '4', '5', '6', '7', '8', '10', '11', '12', '13', '14', '15']
          .contains(nFlag)) {
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
        blok,
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
    idReposisi: generatedReposisiId,
    idTanaman: idTanaman,
    message:
        'Pohon ${displayPohon ?? pohonAwal} di baris $barisAwal telah berhasil ditandai.',
    flag: nFlag,
    barisAwal: barisAwal,
    pohonAwal: pohonAwal,
    success: isHasil,
    pohonIndex: pohonIndex,
  );
}

