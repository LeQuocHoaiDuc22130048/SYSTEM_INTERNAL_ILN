import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../utils/api_client.dart';

class EnrolledEmployee {
  final String id;
  final String name;
  final String? backendEmployeeId;
  final String modelName;

  const EnrolledEmployee({
    required this.id,
    required this.name,
    this.backendEmployeeId,
    required this.modelName,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'backend_employee_id': backendEmployeeId,
      'model_name': modelName,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory EnrolledEmployee.fromMap(Map<String, Object?> map) {
    return EnrolledEmployee(
      id: map['id'] as String,
      name: map['name'] as String,
      backendEmployeeId: map['backend_employee_id'] as String?,
      modelName: map['model_name']?.toString() ?? 'legacy',
    );
  }
}

class FaceEmbeddingSample {
  final int? id;
  final String employeeId;
  final String modelName;
  final int sampleIndex;
  final List<double> embedding;

  const FaceEmbeddingSample({
    this.id,
    required this.employeeId,
    required this.modelName,
    required this.sampleIndex,
    required this.embedding,
  });

  factory FaceEmbeddingSample.fromMap(Map<String, Object?> map) {
    return FaceEmbeddingSample(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as String,
      modelName: map['model_name']?.toString() ?? 'legacy',
      sampleIndex: (map['sample_index'] as num?)?.toInt() ?? 0,
      embedding: (jsonDecode(map['embedding'] as String) as List)
          .map((x) => (x as num).toDouble())
          .toList(growable: false),
    );
  }
}

class AttendanceLog {
  final int? id;
  final String employeeId;
  final String employeeName;
  final double confidence;
  final DateTime checkedAt;
  final String type;
  final String? backendEmployeeId;
  final List<double>? faceEmbedding;
  final String? faceImageBase64;
  final String? imageContentType;
  final DateTime? syncedAt;
  final String? syncError;

  const AttendanceLog({
    this.id,
    required this.employeeId,
    required this.employeeName,
    required this.confidence,
    required this.checkedAt,
    required this.type,
    this.backendEmployeeId,
    this.faceEmbedding,
    this.faceImageBase64,
    this.imageContentType,
    this.syncedAt,
    this.syncError,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'confidence': confidence,
      'checked_at': checkedAt.toIso8601String(),
      'type': type,
      'backend_employee_id': backendEmployeeId,
      'face_embedding': faceEmbedding == null
          ? null
          : jsonEncode(faceEmbedding),
      'face_image_base64': faceImageBase64,
      'image_content_type': imageContentType,
      'synced_at': syncedAt?.toIso8601String(),
      'sync_error': syncError,
    };
  }

  factory AttendanceLog.fromMap(Map<String, Object?> map) {
    return AttendanceLog(
      id: map['id'] as int?,
      employeeId: map['employee_id'] as String,
      employeeName: map['employee_name'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      checkedAt: DateTime.parse(map['checked_at'] as String),
      type: map['type']?.toString() ?? 'IN',
      backendEmployeeId: map['backend_employee_id'] as String?,
      faceEmbedding: map['face_embedding'] == null
          ? null
          : (jsonDecode(map['face_embedding'] as String) as List)
                .map((x) => (x as num).toDouble())
                .toList(growable: false),
      faceImageBase64: map['face_image_base64'] as String?,
      imageContentType: map['image_content_type'] as String?,
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
      syncError: map['sync_error'] as String?,
    );
  }

  bool get isSynced => syncedAt != null;
}

class FaceMatch {
  final EnrolledEmployee employee;
  final double cosineSimilarity;
  final double euclideanDistance;

  const FaceMatch({
    required this.employee,
    required this.cosineSimilarity,
    required this.euclideanDistance,
  });
}

class FaceRecognitionAttempt {
  final int? id;
  final String? localAttemptId;
  final String modelName;
  final String outcome;
  final double? similarityScore;
  final double threshold;
  final String? employeeId;
  final String? employeeName;
  final String? backendEmployeeId;
  final String deviceId;
  final DateTime occurredAt;
  final DateTime? syncedAt;
  final String? syncError;

  const FaceRecognitionAttempt({
    this.id,
    this.localAttemptId,
    required this.modelName,
    required this.outcome,
    required this.similarityScore,
    required this.threshold,
    this.employeeId,
    this.employeeName,
    this.backendEmployeeId,
    required this.deviceId,
    required this.occurredAt,
    this.syncedAt,
    this.syncError,
  });

  factory FaceRecognitionAttempt.fromMap(Map<String, Object?> map) {
    return FaceRecognitionAttempt(
      id: map['id'] as int?,
      localAttemptId: map['local_attempt_id'] as String?,
      modelName: map['model_name']?.toString() ?? 'face-embedding',
      outcome: map['outcome']?.toString() ?? 'REJECTED',
      similarityScore: (map['similarity_score'] as num?)?.toDouble(),
      threshold: (map['threshold'] as num?)?.toDouble() ?? 0,
      employeeId: map['employee_id'] as String?,
      employeeName: map['employee_name'] as String?,
      backendEmployeeId: map['backend_employee_id'] as String?,
      deviceId: map['device_id']?.toString() ?? 'flutter-mobile-offline-face',
      occurredAt: DateTime.parse(map['occurred_at'] as String),
      syncedAt: map['synced_at'] == null
          ? null
          : DateTime.parse(map['synced_at'] as String),
      syncError: map['sync_error'] as String?,
    );
  }
}

class FaceMatchThresholdCalibration {
  static const minThreshold = 0.0;
  static const maxThreshold = 1.0;
  static const provisionalLocalThreshold = minThreshold;

  const FaceMatchThresholdCalibration._();
}

class DatabaseService {
  Database? _db;
  int _lastNearbyDuplicateSkips = 0;
  static const embeddingMaxOfflineAge = Duration(days: 7);
  static const biometricQueueRetention = Duration(days: 30);
  static const syncQueueRetention = Duration(days: 90);
  static const attendanceAttemptWindow = Duration(minutes: 1);

  bool get lastSyncHadNearbyDuplicate => _lastNearbyDuplicateSkips > 0;

  Future<double?> getFaceMatchThreshold() async {
    final raw = await _getMetadata('face_match_threshold');
    final parsed = raw == null ? null : double.tryParse(raw);
    if (parsed == null) return null;
    return parsed.clamp(
      FaceMatchThresholdCalibration.minThreshold,
      FaceMatchThresholdCalibration.maxThreshold,
    );
  }

  Future<void> saveFaceMatchThreshold(double threshold) async {
    final normalized = threshold.clamp(
      FaceMatchThresholdCalibration.minThreshold,
      FaceMatchThresholdCalibration.maxThreshold,
    );
    await _setMetadata('face_match_threshold', normalized.toStringAsFixed(4));
  }

  Future<void> recordAttendanceSecurityEvent({
    required String reason,
    String? detail,
    String deviceId = 'flutter-mobile-offline-face',
  }) async {
    final db = await database;
    await db.insert('attendance_security_events', {
      'device_id': deviceId,
      'reason': reason,
      'detail': detail,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<int> countRecentAttendanceAttempts({
    Duration window = attendanceAttemptWindow,
    String deviceId = 'flutter-mobile-offline-face',
  }) async {
    final db = await database;
    final cutoff = DateTime.now().toUtc().subtract(window).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM attendance_security_events
      WHERE device_id = ?
        AND reason = 'ATTENDANCE_ATTEMPT'
        AND occurred_at >= ?
      ''',
      [deviceId, cutoff],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }


  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'offline_face_attendance.db');
    _db = await openDatabase(
      path,
      version: 10,
      onCreate: _createSchema,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(
            db,
            'employees',
            'backend_employee_id',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'type',
            "TEXT NOT NULL DEFAULT 'IN'",
          );
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'backend_employee_id',
            'TEXT',
          );
          await _addColumnIfMissing(db, 'attendance_logs', 'synced_at', 'TEXT');
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'sync_error',
            'TEXT',
          );
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            'employees',
            'model_name',
            "TEXT NOT NULL DEFAULT 'legacy'",
          );
        }
        if (oldVersion < 4) {
          await _createEmbeddingTable(db);
          await _migrateLegacyEmbeddings(db);
        }
        if (oldVersion < 5) {
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'face_embedding',
            'TEXT',
          );
        }
        if (oldVersion < 6) {
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'face_image_base64',
            'TEXT',
          );
          await _addColumnIfMissing(
            db,
            'attendance_logs',
            'image_content_type',
            'TEXT',
          );
        }
        if (oldVersion < 7) {
          await _createSyncMetadataTable(db);
        }
        if (oldVersion < 8) {
          await _createAttendanceSecurityEventTable(db);
        }
        if (oldVersion < 9) {
          await _createFaceRecognitionAttemptTable(db);
        }
        if (oldVersion < 10) {
          await _createAttendanceLogIndexes(db);
          await _createFaceRecognitionAttemptIndexes(db);
        }
      },
    );
    await _ensureSchema(_db!);
    await purgeExpiredSyncQueueEntries();
    return _db!;
  }

  static Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        backend_employee_id TEXT,
        model_name TEXT NOT NULL DEFAULT 'legacy',
        embedding TEXT,
        updated_at TEXT NOT NULL
      )
    ''');
    await _createEmbeddingTable(db);
    await _createSyncMetadataTable(db);
    await _createAttendanceSecurityEventTable(db);
    await _createFaceRecognitionAttemptTable(db);
    await db.execute('''
      CREATE TABLE attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        checked_at TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'IN',
        backend_employee_id TEXT,
        face_embedding TEXT,
        face_image_base64 TEXT,
        image_content_type TEXT,
        synced_at TEXT,
        sync_error TEXT
      )
    ''');
    await _createAttendanceLogIndexes(db);
    await _createFaceRecognitionAttemptIndexes(db);
  }

  static Future<void> _ensureSchema(Database db) async {
    await _createEmbeddingTable(db);
    await _createSyncMetadataTable(db);
    await _createAttendanceSecurityEventTable(db);
    await _createFaceRecognitionAttemptTable(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        checked_at TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'IN',
        backend_employee_id TEXT,
        face_embedding TEXT,
        face_image_base64 TEXT,
        image_content_type TEXT,
        synced_at TEXT,
        sync_error TEXT
      )
    ''');
    await _createAttendanceLogIndexes(db);
    await _createFaceRecognitionAttemptIndexes(db);
  }

  static Future<void> _createFaceRecognitionAttemptTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS face_recognition_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        local_attempt_id TEXT UNIQUE,
        model_name TEXT NOT NULL,
        outcome TEXT NOT NULL,
        similarity_score REAL,
        threshold REAL NOT NULL,
        employee_id TEXT,
        employee_name TEXT,
        backend_employee_id TEXT,
        device_id TEXT NOT NULL,
        occurred_at TEXT NOT NULL,
        synced_at TEXT,
        sync_error TEXT
      )
    ''');
    await _createFaceRecognitionAttemptIndexes(db);
  }

  static Future<void> _createAttendanceLogIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_attendance_logs_employee_checked_at
      ON attendance_logs(employee_id, checked_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_attendance_logs_checked_at
      ON attendance_logs(checked_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_attendance_logs_pending_sync
      ON attendance_logs(synced_at, checked_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_attendance_logs_backend_employee
      ON attendance_logs(backend_employee_id, checked_at DESC)
    ''');
  }

  static Future<void> _createFaceRecognitionAttemptIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_face_recognition_attempts_sync
      ON face_recognition_attempts(synced_at, occurred_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_face_recognition_attempts_employee_time
      ON face_recognition_attempts(employee_id, occurred_at DESC)
    ''');
  }

  static Future<void> _createAttendanceSecurityEventTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS attendance_security_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id TEXT NOT NULL,
        reason TEXT NOT NULL,
        detail TEXT,
        occurred_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_attendance_security_events_time
      ON attendance_security_events(device_id, occurred_at)
    ''');
  }

  static Future<void> _createSyncMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _createEmbeddingTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS employee_face_embeddings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        model_name TEXT NOT NULL,
        sample_index INTEGER NOT NULL,
        embedding TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY(employee_id) REFERENCES employees(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_face_embedding_employee_sample
      ON employee_face_embeddings(employee_id, model_name, sample_index)
    ''');
  }

  static Future<void> _migrateLegacyEmbeddings(Database db) async {
    final employeeColumns = await db.rawQuery('PRAGMA table_info(employees)');
    final hasEmbedding = employeeColumns.any(
      (row) => row['name'] == 'embedding',
    );
    if (!hasEmbedding) return;

    final rows = await db.query('employees');
    for (final row in rows) {
      final embedding = row['embedding']?.toString();
      if (embedding == null || embedding.isEmpty) continue;
      await db.insert('employee_face_embeddings', {
        'employee_id': row['id'],
        'model_name': row['model_name']?.toString() ?? 'legacy',
        'sample_index': 0,
        'embedding': embedding,
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  static Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> replaceEmployeeFaceSamples({
    required EnrolledEmployee employee,
    required List<List<double>> embeddings,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      final backendEmployeeId = employee.backendEmployeeId;
      if (backendEmployeeId != null && backendEmployeeId.isNotEmpty) {
        final duplicates = await txn.query(
          'employees',
          columns: ['id'],
          where: 'backend_employee_id = ? AND id <> ?',
          whereArgs: [backendEmployeeId, employee.id],
        );
        for (final duplicate in duplicates) {
          await txn.delete(
            'employee_face_embeddings',
            where: 'employee_id = ?',
            whereArgs: [duplicate['id']],
          );
        }
        await txn.delete(
          'employees',
          where: 'backend_employee_id = ? AND id <> ?',
          whereArgs: [backendEmployeeId, employee.id],
        );
      }

      await txn.insert(
        'employees',
        employee.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'employee_face_embeddings',
        where: 'employee_id = ? AND model_name = ?',
        whereArgs: [employee.id, employee.modelName],
      );

      for (var i = 0; i < embeddings.length; i++) {
        await txn.insert('employee_face_embeddings', {
          'employee_id': employee.id,
          'model_name': employee.modelName,
          'sample_index': i,
          'embedding': jsonEncode(embeddings[i]),
          'created_at': now,
        });
      }
    });
    await _setMetadata('local_face_enrollment_updated_at', now);
  }

  Future<List<EnrolledEmployee>> getEmployees({String? modelName}) async {
    final db = await database;
    final rows = await db.query(
      'employees',
      where: modelName == null ? null : 'model_name = ?',
      whereArgs: modelName == null ? null : [modelName],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(EnrolledEmployee.fromMap).toList(growable: false);
  }

  Future<List<FaceEmbeddingSample>> getFaceSamples({
    required String modelName,
  }) async {
    final db = await database;
    final rows = await db.query(
      'employee_face_embeddings',
      where: 'model_name = ?',
      whereArgs: [modelName],
      orderBy: 'employee_id ASC, sample_index ASC',
    );
    return rows.map(FaceEmbeddingSample.fromMap).toList(growable: false);
  }

  Future<int> countFaceSamples({required String modelName}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) FROM employee_face_embeddings WHERE model_name = ?',
      [modelName],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<FaceMatch?> findBestMatch(
    List<double> probe, {
    required String modelName,
    double threshold = 0.85,
  }) async {
    final best = await findBestCandidate(probe, modelName: modelName);
    if (best == null || best.cosineSimilarity < threshold) return null;
    return best;
  }

  Future<FaceMatch?> findBestCandidate(
    List<double> probe, {
    required String modelName,
  }) async {
    final employees = {
      for (final employee in await getEmployees(modelName: modelName))
        employee.id: employee,
    };
    final samples = await getFaceSamples(modelName: modelName);
    final bestByEmployee = <String, FaceMatch>{};

    for (final sample in samples) {
      final employee = employees[sample.employeeId];
      if (employee == null || sample.embedding.length != probe.length) continue;

      final cosine = _cosineSimilarity(probe, sample.embedding);
      final distance = _euclideanDistance(probe, sample.embedding);
      final match = FaceMatch(
        employee: employee,
        cosineSimilarity: cosine,
        euclideanDistance: distance,
      );
      final current = bestByEmployee[employee.id];
      if (current == null || cosine > current.cosineSimilarity) {
        bestByEmployee[employee.id] = match;
      }
    }

    if (bestByEmployee.isEmpty) return null;
    return bestByEmployee.values.reduce(
      (a, b) => a.cosineSimilarity >= b.cosineSimilarity ? a : b,
    );
  }

  Future<void> recordFaceRecognitionAttempt({
    required String modelName,
    required String outcome,
    required double? similarityScore,
    required double threshold,
    FaceMatch? candidate,
    String deviceId = 'flutter-mobile-offline-face',
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc();
    final id = await db.insert('face_recognition_attempts', {
      'model_name': modelName,
      'outcome': outcome,
      'similarity_score': similarityScore,
      'threshold': threshold,
      'employee_id': candidate?.employee.id,
      'employee_name': candidate?.employee.name,
      'backend_employee_id': candidate?.employee.backendEmployeeId,
      'device_id': deviceId,
      'occurred_at': now.toIso8601String(),
    });
    await db.update(
      'face_recognition_attempts',
      {'local_attempt_id': id.toString()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<FaceMatch?> findDuplicateEnrollment(
    List<double> probe, {
    required String employeeId,
    required String modelName,
    String? backendEmployeeId,
    double threshold = 0.90,
  }) async {
    final employees = {
      for (final employee in await getEmployees(modelName: modelName))
        employee.id: employee,
    };
    final samples = await getFaceSamples(modelName: modelName);
    FaceMatch? best;

    for (final sample in samples) {
      final employee = employees[sample.employeeId];
      if (employee == null) continue;
      final sameLocalEmployee = employee.id == employeeId;
      final sameBackendEmployee =
          backendEmployeeId != null &&
          backendEmployeeId.isNotEmpty &&
          employee.backendEmployeeId == backendEmployeeId;
      if (sameLocalEmployee || sameBackendEmployee) continue;
      if (sample.embedding.length != probe.length) continue;

      final cosine = _cosineSimilarity(probe, sample.embedding);
      final distance = _euclideanDistance(probe, sample.embedding);
      final match = FaceMatch(
        employee: employee,
        cosineSimilarity: cosine,
        euclideanDistance: distance,
      );
      if (best == null || match.cosineSimilarity > best.cosineSimilarity) {
        best = match;
      }
    }

    if (best == null || best.cosineSimilarity < threshold) return null;
    return best;
  }

  Future<int> insertAttendanceLog(
    FaceMatch match, {
    List<double>? faceEmbedding,
    String? faceImageBase64,
    String? imageContentType,
  }) async {
    final db = await database;
    final type = await _nextAttendanceType(match.employee.id);
    return db.insert(
      'attendance_logs',
      AttendanceLog(
        employeeId: match.employee.id,
        employeeName: match.employee.name,
        confidence: match.cosineSimilarity,
        checkedAt: DateTime.now(),
        type: type,
        backendEmployeeId: match.employee.backendEmployeeId,
        faceEmbedding: faceEmbedding,
        faceImageBase64: faceImageBase64,
        imageContentType: imageContentType,
      ).toMap(),
    );
  }

  Future<String> _nextAttendanceType(String employeeId) async {
    final db = await database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day).toIso8601String();
    final rows = await db.query(
      'attendance_logs',
      columns: ['type'],
      where: 'employee_id = ? AND checked_at >= ?',
      whereArgs: [employeeId, dayStart],
      orderBy: 'checked_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return 'IN';
    return rows.first['type'] == 'IN' ? 'OUT' : 'IN';
  }

  Future<List<AttendanceLog>> getRecentAttendanceLogs({int limit = 20}) async {
    final db = await database;
    final rows = await db.query(
      'attendance_logs',
      orderBy: 'checked_at DESC',
      limit: limit,
    );
    return rows.map(AttendanceLog.fromMap).toList(growable: false);
  }

  Future<int> countAttendanceLogs() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM attendance_logs',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<String?> getLatestPendingSyncError() async {
    final db = await database;
    final rows = await db.query(
      'attendance_logs',
      columns: ['sync_error'],
      where: 'synced_at IS NULL AND sync_error IS NOT NULL',
      orderBy: 'checked_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sync_error']?.toString();
  }

  Future<String?> getLatestPendingServerRejection() async {
    final db = await database;
    final rows = await db.query(
      'attendance_logs',
      columns: ['sync_error'],
      where: "sync_error LIKE 'Server rejected:%'",
      orderBy: 'checked_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['sync_error']?.toString();
  }

  Future<int> syncPendingAttendanceLogs({required ApiClient api}) async {
    _lastNearbyDuplicateSkips = 0;
    final db = await database;
    await purgeExpiredBiometricQueueData();
    final pending = await db.query(
      'attendance_logs',
      where: 'synced_at IS NULL',
      orderBy: 'checked_at ASC',
    );
    return _syncPendingAttendanceLogsBatch(db, pending, api);
    /*
    var synced = 0;

    for (final row in pending) {
      final log = AttendanceLog.fromMap(row);
      try {
        if (log.backendEmployeeId == null || log.backendEmployeeId!.isEmpty) {
          throw const FormatException('Thiếu backend employee id');
        }

        if (log.backendEmployeeId == currentUserId) {
          await api.post(
            '/api/v1/attendance/check',
            body: {
              'deviceId': 'flutter-mobile-offline-face',
              'note':
                  'Chấm công bằng khuôn mặt trên thiết bị di động (${log.type})',
            },
          );
        } else {
          await api.post(
            '/api/v1/attendance/manual',
            body: {
              'employeeId': log.backendEmployeeId,
              'type': log.type,
              'checkTime': log.checkedAt.toUtc().toIso8601String(),
              'note': 'Chấm công bằng khuôn mặt trên thiết bị di động',
            },
          );
        }

        await db.update(
          'attendance_logs',
          {'synced_at': DateTime.now().toIso8601String(), 'sync_error': null},
          where: 'id = ?',
          whereArgs: [log.id],
        );
        synced++;
      } catch (error) {
        await db.update(
          'attendance_logs',
          {'sync_error': error.toString()},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      }
    }
    return synced;
    */
  }

  Future<int> syncPendingFaceRecognitionAttempts({
    required ApiClient api,
  }) async {
    final db = await database;
    final pending = await db.query(
      'face_recognition_attempts',
      where: 'synced_at IS NULL',
      orderBy: 'occurred_at ASC',
      limit: 100,
    );
    if (pending.isEmpty) return 0;

    final attempts = pending
        .map(FaceRecognitionAttempt.fromMap)
        .toList(growable: false);
    try {
      await api.post(
        '/api/v1/attendance/recognition-logs/batch',
        body: {'logs': attempts.map(_faceRecognitionAttemptToJson).toList()},
      );
      final now = DateTime.now().toUtc().toIso8601String();
      for (final attempt in attempts) {
        await db.update(
          'face_recognition_attempts',
          {'synced_at': now, 'sync_error': null},
          where: 'id = ?',
          whereArgs: [attempt.id],
        );
      }
      await purgeExpiredSyncQueueEntries();
      return attempts.length;
    } catch (error) {
      for (final attempt in attempts) {
        await db.update(
          'face_recognition_attempts',
          {'sync_error': 'Sync failed: $error'},
          where: 'id = ?',
          whereArgs: [attempt.id],
        );
      }
      await purgeExpiredSyncQueueEntries();
      return 0;
    }
  }

  Future<int> purgeExpiredSyncQueueEntries({
    Duration maxAge = syncQueueRetention,
  }) async {
    final db = await database;
    final cutoff = DateTime.now().toUtc().subtract(maxAge).toIso8601String();
    final deletedAttendance = await db.delete(
      'attendance_logs',
      where: '''
        checked_at < ?
        AND (
          synced_at IS NOT NULL
          OR sync_error LIKE 'Server rejected:%'
          OR sync_error = 'Duplicate nearby attendance'
          OR sync_error = 'Missing backend employee id'
          OR sync_error = 'Expired biometric queue data purged'
        )
      ''',
      whereArgs: [cutoff],
    );
    final deletedRecognition = await db.delete(
      'face_recognition_attempts',
      where: '''
        occurred_at < ?
        AND (synced_at IS NOT NULL OR sync_error IS NOT NULL)
      ''',
      whereArgs: [cutoff],
    );
    return deletedAttendance + deletedRecognition;
  }

  Future<int> _syncPendingAttendanceLogsBatch(
    Database db,
    List<Map<String, Object?>> pending,
    ApiClient api,
  ) async {
    final logs = pending.map(AttendanceLog.fromMap).toList(growable: false);
    final readyLogs = <AttendanceLog>[];
    for (final log in logs) {
      if (log.backendEmployeeId == null || log.backendEmployeeId!.isEmpty) {
        await db.update(
          'attendance_logs',
          {'sync_error': 'Missing backend employee id'},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      } else {
        readyLogs.add(log);
      }
    }
    if (readyLogs.isEmpty) return 0;

    try {
      final response = await api.post(
        '/api/v1/attendance/sync',
        body: {'logs': readyLogs.map(_attendanceLogToSyncJson).toList()},
      );
      final results = response is Map<String, dynamic>
          ? response['results']
          : null;
      if (results is! List) return 0;

      var synced = 0;
      final logsBySyncId = {for (final log in readyLogs) _syncLogId(log): log};
      for (final result in results) {
        if (result is! Map<String, dynamic>) continue;
        final localLogId = result['localLogId']?.toString();
        final status = result['status']?.toString();
        final message = result['message']?.toString() ?? '';
        final log = logsBySyncId[localLogId];
        if (log == null) continue;

        if (status == 'SYNCED' ||
            (status == 'SKIPPED' && message == 'Duplicate device log')) {
          await db.update(
            'attendance_logs',
            {
              'synced_at': DateTime.now().toIso8601String(),
              'sync_error': null,
              'face_image_base64': null,
              'face_embedding': null,
            },
            where: 'id = ?',
            whereArgs: [log.id],
          );
          synced++;
        } else if (status == 'SKIPPED' &&
            message == 'Duplicate employee timestamp within 2 minutes') {
          await db.update(
            'attendance_logs',
            {
              'synced_at': DateTime.now().toIso8601String(),
              'sync_error': 'Duplicate nearby attendance',
              'face_image_base64': null,
              'face_embedding': null,
            },
            where: 'id = ?',
            whereArgs: [log.id],
          );
          _lastNearbyDuplicateSkips++;
        } else {
          await db.update(
            'attendance_logs',
            {
              'synced_at': DateTime.now().toIso8601String(),
              'sync_error':
                  'Server rejected: ${message.isNotEmpty ? message : 'Face verification failed'}',
              'face_image_base64': null,
              'face_embedding': null,
            },
            where: 'id = ?',
            whereArgs: [log.id],
          );
        }
      }
      await purgeExpiredSyncQueueEntries();
      return synced;
    } catch (error) {
      for (final log in readyLogs) {
        await db.update(
          'attendance_logs',
          {'sync_error': 'Sync failed: $error'},
          where: 'id = ?',
          whereArgs: [log.id],
        );
      }
      await purgeExpiredSyncQueueEntries();
      return 0;
    }
  }

  Future<int> purgeExpiredBiometricQueueData({
    Duration maxAge = biometricQueueRetention,
  }) async {
    final db = await database;
    final cutoff = DateTime.now().subtract(maxAge).toIso8601String();
    return db.update(
      'attendance_logs',
      {
        'face_image_base64': null,
        'face_embedding': null,
        'sync_error': 'Expired biometric queue data purged',
      },
      where:
          'synced_at IS NULL AND checked_at < ? AND (face_image_base64 IS NOT NULL OR face_embedding IS NOT NULL)',
      whereArgs: [cutoff],
    );
  }

  Map<String, Object?> _attendanceLogToSyncJson(AttendanceLog log) {
    return {
      'localLogId': _syncLogId(log),
      'employeeId': log.backendEmployeeId,
      'type': log.type,
      'checkTime': log.checkedAt.toUtc().toIso8601String(),
      'mobileCheckTime': log.checkedAt.toUtc().toIso8601String(),
      'confidenceScore': log.confidence,
      'faceEmbedding': log.faceEmbedding,
      'faceImageBase64': log.faceImageBase64,
      'imageContentType': log.imageContentType ?? 'image/jpeg',
      'deviceId': 'flutter-mobile-offline-face',
      'note': 'Offline face attendance (${log.type})',
    };
  }

  String _syncLogId(AttendanceLog log) {
    return [
      'flutter-mobile-offline-face',
      log.employeeId,
      log.id ?? 0,
      log.checkedAt.microsecondsSinceEpoch,
    ].join(':');
  }

  Map<String, Object?> _faceRecognitionAttemptToJson(
    FaceRecognitionAttempt attempt,
  ) {
    return {
      'localAttemptId': attempt.localAttemptId ?? attempt.id?.toString(),
      'modelName': attempt.modelName,
      'outcome': attempt.outcome,
      'similarityScore': attempt.similarityScore,
      'threshold': attempt.threshold,
      'employeeId': attempt.backendEmployeeId,
      'localEmployeeId': attempt.employeeId,
      'employeeName': attempt.employeeName,
      'deviceId': attempt.deviceId,
      'occurredAt': attempt.occurredAt.toUtc().toIso8601String(),
    };
  }

  Future<bool> isEmbeddingSyncExpired({
    Duration maxAge = embeddingMaxOfflineAge,
  }) async {
    final lastSync =
        await _getMetadataDateTime('embedding_last_sync_at') ??
        await _getMetadataDateTime('local_face_enrollment_updated_at') ??
        await _getLatestFaceSampleCreatedAt();
    if (lastSync == null) return true;
    return DateTime.now().toUtc().difference(lastSync.toUtc()) > maxAge;
  }

  Future<DateTime?> _getLatestFaceSampleCreatedAt() async {
    final db = await database;
    final rows = await db.query(
      'employee_face_embeddings',
      columns: ['created_at'],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = rows.first['created_at']?.toString();
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<String?> _getMetadata(String key) async {
    final db = await database;
    final rows = await db.query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  Future<DateTime?> _getMetadataDateTime(String key) async {
    final value = await _getMetadata(key);
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  Future<void> _setMetadata(String key, String value) async {
    final db = await database;
    await db.insert('sync_metadata', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _markEmbeddingSyncFresh({
    required String version,
    required String checksum,
  }) async {
    await _setMetadata('embedding_version', version);
    await _setMetadata('embedding_checksum', checksum);
    await _setMetadata(
      'embedding_last_sync_at',
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> removeEmployeesByBackendIds(
    List<String> backendEmployeeIds,
  ) async {
    if (backendEmployeeIds.isEmpty) return;
    final db = await database;
    await db.transaction((txn) async {
      for (final backendEmployeeId in backendEmployeeIds) {
        final rows = await txn.query(
          'employees',
          columns: ['id'],
          where: 'backend_employee_id = ?',
          whereArgs: [backendEmployeeId],
        );
        for (final row in rows) {
          await txn.delete(
            'employee_face_embeddings',
            where: 'employee_id = ?',
            whereArgs: [row['id']],
          );
        }
        await txn.delete(
          'employees',
          where: 'backend_employee_id = ?',
          whereArgs: [backendEmployeeId],
        );
      }
    });
  }

  Future<int> syncEmployeeEmbeddingsFromServer({required ApiClient api}) async {
    final metadata = await api.get('/api/v1/employees/embeddings/meta');
    if (metadata is! Map<String, dynamic>) return 0;

    final serverVersion = metadata['version']?.toString();
    final serverChecksum = metadata['checksum']?.toString();
    final serverThreshold = (metadata['matchThreshold'] as num?)?.toDouble();
    if (serverVersion == null ||
        serverVersion.isEmpty ||
        serverChecksum == null ||
        serverChecksum.isEmpty) {
      return 0;
    }

    final localVersion = await _getMetadata('embedding_version');
    final localChecksum = await _getMetadata('embedding_checksum');
    if (localVersion == serverVersion && localChecksum == serverChecksum) {
      if (serverThreshold != null) {
        await saveFaceMatchThreshold(serverThreshold);
      }
      await _markEmbeddingSyncFresh(
        version: serverVersion,
        checksum: serverChecksum,
      );
      return 0;
    }

    final response = await api.get(
      '/api/v1/employees/embeddings/changes',
      queryParameters: {
        if (localVersion != null && localVersion.isNotEmpty)
          'since': localVersion,
      },
    );
    if (response is! Map<String, dynamic>) return 0;

    final changed = response['changed'];
    final removed = response['removedEmployeeIds'];
    final deltaThreshold = (response['matchThreshold'] as num?)?.toDouble();
    if (deltaThreshold != null) {
      await saveFaceMatchThreshold(deltaThreshold);
    } else if (serverThreshold != null) {
      await saveFaceMatchThreshold(serverThreshold);
    }
    if (removed is List) {
      await removeEmployeesByBackendIds(
        removed.map((id) => id.toString()).toList(growable: false),
      );
    }
    if (changed is! List) {
      await _markEmbeddingSyncFresh(
        version: serverVersion,
        checksum: serverChecksum,
      );
      return 0;
    }

    var imported = 0;
    for (final item in changed) {
      if (item is! Map<String, dynamic>) continue;
      final backendEmployeeId = item['employeeId']?.toString();
      final name = item['fullName']?.toString();
      final employeeCode = item['employeeCode']?.toString();
      final embeddingText = item['embedding']?.toString();
      final modelName = item['modelName']?.toString() ?? 'face-embedding';
      if (backendEmployeeId == null ||
          backendEmployeeId.isEmpty ||
          name == null ||
          name.isEmpty ||
          embeddingText == null ||
          embeddingText.isEmpty) {
        continue;
      }

      final embedding = _decodeEmbedding(embeddingText);
      if (embedding.isEmpty) continue;

      await replaceEmployeeFaceSamples(
        employee: EnrolledEmployee(
          id: employeeCode?.isNotEmpty == true
              ? employeeCode!
              : backendEmployeeId,
          name: name,
          backendEmployeeId: backendEmployeeId,
          modelName: modelName,
        ),
        embeddings: [embedding],
      );
      imported++;
    }
    await _markEmbeddingSyncFresh(
      version: serverVersion,
      checksum: serverChecksum,
    );
    return imported;
  }

  List<double> _decodeEmbedding(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((x) => (x as num).toDouble()).toList(growable: false);
    }
    if (decoded is Map && decoded['embedding'] is List) {
      return (decoded['embedding'] as List)
          .map((x) => (x as num).toDouble())
          .toList(growable: false);
    }
    return const [];
  }

  double _cosineSimilarity(List<double> a, List<double> b) {
    var dot = 0.0;
    var normA = 0.0;
    var normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return -1;
    return dot / denominator;
  }

  double _euclideanDistance(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
