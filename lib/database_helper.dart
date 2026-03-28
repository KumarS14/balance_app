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
  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);
    
    // Version 2 to handle the schema upgrade required by my ERD
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // I created this database schema based exactly on the ERD diagram in my design specification.
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ideal_sleep_goal INTEGER NOT NULL,
        ideal_study_limit INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE time_blocks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL, 
        end_time TEXT NOT NULL,
        is_productive INTEGER NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS time_blocks');
      await _createDB(db, newVersion);
    }
  }

  // Function to initialize a default user profile (Anxious Alex) for the Heuristic Engine
  Future<void> initializeDefaultUser() async {
    final db = await instance.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM users'));
    if (count == 0) {
      await db.insert('users', {
        'name': 'Student',
        'ideal_sleep_goal': 8, 
        'ideal_study_limit': 6, 
      });
    }
  }

  Future<int> insertTimeBlock(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('time_blocks', row);
  }

  // Updated to calculate TOTAL HOURS (double) rather than counting blocks (int)
  Future<Map<String, double>> getDailyStats(String date) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_blocks',
      where: 'date LIKE ?',
      whereArgs: ['$date%'], 
    );

    double studyHours = 0;
    double sleepHours = 0;
    double leisureHours = 0;

    for (var row in maps) {
      DateTime start = DateTime.parse(row['start_time']);
      DateTime end = DateTime.parse(row['end_time']);
      double durationInHours = end.difference(start).inMinutes / 60.0;

      if (row['category'] == 'Study') studyHours += durationInHours;
      if (row['category'] == 'Sleep') sleepHours += durationInHours;
      if (row['category'] == 'Leisure') leisureHours += durationInHours;
    }

    return {'Study': studyHours, 'Sleep': sleepHours, 'Leisure': leisureHours};
  }

  // New function to pull historical data over a specific time range for the Trend Graph
  Future<Map<String, Map<String, double>>> getStatsForDateRange(DateTime startDate, DateTime endDate) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'time_blocks',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate.toIso8601String().split('T')[0], endDate.toIso8601String().split('T')[0]], 
    );

    Map<String, Map<String, double>> rangeStats = {};

    for (var row in maps) {
      String date = row['date'];
      if (!rangeStats.containsKey(date)) {
        rangeStats[date] = {'Study': 0, 'Sleep': 0, 'Leisure': 0};
      }

      DateTime start = DateTime.parse(row['start_time']);
      DateTime end = DateTime.parse(row['end_time']);
      double duration = end.difference(start).inMinutes / 60.0;

      if (row['category'] == 'Study') rangeStats[date]!['Study'] = rangeStats[date]!['Study']! + duration;
      if (row['category'] == 'Sleep') rangeStats[date]!['Sleep'] = rangeStats[date]!['Sleep']! + duration;
      if (row['category'] == 'Leisure') rangeStats[date]!['Leisure'] = rangeStats[date]!['Leisure']! + duration;
    }

    return rangeStats;
  }
}