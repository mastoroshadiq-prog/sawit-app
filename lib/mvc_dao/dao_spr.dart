import 'package:sqflite/sqflite.dart';
import '../plantdb/db_helper.dart';
import '../mvc_models/spr.dart';

class SPRDao {
  final DBHelper _dbHelper = DBHelper();

  // INSERT / UPDATE
  Future<int> insertSPR(SPR data) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'stand_per_row',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertSPRBatch(List<SPR> spr) async {
    final db = await _dbHelper.database;

    // Mulai batch
    final batch = db.batch();

    // Tambahkan semua perintah insert ke dalam batch
    for (var item in spr) {
      batch.insert(
        'stand_per_row',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Eksekusi batch
    await batch.commit(noResult: true);

    // Return jumlah data yang diinsert
    return spr.length;
  }

  // GET ALL
  Future<List<SPR>> getAllSPR() async {
    final db = await _dbHelper.database;
    final result = await db.query('stand_per_row');
    return result.map((e) => SPR.fromMap(e)).toList();
  }

  Future<List<SPR>> getByBlok(String blok) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'stand_per_row',
      where: 'TRIM(UPPER(blok)) = TRIM(UPPER(?))',
      whereArgs: [blok],
    );
    return result.map((e) => SPR.fromMap(e)).toList();
  }

  Future<List<SPR>> getAllByFlagX() async {
    final db = await _dbHelper.database;
    final res = await db.query(
        'stand_per_row',
        where: 'flag = 0'
    );
    return res.map((e) => SPR.fromMap(e)).toList();
  }

  Future<List<SPR>> getTenByFlag() async {
    final db = await _dbHelper.database;
    final res = await db.query('stand_per_row', where: 'flag = 0', limit: 10,);
    return res.map((e) => SPR.fromMap(e)).toList();
  }

  // GET BY PRIMARY KEY
  Future<SPR?> getByIdSPR(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'stand_per_row',
      where: 'idSPR = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return SPR.fromMap(result.first);
    }
    return null;
  }

  // GET BY idTanaman
  Future<List<SPR>> getById(String id) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'stand_per_row',
      where: 'idSPR = ?',
      whereArgs: [id],
    );
    return result.map((e) => SPR.fromMap(e)).toList();
  }

  Future<int> countUnsyncedSPR() async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery('SELECT COUNT(*) FROM stand_per_row WHERE flag = 0');

    // Mengambil angka pertama dari hasil query
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> updateSPR(SPR spr) async {
    final db = await _dbHelper.database;
    return await db.update(
      'stand_per_row',
      spr.toMap(),
      where: 'idSPR = ?',
      whereArgs: [spr.idSPR],
    );
  }

  Future<void> updateFlag(String blok, String nbaris) async {
    final db = await _dbHelper.database;
    await db.update(
      'stand_per_row',
      {'flag': 1}, // menandai sudah sync
      where: 'blok = ? AND baris = ?',
      whereArgs: [blok, nbaris],
    );
  }

  Future<void> sprTerkini(SPR spr) async {
    final db = await _dbHelper.database;
    await db.update(
      'stand_per_row',
      {'sprAwal': spr.sprAwal, 'sprAkhir': spr.sprAkhir, 'keterangan': spr.keterangan},
      where: 'blok = ? AND nbaris = ?',
      whereArgs: [spr.blok, spr.nbaris],
    );
  }

  // DELETE ALL
  Future<int> deleteAll() async {
    final db = await _dbHelper.database;
    return await db.delete('stand_per_row');
  }

  Future<int> deleteByBlok(String blok) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'stand_per_row',
      where: 'TRIM(UPPER(blok)) = TRIM(UPPER(?))',
      whereArgs: [blok],
    );
  }

}
