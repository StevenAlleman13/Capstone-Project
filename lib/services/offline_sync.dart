import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Offline-first sync service.
///
/// Reads: try Supabase first → cache result in Hive → on failure return cache.
/// Writes: try Supabase first → on failure enqueue locally.
/// On every successful Supabase read the pending queue is flushed first.
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _cacheBoxName = 'offline_cache';
  static const _queueBoxName = 'pending_ops';

  late Box _cache;
  late Box _queue;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> init() async {
    _cache = await Hive.openBox(_cacheBoxName);
    _queue = await Hive.openBox(_queueBoxName);
  }

  // ── Cache helpers ──────────────────────────────────────────────────────────

  String _listKey(String table, String userId) => '${userId}_$table';
  String _singleKey(String table, String userId) => '${userId}_${table}_single';

  void cacheList(String table, String userId, List<dynamic> data) {
    _cache.put(_listKey(table, userId), jsonEncode(data));
  }

  List<Map<String, dynamic>> getCachedList(String table, String userId) {
    final raw = _cache.get(_listKey(table, userId));
    if (raw == null) return [];
    return List<Map<String, dynamic>>.from(
      (jsonDecode(raw as String) as List).map((e) => Map<String, dynamic>.from(e as Map)),
    );
  }

  void cacheSingle(String table, String userId, Map<String, dynamic> data) {
    _cache.put(_singleKey(table, userId), jsonEncode(data));
  }

  Map<String, dynamic>? getCachedSingle(String table, String userId) {
    final raw = _cache.get(_singleKey(table, userId));
    if (raw == null) return null;
    return Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
  }

  // ── Cache mutation helpers (call these on every local write) ──────────────

  /// Add a new record to a cached list.
  void addToCachedList(String table, String userId, Map<String, dynamic> item) {
    final list = getCachedList(table, userId);
    list.add(item);
    cacheList(table, userId, list);
  }

  /// Update fields on a matching record in a cached list.
  void patchCachedList(String table, String userId, String idField, String idValue, Map<String, dynamic> updates) {
    final list = getCachedList(table, userId);
    final idx = list.indexWhere((e) => e[idField]?.toString() == idValue);
    if (idx != -1) {
      list[idx] = {...list[idx], ...updates};
      cacheList(table, userId, list);
    }
  }

  /// Remove a matching record from a cached list.
  void removeFromCachedList(String table, String userId, String idField, String idValue) {
    final list = getCachedList(table, userId);
    list.removeWhere((e) => e[idField]?.toString() == idValue);
    cacheList(table, userId, list);
  }

  /// Merge updates into a cached single record.
  void patchCachedSingle(String table, String userId, Map<String, dynamic> updates) {
    final existing = getCachedSingle(table, userId) ?? {};
    cacheSingle(table, userId, {...existing, ...updates});
  }

  // ── Pending queue ──────────────────────────────────────────────────────────

  void enqueue({
    required String table,
    required String type, // 'insert' | 'update' | 'delete' | 'upsert'
    required Map<String, dynamic> data,
    Map<String, dynamic>? match, // for update / delete
  }) {
    _queue.add(jsonEncode({
      'table': table,
      'type': type,
      'data': data,
      if (match != null) 'match': match,
    }));
  }

  Future<void>? _flushFuture;

  /// Replays every queued operation against Supabase in order.
  /// Concurrent callers all await the same flush so none races ahead to fetch
  /// stale data before the upload finishes.
  Future<void> flushQueue() {
    if (_queue.isEmpty) return Future.value();
    return _flushFuture ??= _doFlush().whenComplete(() => _flushFuture = null);
  }

  Future<void> _doFlush() async {
    final keys = _queue.keys.toList();
    for (final key in keys) {
      final raw = _queue.get(key);
      if (raw == null) {
        await _queue.delete(key);
        continue;
      }
      final op = Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
      final table = op['table'] as String;
      final type = op['type'] as String;
      final data = Map<String, dynamic>.from(op['data'] as Map);
      final match = op['match'] != null
          ? Map<String, dynamic>.from(op['match'] as Map)
          : null;
      try {
        switch (type) {
          case 'insert':
            await _db.from(table).insert(data);
          case 'update':
            await _db.from(table).update(data).match(match!.cast<String, Object>());
          case 'delete':
            await _db.from(table).delete().match(match!.cast<String, Object>());
          case 'upsert':
            await _db.from(table).upsert(data);
        }
        await _queue.delete(key);
      } catch (_) {
        // Still offline — stop here, leave rest of queue intact.
        return;
      }
    }
  }
}
