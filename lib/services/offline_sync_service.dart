import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'api_service.dart';

enum SyncStatus { idle, syncing, error }

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._();
  OfflineSyncService._();

  Database? _db;
  final isOnline = ValueNotifier<bool>(true);
  final syncStatus = ValueNotifier<SyncStatus>(SyncStatus.idle);
  final pendingCount = ValueNotifier<int>(0);
  StreamSubscription? _connectivitySub;
  final _uuid = const Uuid();

  Future<void> init() async {
    final dbPath = p.join(await getDatabasesPath(), 'offline_queue.db');
    _db = await openDatabase(dbPath, version: 1, onCreate: (db, v) async {
      await db.execute('''
        CREATE TABLE action_queue (
          id TEXT PRIMARY KEY,
          endpoint TEXT NOT NULL,
          method TEXT NOT NULL,
          body TEXT,
          created_at INTEGER NOT NULL,
          retry_count INTEGER DEFAULT 0
        )
      ''');
    });

    // Check initial connectivity
    final result = await Connectivity().checkConnectivity();
    isOnline.value = !result.contains(ConnectivityResult.none);

    // Listen for changes
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      final online = !result.contains(ConnectivityResult.none);
      isOnline.value = online;
      if (online) processQueue();
    });

    await _updatePendingCount();
  }

  Future<void> enqueueAction(String endpoint, String method, Map<String, dynamic>? body) async {
    await _db?.insert('action_queue', {
      'id': _uuid.v4(),
      'endpoint': endpoint,
      'method': method,
      'body': body != null ? jsonEncode(body) : null,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'retry_count': 0,
    });
    await _updatePendingCount();
  }

  Future<void> processQueue() async {
    if (!isOnline.value || _db == null) return;
    syncStatus.value = SyncStatus.syncing;

    try {
      final items = await _db!.query('action_queue', orderBy: 'created_at ASC');
      for (final item in items) {
        final retryCount = (item['retry_count'] as int?) ?? 0;
        if (retryCount >= 3) {
          await _db!.delete('action_queue', where: 'id = ?', whereArgs: [item['id']]);
          continue;
        }

        try {
          final endpoint = item['endpoint'] as String;
          final method = item['method'] as String;
          final body = item['body'] != null ? jsonDecode(item['body'] as String) as Map<String, dynamic> : null;

          switch (method.toUpperCase()) {
            case 'POST':
              await ApiService.instance.post(endpoint, body ?? {});
              break;
            case 'PUT':
              await ApiService.instance.put(endpoint, body ?? {});
              break;
            case 'DELETE':
              await ApiService.instance.delete(endpoint);
              break;
          }
          await _db!.delete('action_queue', where: 'id = ?', whereArgs: [item['id']]);
        } catch (e) {
          await _db!.update('action_queue', {'retry_count': retryCount + 1}, where: 'id = ?', whereArgs: [item['id']]);
        }
      }
      syncStatus.value = SyncStatus.idle;
    } catch (e) {
      syncStatus.value = SyncStatus.error;
    }
    await _updatePendingCount();
  }

  Future<void> _updatePendingCount() async {
    final count = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM action_queue'));
    pendingCount.value = count ?? 0;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _db?.close();
  }
}
