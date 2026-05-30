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

class DatabaseService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'offline_face_attendance.db');
    _db = await openDatabase(
      path,
      version: 4,
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
      },
    );
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
    await db.execute('''
      CREATE TABLE attendance_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        employee_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        checked_at TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'IN',
        backend_employee_id TEXT,
        synced_at TEXT,
        sync_error TEXT
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
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    });
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

  Future<FaceMatch?> findBestMatch(
    List<double> probe, {
    required String modelName,
    double threshold = 0.85,
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
    final best = bestByEmployee.values.reduce(
      (a, b) => a.cosineSimilarity >= b.cosineSimilarity ? a : b,
    );
    if (best.cosineSimilarity < threshold) return null;
    return best;
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

  Future<int> insertAttendanceLog(FaceMatch match) async {
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

  Future<int> syncPendingAttendanceLogs({
    required ApiClient api,
    required String? currentUserId,
  }) async {
    final db = await database;
    final pending = await db.query(
      'attendance_logs',
      where: 'synced_at IS NULL',
      orderBy: 'checked_at ASC',
    );
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
