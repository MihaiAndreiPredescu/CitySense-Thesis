import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/offline_report.dart';

class OfflineReportRepository {
  static const _databaseName = 'citysense_offline_reports.db';
  static const _databaseVersion = 1;
  static const _tableName = 'offline_reports';
  static const _pendingState = 'pending';
  static const _failedState = 'failed';

  final Uuid _uuid = const Uuid();
  Database? _database;

  Future<OfflineReport> enqueueReport({
    required File imageFile,
    required double latitude,
    required double longitude,
    required DateTime capturedAt,
  }) async {
    final clientReportId = _uuid.v4();
    final storedImage = await _copyImage(imageFile, clientReportId);
    final queuedAt = DateTime.now().toUtc();

    await (await _db).insert(_tableName, {
      'client_report_id': clientReportId,
      'image_path': storedImage.path,
      'latitude': latitude,
      'longitude': longitude,
      'captured_at': capturedAt.toUtc().toIso8601String(),
      'queued_at': queuedAt.toIso8601String(),
      'retry_count': 0,
      'last_error': null,
      'state': _pendingState,
    });

    return OfflineReport(
      clientReportId: clientReportId,
      imagePath: storedImage.path,
      latitude: latitude,
      longitude: longitude,
      capturedAt: capturedAt.toUtc(),
      queuedAt: queuedAt,
      retryCount: 0,
      state: _pendingState,
    );
  }

  Future<List<OfflineReport>> pendingReports() async {
    final rows = await (await _db).query(
      _tableName,
      where: 'state = ?',
      whereArgs: [_pendingState],
      orderBy: 'queued_at ASC',
    );
    return rows.map(OfflineReport.fromMap).toList();
  }

  Future<int> pendingCount() async {
    return _countWhereState(_pendingState);
  }

  Future<int> failedCount() async {
    return _countWhereState(_failedState);
  }

  Future<void> markRetryableFailure({
    required String clientReportId,
    required String error,
  }) async {
    final report = await findByClientReportId(clientReportId);
    await (await _db).update(
      _tableName,
      {
        'retry_count': (report?.retryCount ?? 0) + 1,
        'last_error': error,
        'state': _pendingState,
      },
      where: 'client_report_id = ?',
      whereArgs: [clientReportId],
    );
  }

  Future<void> markPermanentFailure({
    required String clientReportId,
    required String error,
  }) async {
    final report = await findByClientReportId(clientReportId);
    await (await _db).update(
      _tableName,
      {
        'retry_count': (report?.retryCount ?? 0) + 1,
        'last_error': error,
        'state': _failedState,
      },
      where: 'client_report_id = ?',
      whereArgs: [clientReportId],
    );
  }

  Future<OfflineReport?> findByClientReportId(String clientReportId) async {
    final rows = await (await _db).query(
      _tableName,
      where: 'client_report_id = ?',
      whereArgs: [clientReportId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return OfflineReport.fromMap(rows.first);
  }

  Future<void> deleteReport(String clientReportId) async {
    final report = await findByClientReportId(clientReportId);
    await (await _db).delete(
      _tableName,
      where: 'client_report_id = ?',
      whereArgs: [clientReportId],
    );

    final imagePath = report?.imagePath;
    if (imagePath != null) {
      final image = File(imagePath);
      if (await image.exists()) {
        await image.delete();
      }
    }
  }

  Future<void> close() async {
    final database = _database;
    if (database != null) {
      await database.close();
      _database = null;
    }
  }

  Future<int> _countWhereState(String state) async {
    final result = Sqflite.firstIntValue(
      await (await _db).rawQuery(
        'SELECT COUNT(*) FROM $_tableName WHERE state = ?',
        [state],
      ),
    );
    return result ?? 0;
  }

  Future<File> _copyImage(File imageFile, String clientReportId) async {
    final directory = await getApplicationDocumentsDirectory();
    final offlineDirectory = Directory(
      path.join(directory.path, 'offline_reports'),
    );
    if (!await offlineDirectory.exists()) {
      await offlineDirectory.create(recursive: true);
    }

    final extension = path.extension(imageFile.path).isEmpty
        ? '.jpg'
        : path.extension(imageFile.path);
    final destination = File(
      path.join(offlineDirectory.path, '$clientReportId$extension'),
    );
    return imageFile.copy(destination.path);
  }

  Future<Database> get _db async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final directory = await getApplicationDocumentsDirectory();
    final database = await openDatabase(
      path.join(directory.path, _databaseName),
      version: _databaseVersion,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            client_report_id TEXT PRIMARY KEY,
            image_path TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            captured_at TEXT NOT NULL,
            queued_at TEXT NOT NULL,
            retry_count INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            state TEXT NOT NULL DEFAULT '$_pendingState'
          )
        ''');
      },
    );
    _database = database;
    return database;
  }
}
