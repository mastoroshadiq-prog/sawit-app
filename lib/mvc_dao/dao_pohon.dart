import '../plantdb/db_helper.dart';
import '../mvc_models/pohon.dart';
import 'package:sqflite/sqflite.dart';

class PohonDao {
  final dbHelper = DBHelper();

  Future<int> insertPohon(Pohon pohon) async {
    final db = await dbHelper.database;
    return await db.insert(
      'pohon',
      pohon.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertPohonBatch(List<Pohon> pohon) async {
    final db = await dbHelper.database;

    // Mulai batch
    final batch = db.batch();

    // Tambahkan semua perintah insert ke dalam batch
    for (var item in pohon) {
      batch.insert(
        'pohon',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Eksekusi batch
    await batch.commit(noResult: true);

    // Return jumlah data yang diinsert
    return pohon.length;
  }

  Future<List<Pohon>> getAllPohonX() async {
    final db = await dbHelper.database;
    final res = await db.query('pohon');
    return res.map((e) => Pohon.fromMap(e)).toList();
  }

  Future<List<Pohon>> getAllPohon() async {
    final db = await dbHelper.database;
    final res = await db.query('pohon');
    return res.map((e) => Pohon.fromMap(e)).toList();
  }

  Future<List<Pohon>> getAllPohonByBlok(String blok) async {
    final db = await dbHelper.database;
    final res = await db.query('pohon', where: 'blok = ?', whereArgs: [blok]);
    return res.map((e) => Pohon.fromMap(e)).toList();
  }

  Future<Pohon?> getPohonById(String objectId) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'pohon',
      where: 'objectId = ?',
      whereArgs: [objectId],
    );
    if (res.isNotEmpty) return Pohon.fromMap(res.first);
    return null;
  }

  Future<int> updatePohon(Pohon pohon) async {
    final db = await dbHelper.database;
    return await db.update(
      'pohon',
      pohon.toMap(),
      where: 'objectId = ?',
      whereArgs: [pohon.objectId],
    );
  }

  Future<void> updateStatusPohon(
      String barisTujuan,
      String nFlag,
      String nPohonAwal,
      String nBarisAwal
  ) async {
    // contoh: update flag=1 untuk record tertentu
    final db = await dbHelper.database;
    await db.update(
      'pohon',
      {'nflag': nFlag, 'npohon': nPohonAwal, 'nbaris': nBarisAwal},
      where: 'npohon = ? AND nbaris = ?',
      whereArgs: [nPohonAwal, barisTujuan],
    );
  }

  Future<void> updateStatusPohonByObjectId(
    String objectId,
    String nFlag,
    String nPohonAwal,
    String nBarisAwal,
  ) async {
    final db = await dbHelper.database;
    await db.update(
      'pohon',
      {
        'nflag': nFlag,
        'npohon': nPohonAwal,
        'nbaris': nBarisAwal,
      },
      where: 'objectId = ?',
      whereArgs: [objectId],
    );
  }

  Future<int> deletePohon(String objectId) async {
    final db = await dbHelper.database;
    return await db.delete(
      'pohon',
      where: 'objectId = ?',
      whereArgs: [objectId],
    );
  }

  Future<int> deleteAllPohon() async {
    final db = await dbHelper.database;

    // Hapus semua data
    return await db.delete('pohon');
  }

  Future<int> deleteByBlok(String blok) async {
    final db = await dbHelper.database;
    return await db.delete(
      'pohon',
      where: 'blok = ?',
      whereArgs: [blok],
    );
  }
}
