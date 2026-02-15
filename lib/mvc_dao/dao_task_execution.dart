import '../plantdb/db_helper.dart';
import '../mvc_models/execution.dart';
import 'package:sqflite/sqflite.dart';

class TaskExecutionDao {
  final dbHelper = DBHelper();

  Future<int> insertTaskExec(TaskExecution taskExecution) async {
    final db = await dbHelper.database;
    return await db.insert(
      'eksekusi',
      taskExecution.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> insertListTaskExec(List<TaskExecution> taskExecution) async {
    final db = await dbHelper.database;
    int count = 0;

    for (var item in taskExecution) {
      await db.insert(
        'eksekusi',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      count++;
    }

    return count; // jumlah data yang berhasil diinsert
  }

  Future<int> inserttaskExecBatch(List<TaskExecution> taskExecution) async {
    final db = await dbHelper.database;

    // Mulai batch
    final batch = db.batch();

    // Tambahkan semua perintah insert ke dalam batch
    for (var item in taskExecution) {
      batch.insert(
        'eksekusi',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Eksekusi batch
    await batch.commit(noResult: true);

    // Return jumlah data yang diinsert
    return taskExecution.length;
  }

  Future<List<TaskExecution>> getAllTaskExec() async {
    final db = await dbHelper.database;
    final res = await db.query('eksekusi');
    return res.map((e) => TaskExecution.fromMap(e)).toList();
  }

  Future<List<TaskExecution>> getAllTaskExecByFlag() async {
    final db = await dbHelper.database;
    final res = await db.query('eksekusi', where: 'flag = 0');
    return res.map((e) => TaskExecution.fromMap(e)).toList();
  }

  Future<List<TaskExecution>> getPendingTaskExec() async {
    final db = await dbHelper.database;
    final res = await db.query(
      'eksekusi',
      where: 'flag = 0 AND TRIM(UPPER(taskState)) <> ?',
      whereArgs: ['SELESAI'],
    );
    return res.map((e) => TaskExecution.fromMap(e)).toList();
  }

  Future<List<TaskExecution>> getDoneTaskExec() async {
    final db = await dbHelper.database;
    final res = await db.query(
      'eksekusi',
      where: 'TRIM(UPPER(taskState)) = ?',
      whereArgs: ['SELESAI'],
    );
    return res.map((e) => TaskExecution.fromMap(e)).toList();
  }

  Future<int> countPendingTaskExec() async {
    final db = await dbHelper.database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM eksekusi WHERE flag = 0 AND TRIM(UPPER(taskState)) <> 'SELESAI'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<int> countDoneTaskExec() async {
    final db = await dbHelper.database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS total FROM eksekusi WHERE TRIM(UPPER(taskState)) = 'SELESAI'",
    );
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<TaskExecution?> getTaskExecById(String id) async {
    final db = await dbHelper.database;
    final res = await db.query('eksekusi', where: 'id = ?', whereArgs: [id]);
    if (res.isNotEmpty) return TaskExecution.fromMap(res.first);
    return null;
  }

  Future<TaskExecution?> getLatestBySpk(String spkNumber) async {
    final db = await dbHelper.database;
    final res = await db.query(
      'eksekusi',
      where: 'spkNumber = ?',
      whereArgs: [spkNumber],
      orderBy: 'taskDate DESC',
      limit: 1,
    );
    if (res.isNotEmpty) return TaskExecution.fromMap(res.first);
    return null;
  }

  Future<int> updateAssignment(TaskExecution taskExecution) async {
    final db = await dbHelper.database;
    return await db.update(
      'eksekusi',
      taskExecution.toMap(),
      where: 'id = ?',
      whereArgs: [taskExecution.id],
    );
  }

  Future<void> updateFlag(String id) async {
    // contoh: update flag=1 untuk record tertentu
    final db = await dbHelper.database;
    await db.update(
      'eksekusi',
      {'flag': 1}, // menandai sudah sync
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTaskExec(String id) async {
    final db = await dbHelper.database;
    return await db.delete('eksekusi', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllTaskExec() async {
    final db = await dbHelper.database;

    // Hapus semua data
    return await db.delete('eksekusi');
  }
}
