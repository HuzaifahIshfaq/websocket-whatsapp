import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  DBHelper._internal();

  factory DBHelper() {
    return _instance;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'chat_rooms.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rooms (
        roomId INTEGER PRIMARY KEY,   
        username TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertRoom(int roomId, String username) async {
    final db = await database;
    await db.insert(
      'rooms',
      {'roomId': roomId, 'username': username},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRooms() async {
    final db = await database;
    return await db.query('rooms');
  }

  Future<List<int>> searchRoomByUsername(String username) async {
    final db = await database;

    final List<Map<String, dynamic>> results = await db.query(
      'rooms',
      columns: ['roomId'],
      where: 'username LIKE ?',
      whereArgs: ['%$username%'],
    );
    return results.map((room) {
      final roomId = room['roomId'];
      return roomId is int ? roomId : int.tryParse(roomId.toString()) ?? 0;
    }).toList();
  }

  Future<void> clearDatabase() async {
    final db = await database;
    await db.delete('rooms');
  }
}
