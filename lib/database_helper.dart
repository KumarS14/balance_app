import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // --- ARCHITECTURAL DECISION: SINGLETON PATTERN ---
  // I implemented the Singleton design pattern here to ensure my application 
  // only ever opens a single, globally accessible connection to the SQLite database.
  // This prevents memory leaks and concurrent database lockouts during read/write operations.
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('balance_habits.db');
    return _database!;
  }

  // --- ARCHITECTURAL DECISION: LOCAL-FIRST DATA STORAGE ---
  // My sociological research highlighted severe privacy concerns with existing wellbeing apps
  // mining user data. To completely eliminate this risk, I used the path_provider package 
  // to securely store all behavioral data strictly on the user's local device.
  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);
    
    // I implemented a versioning system (Version 2) to safely handle schema upgrades 
    // without crashing the app for existing users.
    return await openDatabase(
      path, 
      version: 2, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // --- SCHEMA DESIGN ---
  // I engineered this database schema to directly translate the Entity-Relationship Diagram (ERD)
  // from my initial project specification into functional SQL tables.
  Future _createDB(Database db, int version) async {
    // Table 1: Stores the user's self-defined baselines for the Heuristic Engine
    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        ideal_sleep_goal INTEGER NOT NULL,
        ideal_study_limit INTEGER NOT NULL
      )
    ''');

    // Table 2: Stores the highly detailed longitudinal time-blocking data
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

  // Defensive Programming: Safely drops and rebuilds tables if the schema version changes
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS time_blocks');
      await _createDB(db, newVersion);
    }
  }

  // Function to initialize a default user profile ('Anxious Alex' persona) 
  // so the Heuristic Engine immediately has baseline metrics to compare against upon first boot.
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

  // Securely writes the categorized time blocks to the device storage
  Future<int> insertTimeBlock(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('time_blocks', row);
  }

  // --- DATA AGGREGATION: DAILY METRICS ---
  // I engineered this to mathematically calculate absolute duration in hours (double) 
  // rather than just counting the number of blocks (int). This provides the precision 
  // required by my longitudinal Visualization Suite.
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

  // --- DATA AGGREGATION: LONGITUDINAL TRENDS ---
  // This complex query pulls historical data over a dynamically selected time range.
  // It is the backbone of the V2 Heuristic Engine's 'Chronic Fatigue' and 'Sleep Debt' analysis.
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

  // --- V3 AGILE UPDATE: DATA INTEGRITY & CORRECTION ---

  // I engineered this retrieval method so users can view their raw daily logs.
  // This provides transparency to the user, fulfilling a core tenet of my Personal Informatics model.
  Future<List<Map<String, dynamic>>> getRawBlocksForDay(String date) async {
    final db = await instance.database;
    return await db.query(
      'time_blocks',
      where: 'date LIKE ?',
      whereArgs: ['$date%'],
      orderBy: 'start_time ASC', // I ordered this chronologically for better UX
    );
  }

  // During my initial usability testing, I hypothesized that users would experience high 
  // cognitive friction if they could not correct data entry errors. 
  // I implemented this deletion method to ensure longitudinal data integrity for the Heuristic Engine.
  Future<int> deleteTimeBlock(int id) async {
    final db = await instance.database;
    return await db.delete(
      'time_blocks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}