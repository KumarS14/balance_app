import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // I implemented a Singleton pattern here so my app only opens one database connection at a time.
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('balance_habits.db');
    return _database!;
  }

  // I used the path_provider package here to solve the technical challenge of cross-platform local storage.
  // This ensures the SQLite database is saved securely on the user's specific device,
  // directly fulfilling the 'Privacy-First' requirement of my FYP.
  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // I created this database schema based exactly on the ERD diagram in my design specification.
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE time_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        is_productive INTEGER NOT NULL
      )
    ''');
  }

  // My function to securely save the user's categorized time blocks locally.
  Future<int> insertTimeBlock(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('time_blocks', row);
  }

  // I wrote this new function to aggregate the saved daily data so I can feed it 
  // into my fl_chart UI, fulfilling the 'Reflection' stage of the Personal Informatics model.
  Future<Map<String, int>> getDailyStats(String date) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_blocks',
      where: 'date LIKE ?',
      whereArgs: ['$date%'], 
    );

    int studyCount = 0;
    int sleepCount = 0;
    int leisureCount = 0;

    for (var row in maps) {
      if (row['category'] == 'Study') studyCount++;
      if (row['category'] == 'Sleep') sleepCount++;
      if (row['category'] == 'Leisure') leisureCount++;
    }

    return {'Study': studyCount, 'Sleep': sleepCount, 'Leisure': leisureCount};
  }
}