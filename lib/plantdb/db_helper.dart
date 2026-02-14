import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'plantdb.db');

    //await deleteDatabase(path);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<Database> inisiasiDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'plantdb.db');
    //await deleteDatabase(path);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
  }

  Future<void> _onOpen(Database db) async {
    // Guard migrasi ringan untuk user existing (DB lama versi 1)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS observasi_tambahan (
        idObservasi TEXT PRIMARY KEY,
        idTanaman TEXT,
        blok TEXT,
        baris TEXT,
        pohon TEXT,
        kategori TEXT,
        detail TEXT,
        catatan TEXT,
        petugas TEXT,
        createdAt TEXT,
        flag INTEGER
      )
    ''');

    final repoColumns = await db.rawQuery('PRAGMA table_info(reposisi)');
    final hasCreatedAt = repoColumns.any((c) => c['name'] == 'createdAt');
    if (!hasCreatedAt) {
      await db.execute('ALTER TABLE reposisi ADD COLUMN createdAt TEXT');
    }

    // Backfill timestamp untuk data lama agar tetap bisa ditampilkan di drilldown
    await db.execute(
      "UPDATE reposisi SET createdAt = datetime('now') WHERE createdAt IS NULL OR createdAt = ''",
    );

    await _ensureSopTables(db);
    await _ensureSopSeed(db);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pohon (
        blok TEXT,
        nbaris TEXT,
        npohon TEXT,
        objectId TEXT PRIMARY KEY,
        status TEXT,
        nflag TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS assignment (
        id TEXT PRIMARY KEY,
        spkNumber TEXT,
        taskName TEXT,
        estate TEXT,
        division TEXT,
        block TEXT,
        rowNumber TEXT,
        treeNumber TEXT,
        petugas TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS eksekusi (
        id TEXT PRIMARY KEY,
        spkNumber TEXT,
        taskName TEXT,
        taskState TEXT,
        petugas TEXT,
        taskDate TEXT,
        keterangan TEXT,
        imagePath TEXT,
        flag INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS riwayat (
        id TEXT PRIMARY KEY,
        objectId TEXT,
        tanggal TEXT,
        jenis TEXT,
        keterangan TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reposisi (
        idReposisi TEXT PRIMARY KEY,
        idTanaman TEXT,
        pohonAwal TEXT,
        barisAwal TEXT,
        pohonTujuan TEXT,
        barisTujuan TEXT,
        keterangan TEXT,
        tipeRiwayat TEXT,
        petugas TEXT,
        flag INTEGER,
        blok TEXT,
        createdAt TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS observasi_tambahan (
        idObservasi TEXT PRIMARY KEY,
        idTanaman TEXT,
        blok TEXT,
        baris TEXT,
        pohon TEXT,
        kategori TEXT,
        detail TEXT,
        catatan TEXT,
        petugas TEXT,
        createdAt TEXT,
        flag INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stand_per_row (
        idSPR TEXT PRIMARY KEY,
        blok TEXT,
        nbaris TEXT,
        sprAwal TEXT,
        sprAkhir TEXT,
        keterangan TEXT,
        petugas TEXT,
        flag INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS spr_log (
        idLog TEXT PRIMARY KEY,
        blok TEXT,
        nbaris TEXT,
        sprAwal TEXT,
        sprAkhir TEXT,
        keterangan TEXT,
        petugas TEXT,
        flag INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS kesehatan (
        idKesehatan TEXT PRIMARY KEY,
        idTanaman TEXT,
        statusAwal TEXT,
        statusAkhir TEXT,
        kodeStatus TEXT,
        jenisPohon TEXT,
        keterangan TEXT,
        petugas TEXT,
        fromDate TEXT,
        thruDate TEXT,
        flag INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS petugas (
        akun TEXT PRIMARY KEY,
        nama TEXT,
        kontak TEXT,
        peran TEXT,
        lastSync TEXT,
        blok TEXT,
        divisi TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS auditlog (
        id_audit TEXT PRIMARY KEY,
        user_id TEXT,
        action TEXT,
        detail TEXT,
        log_date TEXT,
        device TEXT,
        flag INTEGER
      )
    ''');

    await _ensureSopTables(db);
    await _ensureSopSeed(db);

    debugPrint("VIEW TABLE CREATION STARTED");
    await db.execute('''
        CREATE VIEW v_reporting AS
        SELECT a.akun, a.nama, a.peran,
        c.spkNumber, c.taskName, c.taskState, 
        count(c.id) AS totalAssignment,
        count(CASE WHEN c.taskState = 'Selesai' THEN 1 END) AS totalSelesai,
        count(CASE WHEN c.taskState = 'Ditunda' THEN 1 END) AS totalDitunda,
        count(d.idKesehatan) AS totalKesehatan,
        count(e.idReposisi) AS totalReposisi
        FROM petugas a
        LEFT JOIN assignment b ON a.akun = b.petugas
        LEFT JOIN eksekusi c ON b.spkNumber = c.spkNumber
        LEFT JOIN kesehatan d ON d.petugas = a.akun
        LEFT JOIN reposisi e ON e.petugas = a.akun
        GROUP BY a.akun, a.nama, a.peran, c.spkNumber, c.taskName, c.taskState
    ''');

    debugPrint("DATABASE & TABLES CREATED");
  }

  Future<void> _ensureSopTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sop_master (
        sopId TEXT PRIMARY KEY,
        sopCode TEXT,
        sopName TEXT,
        sopVersion TEXT,
        isActive INTEGER,
        taskKeyword TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sop_step (
        stepId TEXT PRIMARY KEY,
        sopId TEXT,
        stepOrder INTEGER,
        stepTitle TEXT,
        isRequired INTEGER,
        evidenceType TEXT,
        FOREIGN KEY (sopId) REFERENCES sop_master(sopId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_sop_map (
        mapId TEXT PRIMARY KEY,
        assignmentId TEXT,
        spkNumber TEXT,
        sopId TEXT,
        sourceType TEXT,
        FOREIGN KEY (sopId) REFERENCES sop_master(sopId)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS task_sop_check (
        checkId TEXT PRIMARY KEY,
        executionId TEXT,
        assignmentId TEXT,
        spkNumber TEXT,
        sopId TEXT,
        stepId TEXT,
        isChecked INTEGER,
        note TEXT,
        evidencePath TEXT,
        checkedAt TEXT,
        flag INTEGER,
        FOREIGN KEY (sopId) REFERENCES sop_master(sopId),
        FOREIGN KEY (stepId) REFERENCES sop_step(stepId)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sop_step_sop ON sop_step(sopId, stepOrder)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_sop_map_spk ON task_sop_map(spkNumber)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_sop_check_exec ON task_sop_check(executionId, stepId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_task_sop_check_assign ON task_sop_check(assignmentId, stepId)',
    );
  }

  Future<void> _ensureSopSeed(Database db) async {
    final existing = await db.rawQuery('SELECT COUNT(*) as c FROM sop_master');
    final count = Sqflite.firstIntValue(existing) ?? 0;
    if (count > 0) return;

    await db.insert('sop_master', {
      'sopId': 'SOP-GENERAL-TASK',
      'sopCode': 'SOP-GEN-001',
      'sopName': 'SOP Umum Pengerjaan Task Lapangan',
      'sopVersion': '1.0',
      'isActive': 1,
      'taskKeyword': 'TASK',
    });

    final steps = [
      {
        'stepId': 'SOP-GEN-STEP-01',
        'sopId': 'SOP-GENERAL-TASK',
        'stepOrder': 1,
        'stepTitle': 'Verifikasi lokasi kerja (blok/baris/pohon)',
        'isRequired': 1,
        'evidenceType': 'none',
      },
      {
        'stepId': 'SOP-GEN-STEP-02',
        'sopId': 'SOP-GENERAL-TASK',
        'stepOrder': 2,
        'stepTitle': 'Pastikan APD dan keselamatan kerja terpenuhi',
        'isRequired': 1,
        'evidenceType': 'none',
      },
      {
        'stepId': 'SOP-GEN-STEP-03',
        'sopId': 'SOP-GENERAL-TASK',
        'stepOrder': 3,
        'stepTitle': 'Laksanakan tindakan sesuai instruksi SPK',
        'isRequired': 1,
        'evidenceType': 'none',
      },
      {
        'stepId': 'SOP-GEN-STEP-04',
        'sopId': 'SOP-GENERAL-TASK',
        'stepOrder': 4,
        'stepTitle': 'Ambil dokumentasi hasil pekerjaan',
        'isRequired': 1,
        'evidenceType': 'photo',
      },
      {
        'stepId': 'SOP-GEN-STEP-05',
        'sopId': 'SOP-GENERAL-TASK',
        'stepOrder': 5,
        'stepTitle': 'Catat temuan penting jika ada',
        'isRequired': 0,
        'evidenceType': 'note',
      },
    ];

    for (final step in steps) {
      await db.insert('sop_step', step);
    }
  }

  Future<void> cleanDatabaseAfterLogin() async {
    final db = await database;

    await _cleanDataMaster(db);
    await _cleanDataOperasionalFlag1(db);
  }

  Future<void> cleanDatabaseForUserSwitch() async {
    final db = await database;
    final tables = <String>[
      'petugas',
      'assignment',
      'pohon',
      'stand_per_row',
      'eksekusi',
      'kesehatan',
      'reposisi',
      'observasi_tambahan',
      'auditlog',
      'spr_log',
      'riwayat',
    ];

    for (final table in tables) {
      await db.delete(table);
    }
  }

  Future<void> _cleanDataMaster(Database db) async {
    final List<String> masterTables = [
      'petugas',
      //'pohon',
      'assignment',
      //'auditlog',
    ];

    for (final table in masterTables) {
      await db.delete(table);
    }
  }

  Future<void> _cleanDataOperasionalFlag1(Database db) async {
    final List<String> trxTables = [
      'eksekusi',
      'kesehatan',
      'reposisi',
      'observasi_tambahan',
      'auditlog',
    ];

    for (final table in trxTables) {
      await db.delete(
        table,
        where: 'flag = ?',
        whereArgs: [1],
      );
    }
  }

/*
  Future<int> rawExecute(String sql, [List<dynamic>? arguments]) async {
    final Database db = await database;
    return await db.rawExecute(sql, arguments);
  }
*/

  Future<int> countTable(Database db, String tableName) async {
    final result = await db.rawQuery(
      'SELECT COUNT(*) as total FROM $tableName',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

}

