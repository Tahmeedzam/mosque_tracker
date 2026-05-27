import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabaseService {
  static Database? _db;
  static final LocalDatabaseService instance =
      LocalDatabaseService._constructor();

  final String _inMosqueTableName = "inmosque";
  final String _inMosqueStatusColumn = "mosquestatus";

  final String _pendingMosqueTable = "pending_mosque";
  final String _pendingMosqueId = "mosque_id";
  final String _pendingMosqueName = "mosque_name";
  final String _pendingMosqueTime = "triggered_at";

  LocalDatabaseService._constructor();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await getDatabase();
    return _db!;
  }

  Future<Database> getDatabase() async {
    final databaseDirPath = await getDatabasesPath();
    final databasePath = join(databaseDirPath, "mosque_status.db");

    final database = await openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) async {
        db.execute('''
        CREATE TABLE $_inMosqueTableName (
          $_inMosqueStatusColumn INTEGER DEFAULT 0
        )
        ''');
        await db.insert(_inMosqueTableName, {_inMosqueStatusColumn: 0});

        await db.execute('''
          CREATE TABLE $_pendingMosqueTable (
          $_pendingMosqueId TEXT,
          $_pendingMosqueName TEXT,
          $_pendingMosqueTime TEXT 
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
        CREATE TABLE IF NOT EXISTS $_pendingMosqueTable (
          $_pendingMosqueId TEXT,
          $_pendingMosqueName TEXT,
          $_pendingMosqueTime TEXT
        )
      ''');
        }
      },
    );
    return database;
  }

  void updateStatus() async {
    final db = await database;
    final data = await db.query(_inMosqueTableName);

    if (data.isEmpty) return;
    final status = data.first[_inMosqueStatusColumn] as int;
    final newStatus = status == 1 ? 0 : 1;

    await db.update(_inMosqueTableName, {_inMosqueStatusColumn: newStatus});

    print("Status updated: $status → $newStatus");
  }

  Future<int> getCurrentStatus() async {
    final db = await database;
    final data = await db.query(_inMosqueTableName);
    if (data.isEmpty) {
      // Insert default row and return 0
      await db.insert(_inMosqueTableName, {_inMosqueStatusColumn: 0});
      return 0;
    }
    final status = data.first[_inMosqueStatusColumn] as int;

    print("Current Status: $status");
    return status;
  }

  Future<void> savePendingMosque(String mosqueId, String mosqueName) async {
    final db = await database;
    await db.delete(_pendingMosqueTable); // only one pending at a time
    await db.insert(_pendingMosqueTable, {
      _pendingMosqueId: mosqueId,
      _pendingMosqueName: mosqueName,
      _pendingMosqueTime: DateTime.now().toIso8601String(),
    });
    print("Pending mosque saved: $mosqueName");
  }

  Future<Map<String, dynamic>?> getPendingMosque() async {
    final db = await database;
    final data = await db.query(_pendingMosqueTable);
    if (data.isEmpty) return null;
    return data.first;
  }

  Future<void> clearPendingMosque() async {
    final db = await database;
    await db.delete(_pendingMosqueTable);
  }
}
