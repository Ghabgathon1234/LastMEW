import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'shift_manager.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE year (
            year INTEGER PRIMARY KEY,
            delay INTEGER DEFAULT 0,
            workedDays INTEGER DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE month (
            year INTEGER,
            month INTEGER,
            monthlyDelay INTEGER DEFAULT 0,
            PRIMARY KEY (year, month),
            FOREIGN KEY (year) REFERENCES year(year)
          )
        ''');

        await db.execute('''
          CREATE TABLE day (
            year INTEGER,
            month INTEGER,
            day INTEGER,
            status TEXT,
            shift TEXT,
            attend1 TIME,
            attend2 TIME,
            attend3 TIME,
            leave1 TIME,
            leave2 TIME,
            delayMinutes INTEGER DEFAULT 0,
            PRIMARY KEY (year, month, day),
            FOREIGN KEY (year) REFERENCES year(year),
            FOREIGN KEY (month) REFERENCES month(month)
          )
        ''');
      },
    );
  }

  Future<List<DayRecord>> getDayRecordsForRange(
      DateTime start, DateTime end) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query(
      'day',
      where: 'year || "-" || month || "-" || day BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );

    return results.map((map) => DayRecord.fromMap(map)).toList();
  }

  // Year Table Methods

  Future<void> insertOrUpdateYearRecord(
      int year, int delay, int workedDays) async {
    final db = await database;

    await db.insert(
      'year',
      {
        'year': year,
        'delay': delay,
        'workedDays': workedDays,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateYearRecord(int year, int delay, int workedDays) async {
    final db = await database;

    await db.update(
      'year',
      {
        'delay': delay,
        'workedDays': workedDays,
      },
      where: 'year = ?',
      whereArgs: [year],
    );
  }

  Future<YearRecord?> getYearRecord(int year) async {
    final db = await database;

    // Query the 'year' table to fetch the record for the given year
    List<Map<String, dynamic>> maps = await db.query(
      'year',
      where: 'year = ?',
      whereArgs: [year],
    );

    // If the record exists, return it as a YearRecord, otherwise return null
    if (maps.isNotEmpty) {
      return YearRecord.fromMap(maps.first);
    }
    return null; // Return null if no record is found for the specified year
  }

  Future<List<Map<String, dynamic>>> getAllYearRecords() async {
    final db = await database;

    // Fetch all year records from the 'year' table
    return await db.query('year');
  }

  // Month Table Methods

  Future<void> insertOrUpdateMonthRecord(
      int year, int month, int monthlyDelay) async {
    final db = await database;

    await db.insert(
      'month',
      {
        'year': year,
        'month': month,
        'monthlyDelay': monthlyDelay,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateMonthRecord(int year, int month, int monthlyDelay) async {
    final db = await database;

    await db.update(
      'month',
      {
        'monthlyDelay': monthlyDelay,
      },
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
  }

  Future<List<DayRecord>> getAllRecordsForDate(
      int year, int month, int day) async {
    final db = await database;
    List<Map<String, dynamic>> results = await db.query('dayRecords',
        where: 'year = ? AND month = ? AND day = ?',
        whereArgs: [year, month, day]);
    return List.generate(results.length, (i) {
      return DayRecord.fromMap(results[i]);
    });
  }

  Future<int?> getMonthlyDelay(int year, int month) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'month',
      columns: ['monthlyDelay'], // Only fetch the monthlyDelay column
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );

    if (maps.isNotEmpty) {
      return maps.first['monthlyDelay'] as int; // Return the monthlyDelay
    }
    return null; // Return null if no record is found
  }

  Future<MonthRecord?> getMonthRecord(int year, int month) async{
    final db = await database;
    List<Map<String,dynamic>> maps = await db.query(
      'month',
      where: 'year = ? AND month = ?',
      whereArgs: [year,month],
    );

    if (maps.isNotEmpty){
      return MonthRecord.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getMonthRecordsForYear(int year) async {
    final db = await database;

    // Fetch all month records for the given year
    return await db.query(
      'month', // The table to query from
      where: 'year = ?', // Filter condition
      whereArgs: [year], // Argument for the filter (the provided year)
    );
  }

  // Day Table Methods

  Future<void> insertOrUpdateDayRecord(DayRecord dayRecord) async {
    final db = await database;

    await db.insert(
      'day',
      dayRecord.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDayRecord(
    int year,
    int month,
    int day, {
    String? status,
    String? shift,
    String? attend1,
    String? attend2,
    String? attend3,
    String? leave1,
    String? leave2,
    int? delayMinutes,
  }) async {
    final db = await database;

    Map<String, dynamic> updates = {};

    if (status != null) updates['status'] = status;
    if (shift != null) updates['shift'] = shift;
    if (attend1 != null) updates['attend1'] = attend1;
    if (attend2 != null) updates['attend2'] = attend2;
    if (attend3 != null) updates['attend3'] = attend3;
    if (leave1 != null) updates['leave1'] = leave1;
    if (leave2 != null) updates['leave2'] = leave2;
    if (delayMinutes != null) updates['delayMinutes'] = delayMinutes;

    await db.update(
      'day',
      updates,
      where: 'year = ? AND month = ? AND day = ?',
      whereArgs: [year, month, day],
    );
  }

  Future<DayRecord?> getDayRecord(int year, int month, int day) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'day',
      where: 'year = ? AND month = ? AND day = ?',
      whereArgs: [year, month, day],
    );

    if (maps.isNotEmpty) {
      return DayRecord.fromMap(maps.first);
    }
    return null;
  }
}

// Helper Models

class YearRecord {
  final int year;
  int delay;
  int workedDays;

  YearRecord({
    required this.year,
    required this.delay,
    required this.workedDays,
  });

  // Convert a YearRecord into a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'delay': delay,
      'workedDays': workedDays,
    };
  }

  // Convert a Map into a YearRecord
  static YearRecord fromMap(Map<String, dynamic> map) {
    return YearRecord(
      year: map['year'],
      delay: map['delay'],
      workedDays: map['workedDays'],
    );
  }
}

class MonthRecord {
  final int year;
  final int month;
  int monthlyDelay;

  MonthRecord({
    required this.year,
    required this.month,
    required this.monthlyDelay,
  });

  // Convert a MonthRecord into a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'monthlyDelay': monthlyDelay,
    };
  }

  // Convert a Map into a MonthRecord
  static MonthRecord fromMap(Map<String, dynamic> map) {
    return MonthRecord(
      year: map['year'],
      month: map['month'],
      monthlyDelay: map['monthlyDelay'],
    );
  }
}

class DayRecord {
  final int year;
  final int month;
  final int day;
  String? status;
  String? shift;
  String? attend1;
  String? attend2;
  String? attend3;
  String? leave1;
  String? leave2;
  int delayMinutes;

  DayRecord({
    required this.year,
    required this.month,
    required this.day,
    this.status,
    this.shift,
    this.attend1,
    this.attend2,
    this.attend3,
    this.leave1,
    this.leave2,
    required this.delayMinutes,
  });

  // Convert a DayRecord into a Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'day': day,
      'status': status,
      'shift': shift,
      'attend1': attend1,
      'attend2': attend2,
      'attend3': attend3,
      'leave1': leave1,
      'leave2': leave2,
      'delayMinutes': delayMinutes,
    };
  }

  // Convert a Map into a DayRecord
  static DayRecord fromMap(Map<String, dynamic> map) {
    return DayRecord(
      year: map['year'],
      month: map['month'],
      day: map['day'],
      shift: map['shift'],
      status: map['status'],
      attend1: map['attend1'],
      attend2: map['attend2'],
      attend3: map['attend3'],
      leave1: map['leave1'],
      leave2: map['leave2'],
      delayMinutes: map['delayMinutes'],
    );
  }
}
