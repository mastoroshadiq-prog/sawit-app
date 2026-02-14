import 'package:sqflite/sqflite.dart';

import '../mvc_models/assignment.dart';
import '../mvc_models/sop_master.dart';
import '../mvc_models/sop_step.dart';
import '../mvc_models/task_sop_check.dart';
import '../plantdb/db_helper.dart';

class SopDao {
  final DBHelper _dbHelper = DBHelper();

  Future<int> countUnsyncedChecks() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM task_sop_check WHERE flag = 0',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<List<TaskSopCheck>> getAllZeroChecks() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'task_sop_check',
      where: 'flag = 0',
      orderBy: 'checkedAt ASC',
    );
    return rows.map((e) => TaskSopCheck.fromMap(e)).toList();
  }

  Future<void> updateCheckFlag(String checkId, int flag) async {
    final db = await _dbHelper.database;
    await db.update(
      'task_sop_check',
      {'flag': flag},
      where: 'checkId = ?',
      whereArgs: [checkId],
    );
  }

  Future<void> replaceSopMasterFromServer(List<Map<String, dynamic>> rows) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('sop_master');
    for (final r in rows) {
      batch.insert(
        'sop_master',
        {
          'sopId': (r['sopId'] ?? '').toString(),
          'sopCode': (r['sopCode'] ?? '').toString(),
          'sopName': (r['sopName'] ?? '').toString(),
          'sopVersion': (r['sopVersion'] ?? '').toString(),
          'isActive': ((r['isActive'] as num?)?.toInt() ?? 0),
          'taskKeyword': (r['taskKeyword'] ?? '').toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceSopStepsFromServer(List<Map<String, dynamic>> rows) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('sop_step');
    for (final r in rows) {
      batch.insert(
        'sop_step',
        {
          'stepId': (r['stepId'] ?? '').toString(),
          'sopId': (r['sopId'] ?? '').toString(),
          'stepOrder': ((r['stepOrder'] as num?)?.toInt() ?? 0),
          'stepTitle': (r['stepTitle'] ?? '').toString(),
          'isRequired': ((r['isRequired'] as num?)?.toInt() ?? 0),
          'evidenceType': (r['evidenceType'] ?? 'none').toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceTaskSopMapFromServer(List<Map<String, dynamic>> rows) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    batch.delete('task_sop_map', where: 'sourceType = ?', whereArgs: ['server']);
    for (final r in rows) {
      batch.insert(
        'task_sop_map',
        {
          'mapId': (r['mapId'] ?? '').toString(),
          'assignmentId': (r['assignmentId'] ?? '').toString(),
          'spkNumber': (r['spkNumber'] ?? '').toString(),
          'sopId': (r['sopId'] ?? '').toString(),
          'sourceType': (r['sourceType'] ?? 'server').toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<SopMaster?> resolveSopForAssignment(Assignment assignment) async {
    final db = await _dbHelper.database;

    final mapBySpk = await db.query(
      'task_sop_map',
      where: 'spkNumber = ?',
      whereArgs: [assignment.spkNumber],
      limit: 1,
    );
    if (mapBySpk.isNotEmpty) {
      final sopId = (mapBySpk.first['sopId'] ?? '').toString();
      if (sopId.isNotEmpty) {
        final found = await db.query(
          'sop_master',
          where: 'sopId = ? AND isActive = 1',
          whereArgs: [sopId],
          limit: 1,
        );
        if (found.isNotEmpty) return SopMaster.fromMap(found.first);
      }
    }

    final list = await db.query(
      'sop_master',
      where: 'isActive = 1',
      orderBy: 'sopCode ASC',
    );

    final taskLower = assignment.taskName.toLowerCase();
    for (final row in list) {
      final keywordRaw = (row['taskKeyword'] ?? '').toString().trim().toLowerCase();
      if (keywordRaw.isEmpty) continue;

      final tokens = keywordRaw
          .split(RegExp(r'[|,;]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (tokens.isEmpty) {
        if (taskLower.contains(keywordRaw)) {
          return SopMaster.fromMap(row);
        }
        continue;
      }

      final matched = tokens.any(taskLower.contains);
      if (matched) {
        return SopMaster.fromMap(row);
      }
    }

    if (list.isNotEmpty) return SopMaster.fromMap(list.first);
    return null;
  }

  Future<List<SopStep>> getStepsBySopId(String sopId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'sop_step',
      where: 'sopId = ?',
      whereArgs: [sopId],
      orderBy: 'stepOrder ASC',
    );
    return rows.map((e) => SopStep.fromMap(e)).toList();
  }

  Future<List<TaskSopCheck>> getChecksForAssignment(
    String assignmentId,
    String sopId,
  ) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'task_sop_check',
      where: 'assignmentId = ? AND sopId = ?',
      whereArgs: [assignmentId, sopId],
      orderBy: 'checkedAt DESC',
    );
    return rows.map((e) => TaskSopCheck.fromMap(e)).toList();
  }

  Future<void> upsertCheck(TaskSopCheck check) async {
    final db = await _dbHelper.database;
    await db.insert(
      'task_sop_check',
      check.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, bool>> getCheckedStateMap(String assignmentId, String sopId) async {
    final checks = await getChecksForAssignment(assignmentId, sopId);
    final map = <String, bool>{};
    for (final c in checks) {
      map[c.stepId] = c.isChecked == 1;
    }
    return map;
  }

  Future<bool> areRequiredStepsComplete(String assignmentId, String sopId) async {
    final steps = await getStepsBySopId(sopId);
    final checkedMap = await getCheckedStateMap(assignmentId, sopId);
    for (final s in steps) {
      if (s.isRequired == 1 && checkedMap[s.stepId] != true) {
        return false;
      }
    }
    return true;
  }
}

