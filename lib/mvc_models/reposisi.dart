class Reposisi {
  final String idReposisi;    // PRIMARY KEY
  final String idTanaman;     // referensi ke pohon.objectId
  final String pohonAwal;     // posisi pohon sebelum reposisi
  final String barisAwal;     // posisi baris sebelum reposisi
  final String pohonTujuan;   // posisi pohon setelah reposisi
  final String barisTujuan;   // posisi baris setelah reposisi
  final String keterangan;    // catatan bebas
  final String tipeRiwayat;   // contoh: L,R,N,K (Left, Right, Normal, Kenthosan)
  final String petugas;
  final int flag;
  final String blok;
  final String createdAt;

  Reposisi({
    required this.idReposisi,
    required this.idTanaman,
    required this.pohonAwal,
    required this.barisAwal,
    required this.pohonTujuan,
    required this.barisTujuan,
    required this.keterangan,
    required this.tipeRiwayat,
    required this.petugas,
    required this.flag,
    required this.blok,
    this.createdAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'idReposisi': idReposisi,
      'idTanaman': idTanaman,
      'pohonAwal': pohonAwal,
      'barisAwal': barisAwal,
      'pohonTujuan': pohonTujuan,
      'barisTujuan': barisTujuan,
      'keterangan': keterangan,
      'tipeRiwayat': tipeRiwayat,
      'petugas': petugas,
      'flag': flag,
      'blok': blok,
      'createdAt': createdAt,
    };
  }

  factory Reposisi.fromMap(Map<String, dynamic> map) {
    return Reposisi(
      idReposisi: map['idReposisi'] ?? '',
      idTanaman: map['idTanaman'] ?? '',
      pohonAwal: map['pohonAwal'] ?? '',
      barisAwal: map['barisAwal'] ?? '',
      pohonTujuan: map['pohonTujuan'] ?? '',
      barisTujuan: map['barisTujuan'] ?? '',
      keterangan: map['keterangan'] ?? '',
      tipeRiwayat: map['tipeRiwayat'] ?? '',
      petugas: map['petugas'] ?? '',
      flag: map['flag'] ?? 0,
      blok: map['blok'] ?? '',
      createdAt: map['createdAt'] ?? '',
    );
  }
}
