class ObservasiTambahan {
  final String idObservasi;
  final String idTanaman;
  final String blok;
  final String baris;
  final String pohon;
  final String kategori;
  final String detail;
  final String catatan;
  final String petugas;
  final String createdAt;
  final int flag;

  ObservasiTambahan({
    required this.idObservasi,
    required this.idTanaman,
    required this.blok,
    required this.baris,
    required this.pohon,
    required this.kategori,
    required this.detail,
    required this.catatan,
    required this.petugas,
    required this.createdAt,
    required this.flag,
  });

  Map<String, dynamic> toMap() {
    return {
      'idObservasi': idObservasi,
      'idTanaman': idTanaman,
      'blok': blok,
      'baris': baris,
      'pohon': pohon,
      'kategori': kategori,
      'detail': detail,
      'catatan': catatan,
      'petugas': petugas,
      'createdAt': createdAt,
      'flag': flag,
    };
  }

  factory ObservasiTambahan.fromMap(Map<String, dynamic> map) {
    return ObservasiTambahan(
      idObservasi: map['idObservasi'] ?? '',
      idTanaman: map['idTanaman'] ?? '',
      blok: map['blok'] ?? '',
      baris: map['baris'] ?? '',
      pohon: map['pohon'] ?? '',
      kategori: map['kategori'] ?? '',
      detail: map['detail'] ?? '',
      catatan: map['catatan'] ?? '',
      petugas: map['petugas'] ?? '',
      createdAt: map['createdAt'] ?? '',
      flag: map['flag'] ?? 0,
    );
  }
}
