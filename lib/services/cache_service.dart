import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class CacheService {
  static final CacheService instance = CacheService._();
  CacheService._();

  Database? _db;

  /// Initializes the SQLite database for caching.
  /// Must be called once before using cacheData / getCachedData.
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = p.join(await getDatabasesPath(), 'cache_data.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE cache_data (
          cache_key TEXT PRIMARY KEY,
          data TEXT NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
    });
  }

  /// Stores [data] as a JSON string under [key] along with a timestamp.
  Future<void> cacheData(String key, dynamic data) async {
    await _ensureInit();
    final jsonString = jsonEncode(data);
    await _db!.insert(
      'cache_data',
      {
        'cache_key': key,
        'data': jsonString,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns the cached data for [key], or `null` if the entry does not
  /// exist or has expired beyond [maxAge].
  Future<dynamic> getCachedData(
    String key, {
    Duration maxAge = const Duration(hours: 1),
  }) async {
    await _ensureInit();
    final results = await _db!.query(
      'cache_data',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final updatedAt = row['updated_at'] as int;
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(updatedAt);

    if (DateTime.now().difference(cachedAt) > maxAge) {
      // Expired - clean up
      await _db!.delete('cache_data', where: 'cache_key = ?', whereArgs: [key]);
      return null;
    }

    return jsonDecode(row['data'] as String);
  }

  /// Removes all cached entries.
  Future<void> clearCache() async {
    await _ensureInit();
    await _db!.delete('cache_data');
  }

  /// Ensures the database is initialized before any operation.
  Future<void> _ensureInit() async {
    if (_db == null) await init();
  }
}
