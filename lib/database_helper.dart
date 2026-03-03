import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  // Implementing a Singleton pattern so only one database connection exists at a time
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('balance_habits.db');
    return _database!;
  }

  // I used path_provider here to solve the challenge of cross-platform local storage.
  // This ensures the database is saved securely on the user's specific device,
  // fulfilling my 'Privacy-First' requirement.
  Future<Database> _initDB(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final path = join(dbFolder.path, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // Creating the schema based on the ERD diagram in my design specification
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

  // Function to save the user's categorized time blocks locally
  Future<int> insertTimeBlock(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('time_blocks', row);
  }
}