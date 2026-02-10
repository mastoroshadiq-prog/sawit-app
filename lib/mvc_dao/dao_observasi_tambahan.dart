import 'package:sqflite/sqflite.dart';
import '../plantdb/db_helper.dart';
import '../mvc_models/observasi_tambahan.dart';

class ObservasiTambahanDao {
  final DBHelper _dbHelper = DBHelper();

  Future<int> insertObservasi(ObservasiTambahan data) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'observasi_tambahan',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ObservasiTambahan>> getAllZeroObservasi() async {
    final db = await _dbHelper.database;
    final res = await db.query('observasi_tambahan', where: 'flag = 0');
    return res.map((e) => ObservasiTambahan.fromMap(e)).toList();
  }

  Future<void> updateFlag(String idObservasi) async {
    final db = await _dbHelper.database;
    await db.update(
      'observasi_tambahan',
      {'flag': 1},
      where: 'idObservasi = ?',
      whereArgs: [idObservasi],
    );
  }
}
