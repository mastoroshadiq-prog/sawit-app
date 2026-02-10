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

  Future<void> cleanDatabaseAfterLogin() async {
    final db = await database;

    await _cleanDataMaster(db);
    await _cleanDataOperasionalFlag1(db);
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

