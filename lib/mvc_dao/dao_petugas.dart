import 'package:sqflite/sqflite.dart';
import '../plantdb/db_helper.dart';
import '../mvc_models/petugas.dart';

class PetugasDao {
  final DBHelper _dbHelper = DBHelper();

  // INSERT / UPDATE
  Future<int> insertPetugas(Petugas data) async {
    final db = await _dbHelper.database;
    return await db.insert(
      'petugas',
      data.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // GET ALL
  Future<List<Petugas>> getAllPetugas() async {
    final db = await _dbHelper.database;
    final result = await db.query('petugas');
    return result.map((e) => Petugas.fromMap(e)).toList();
  }

  // GET BY akun
  Future<Petugas?> getByAkun(String akun) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'petugas',
      where: 'akun = ?',
      whereArgs: [akun],
    );

    if (result.isNotEmpty) {
      return Petugas.fromMap(result.first);
    }
    return null;
  }

  Future<Petugas?> getPetugas() async {
    final db = await _dbHelper.database;
    final result = await db.query('petugas');

    if (result.isNotEmpty) {
      return Petugas.fromMap(result.first);
    }
    return null;
  }

  // UPDATE last_sync
  Future<int> updateLastSync(String akun, String lastSync) async {
    final db = await _dbHelper.database;
    return await db.update(
      'petugas',
      {'lastSync': lastSync},
      where: 'akun = ?',
      whereArgs: [akun],
    );
  }

  Future<int> updateBlok(String akun, String blok) async {
    final db = await _dbHelper.database;
    return await db.update(
      'petugas',
      {'blok': blok},
      where: 'akun = ?',
      whereArgs: [akun],
    );
  }

  // DELETE ALL (opsional)
  Future<int> deleteAllWorkers() async {
    final db = await _dbHelper.database;
    return await db.delete('petugas');
  }
}
