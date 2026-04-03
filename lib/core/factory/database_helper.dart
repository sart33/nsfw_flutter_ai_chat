import 'dart:async';
import 'dart:developer';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/persona_model.dart';

/// Singleton helper that owns the SQLite database for branches & messages.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();


  Database? _db;

  /// Returns the open database, creating it on first access.
  Future<Database> get database async {
    if (_db != null) return _db!;
    await initDB();
    return _db!;
  }

  /// Opens (or creates) the 'chat_history.db' file and runs table creation.
  Completer<void>? _initCompleter;

  Future<void> initDB() async {
    if (_db != null) return;
    if (_initCompleter != null) {
      return _initCompleter!.future;
    }
    _initCompleter = Completer<void>();
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'chat_history.db');
      _db = await openDatabase(
        path,
        version: 13,
        onCreate: (db, version) async {
          await _createAllTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 13) {
            await _createMultiPresetsTable(db);
          }
        },
      );
      await _db!.execute('CREATE INDEX IF NOT EXISTS idx_branches_entity ON branches(entity_id)');
      await _db!.execute('CREATE INDEX IF NOT EXISTS idx_messages_branch ON messages(branch_id)');
      await _db!.execute('CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)');
      _initCompleter!.complete();
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
  }
  // -- Migration helper to move persona data from SharedPreferences to the new 'personas' table.

  Future<void> _createAllTables(Database db) async {
    await db.execute('''
    CREATE TABLE branches (
      id              TEXT PRIMARY KEY,
      entity_id       TEXT    NOT NULL,
      created_at      INTEGER NOT NULL,
      updated_at      INTEGER NOT NULL,
      preview         TEXT,
      context_summary TEXT
    )
  ''');

    await db.execute('''
    CREATE TABLE messages (
      id              TEXT PRIMARY KEY,
      branch_id       TEXT    NOT NULL,
      persona_id      TEXT,
      sender_name     TEXT    NOT NULL,
      content         TEXT    NOT NULL,
      is_user         INTEGER NOT NULL,
      timestamp       INTEGER NOT NULL,
      is_quick_action INTEGER NOT NULL DEFAULT 0,
      imageLocalPath  TEXT,
      FOREIGN KEY (branch_id) REFERENCES branches(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE gallery_images (
      id           TEXT    PRIMARY KEY,
      persona_id   TEXT    NOT NULL,
      template_id  INTEGER NOT NULL,
      local_path   TEXT    NOT NULL,
      generated_at INTEGER NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE summaries (
      id               TEXT PRIMARY KEY,
      branch_id        TEXT NOT NULL,
      block_number     INTEGER NOT NULL,
      summary_text     TEXT NOT NULL,
      created_at       INTEGER NOT NULL,
      messages_covered INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (branch_id) REFERENCES branches(id)
    )
  ''');

    await db.execute('''
    CREATE TABLE persona_prompts (
      persona_id TEXT PRIMARY KEY,
      nsfw       TEXT,
      erotic     TEXT,
      beach      TEXT,
      romantic   TEXT,
      romantic2  TEXT,
      office     TEXT,
      updated_at INTEGER NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE scene_generation_log (
      id           TEXT PRIMARY KEY,
      branch_id    TEXT NOT NULL,
      persona_name TEXT NOT NULL,
      extracted_at INTEGER NOT NULL,
      scene_window TEXT NOT NULL,
      raw_llm_json TEXT,
      final_prompt TEXT NOT NULL,
      image_path   TEXT NOT NULL
    )
  ''');

    await db.execute('''
    CREATE TABLE personas (
      id               TEXT PRIMARY KEY,
      name             TEXT NOT NULL,
      description      TEXT NOT NULL,
      greeting         TEXT NOT NULL,
      avatar_path      TEXT,
      avatar_asset_path TEXT,
      behavior         TEXT,
      gallery_mode     TEXT NOT NULL DEFAULT 'nude',
      created_at       INTEGER NOT NULL,
      updated_at       INTEGER NOT NULL
    )
  ''');

    await _createMultiPresetsTable(db);

    await db.execute('CREATE INDEX IF NOT EXISTS idx_branches_entity ON branches(entity_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_branch ON messages(branch_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)');
  }

  // ── BRANCHES ────────────────────────────────────────────────────────────

  /// Returns all branches for a given entity, newest-updated first.
  Future<List<Map<String, dynamic>>> getBranchesForEntity(
      String entityId) async {
    try {
      final db = await database;
      log('SELECT branches WHERE entity_id=$entityId ORDER BY updated_at DESC', name: 'DB_READ');
      final results = await db.query(
        'branches',
        where: 'entity_id = ?',
        whereArgs: [entityId],
        orderBy: 'updated_at DESC',
      );
      log('getBranchesForEntity result count: ${results.length}', name: 'DB_READ');
      return results;
    } catch (e) {
      log('getBranchesForEntity error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getBranchesForEntity error: $e');
      rethrow;
    }
  }

  /// Returns up to [limit] most recently updated branches
  /// whose entity_id starts with 'single:'.
  Future<List<Map<String, dynamic>>> getRecentSingleBranches({int limit = 5}) async {
    try {
      final db = await database;
      log('SELECT branches with real_updated_at FROM messages JOIN WHERE entity_id LIKE \'single:%\' ORDER BY real_updated_at DESC LIMIT $limit', name: 'DB_READ');
      final results = await db.rawQuery('''
    SELECT 
      b.id,
      b.entity_id,
      b.preview,
      b.updated_at,
    
    COALESCE(MAX(m.timestamp), b.updated_at) AS real_updated_at,
    
      p.name as persona_name,
      p.avatar_path,
      p.avatar_asset_path
    
    FROM branches b
    
    LEFT JOIN messages m 
      ON m.branch_id = b.id
    
    LEFT JOIN personas p 
      ON p.id = REPLACE(b.entity_id, 'single:', '')
    
    WHERE b.entity_id LIKE 'single:%'
    
    GROUP BY b.id
    
    ORDER BY real_updated_at DESC
    
    LIMIT ?
  ''', [limit]);
      log('getRecentSingleBranches result count: ${results.length}', name: 'DB_READ');
      return results;
    } catch (e) {
      log('getRecentSingleBranches error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getRecentSingleBranches error: $e');
      rethrow;
    }
  }

  /// Inserts a new branch row.
  Future<void> insertBranch(
      String id, String entityId, String? preview) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final data = {
        'id': id,
        'entity_id': entityId,
        'created_at': now,
        'updated_at': now,
        'preview': preview,
      };
      log('INSERT INTO branches: $data', name: 'DB_WRITE');
      await db.insert('branches', data);
    } catch (e) {
      log('insertBranch error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertBranch error: $e');
      rethrow;
    }
  }

  /// Updates the preview text of a branch.
  Future<void> updateBranchPreview(String branchId, String preview) async {
    try {
      final db = await database;
      log('UPDATE branches SET preview WHERE id=$branchId, data: {preview: $preview}', name: 'DB_WRITE');
      await db.update(
        'branches',
        {'preview': preview},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      log('updateBranchPreview error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.updateBranchPreview error: $e');
      rethrow;
    }
  }

  /// Touches the updated_at timestamp of a branch to now.
  Future<void> updateBranchTimestamp(String branchId) async {
    try {
      final db = await database;
      log('UPDATE branches SET updated_at=now WHERE id=$branchId', name: 'DB_WRITE');
      await db.update(
        'branches',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      log('updateBranchTimestamp error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.updateBranchTimestamp error: $e');
      rethrow;
    }
  }

  /// Deletes a branch and all its messages and summary blocks.
  Future<void> deleteBranch(String branchId) async {
    try {
      final db = await database;
      log('DELETE messages+summaries WHERE branch_id=$branchId + DELETE branches WHERE id=$branchId', name: 'DB_DELETE');
      await db.transaction((txn) async {
        await txn.delete('messages',
            where: 'branch_id = ?', whereArgs: [branchId]);
        await txn.delete('summaries',
            where: 'branch_id = ?', whereArgs: [branchId]);
        await txn
            .delete('branches', where: 'id = ?', whereArgs: [branchId]);
      });
    } catch (e) {
      log('deleteBranch error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteBranch error: $e');
      rethrow;
    }
  }

  /// Deletes all branches and their messages and summary blocks for a given entity.
  Future<void> deleteAllForEntity(String entityId) async {
    try {
      final db = await database;
      log('DELETE all branches+messages+summaries for entity_id=$entityId', name: 'DB_DELETE');
      await db.transaction((txn) async {
        // Fetch branch ids first.
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: 'entity_id = ?',
          whereArgs: [entityId],
        );
        for (final branch in branches) {
          final branchId = branch['id'] as String;
          log('DELETE messages WHERE branch_id=$branchId', name: 'DB_DELETE');
          await txn.delete('messages',
              where: 'branch_id = ?', whereArgs: [branchId]);
          log('DELETE summaries WHERE branch_id=$branchId', name: 'DB_DELETE');
          await txn.delete('summaries',
              where: 'branch_id = ?', whereArgs: [branchId]);
        }
        await txn.delete('branches',
            where: 'entity_id = ?', whereArgs: [entityId]);
      });
    } catch (e) {
      log('deleteAllForEntity error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteAllForEntity error: $e');
      rethrow;
    }
  }

  // ── BRANCH SUMMARY ──────────────────────────────────────────────────────

  /// Returns the stored context summary for [branchId], or null if absent.
  Future<String?> getBranchSummary(String branchId) async {
    try {
      final db = await database;
      log('SELECT context_summary FROM branches WHERE id=$branchId', name: 'DB_READ');
      final rows = await db.query(
        'branches',
        columns: ['context_summary'],
        where: 'id = ?',
        whereArgs: [branchId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      final value = rows.first['context_summary'];
      if (value == null || (value as String).isEmpty) return null;
      return value;
    } catch (e) {
      log('getBranchSummary error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getBranchSummary error: $e');
      rethrow;
    }
  }

  /// Saves (overwrites) the context summary for [branchId].
  Future<void> saveBranchSummary(String branchId, String summary) async {
    try {
      final db = await database;
      log('UPDATE branches SET context_summary WHERE id=$branchId', name: 'DB_WRITE');
      await db.update(
        'branches',
        {'context_summary': summary},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      log('saveBranchSummary error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.saveBranchSummary error: $e');
      rethrow;
    }
  }

  // ── MESSAGES ────────────────────────────────────────────────────────────

  /// Returns all messages for a branch, ordered by timestamp ascending.
  Future<List<Map<String, dynamic>>> getMessages(String branchId) async {
    try {
      final db = await database;
      log('SELECT messages WHERE branch_id=$branchId ORDER BY timestamp ASC', name: 'DB_READ');
      final results = await db.query(
        'messages',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'timestamp ASC',
      );
      log('getMessages result count: ${results.length}', name: 'DB_READ');
      return results;
    } catch (e) {
      log('getMessages error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getMessages error: $e');
      rethrow;
    }
  }

  /// Inserts a single message row.
  Future<void> insertMessage(
      Map<String, dynamic> message, String branchId) async {
    try {
      final db = await database;
      final row = Map<String, dynamic>.from(message);
      row['branch_id'] = branchId;
      log('INSERT INTO messages: $row', name: 'DB_WRITE');
      await db.insert('messages', row);
    } catch (e) {
      log('insertMessage error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertMessage error: $e');
      rethrow;
    }
  }

  /// Deletes a single message by id.
  Future<void> deleteMessage(String messageId) async {
    try {
      final db = await database;
      log('DELETE messages WHERE id=$messageId', name: 'DB_DELETE');
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    } catch (e) {
      log('deleteMessage error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteMessage error: $e');
      rethrow;
    }
  }

  /// Deletes the message with [messageId] and every message after it
  /// (by timestamp) within the same branch.
  Future<void> deleteMessagesFromId(
      String messageId, String branchId) async {
    try {
      final db = await database;
      // Find the target message's timestamp.
      final rows = await db.query(
        'messages',
        columns: ['timestamp'],
        where: 'id = ?',
        whereArgs: [messageId],
      );
      if (rows.isEmpty) return;
      final ts = rows.first['timestamp'] as int;

      log('DELETE messages WHERE branch_id=$branchId AND timestamp>=$ts (from messageId=$messageId)', name: 'DB_DELETE');
      await db.delete(
        'messages',
        where: 'branch_id = ? AND timestamp >= ?',
        whereArgs: [branchId, ts],
      );
    } catch (e) {
      log('deleteMessagesFromId error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteMessagesFromId error: $e');
      rethrow;
    }
  }

  /// Updates the content of an existing message.
  Future<void> updateMessageContent(
      String messageId, String newContent) async {
    try {
      final db = await database;
      log('UPDATE messages SET content WHERE id=$messageId, data: {content: $newContent}', name: 'DB_WRITE');
      await db.update(
        'messages',
        {'content': newContent},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      log('updateMessageContent error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.updateMessageContent error: $e');
      rethrow;
    }
  }

  // ── GALLERY IMAGES ───────────────────────────────────────────────────────

  /// Returns all gallery image rows for [personaId].
  Future<List<Map<String, dynamic>>> getGalleryForPersona(
      String personaId) async {
    try {
      final db = await database;
      log('SELECT gallery_images WHERE persona_id=$personaId', name: 'DB_READ');
      return await db.query(
        'gallery_images',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
      log('getGalleryForPersona error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getGalleryForPersona error: $e');
      rethrow;
    }
  }

  /// Returns a single gallery image row by [id], or null if not found.
  Future<Map<String, dynamic>?> getGalleryImageById(String id) async {
    try {
      final db = await database;
      log('SELECT gallery_images WHERE id=$id', name: 'DB_READ');
      final rows = await db.query(
        'gallery_images',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
      log('getGalleryImageById error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getGalleryImageById error: $e');
      rethrow;
    }
  }

  /// Inserts a new gallery image record.
  Future<void> insertGalleryImage(
    String id,
    String personaId,
    int templateId,
    String localPath,
    int generatedAt,
  ) async {
    try {
      final db = await database;
      final data = {
        'id': id,
        'persona_id': personaId,
        'template_id': templateId,
        'local_path': localPath,
        'generated_at': generatedAt,
      };
      log('INSERT INTO gallery_images: $data', name: 'DB_WRITE');
      await db.insert('gallery_images', data);
    } catch (e) {
      log('insertGalleryImage error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertGalleryImage error: $e');
      rethrow;
    }
  }

  /// Deletes a single gallery image record by [id].
  Future<void> deleteGalleryImage(String id) async {
    try {
      final db = await database;
      log('DELETE gallery_images WHERE id=$id', name: 'DB_DELETE');
      await db.delete('gallery_images', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      log('deleteGalleryImage error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteGalleryImage error: $e');
      rethrow;
    }
  }

  /// Deletes all gallery image records for [personaId].
  Future<void> deleteAllGalleryForPersona(String personaId) async {
    try {
      final db = await database;
      log('DELETE gallery_images WHERE persona_id=$personaId', name: 'DB_DELETE');
      await db.delete(
        'gallery_images',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
      log('deleteAllGalleryForPersona error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteAllGalleryForPersona error: $e');
      rethrow;
    }
  }

  /// Returns the list of template_ids already used for [personaId].
  Future<List<int>> getUsedTemplateIds(String personaId) async {
    try {
      final db = await database;
      log('SELECT template_id FROM gallery_images WHERE persona_id=$personaId', name: 'DB_READ');
      final rows = await db.query(
        'gallery_images',
        columns: ['template_id'],
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
      return rows
          .map((r) => r['template_id'] as int)
          .toList();
    } catch (e) {
      log('getUsedTemplateIds error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getUsedTemplateIds error: $e');
      rethrow;
    }
  }

  // ── SUMMARY BLOCKS ──────────────────────────────────────────────────────

  /// Returns all summary blocks for a branch, ordered by block_number ascending.
  Future<List<Map<String, dynamic>>> getSummaryBlocks(String branchId) async {
    try {
      final db = await database;
      log('SELECT summaries WHERE branch_id=$branchId ORDER BY block_number ASC', name: 'DB_READ');
      final results = await db.query(
        'summaries',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'block_number ASC',
      );
      log('getSummaryBlocks result count: ${results.length}', name: 'DB_READ');
      return results;
    } catch (e) {
      log('getSummaryBlocks error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getSummaryBlocks error: $e');
      rethrow;
    }
  }

  /// Returns the next block number for a branch (max + 1, or 1 if no blocks).
  Future<int> getNextBlockNumber(String branchId) async {
    try {
      final db = await database;
      log('SELECT MAX(block_number) FROM summaries WHERE branch_id=$branchId', name: 'DB_READ');
      final rows = await db.rawQuery(
        'SELECT MAX(block_number) as max_num FROM summaries WHERE branch_id = ?',
        [branchId],
      );
      if (rows.isEmpty || rows.first['max_num'] == null) {
        return 1;
      }
      final maxNum = rows.first['max_num'] as int;
      return maxNum + 1;
    } catch (e) {
      log('getNextBlockNumber error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getNextBlockNumber error: $e');
      rethrow;
    }
  }

  /// Inserts a new summary block.
  Future<void> insertSummaryBlock(
    String id,
    String branchId,
    int blockNumber,
    String summaryText,
    int createdAt,
    int messagesCovered,
  ) async {
    try {
      final db = await database;
      final data = {
        'id': id,
        'branch_id': branchId,
        'block_number': blockNumber,
        'summary_text': summaryText,
        'created_at': createdAt,
        'messages_covered': messagesCovered,
      };
      log('INSERT INTO summaries: $data', name: 'DB_WRITE');
      await db.insert('summaries', data);
    } catch (e) {
      log('insertSummaryBlock error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertSummaryBlock error: $e');
      rethrow;
    }
  }

  /// Returns the maximum messages_covered value for a branch.
  Future<int> getCoveredMessageCount(String branchId) async {
    try {
      final db = await database;
      log('SELECT MAX(messages_covered) FROM summaries WHERE branch_id=$branchId', name: 'DB_READ');
      final rows = await db.rawQuery(
        'SELECT MAX(messages_covered) as covered FROM summaries WHERE branch_id = ?',
        [branchId],
      );
      if (rows.isEmpty || rows.first['covered'] == null) return 0;
      return rows.first['covered'] as int;
    } catch (e) {
      log('getCoveredMessageCount error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getCoveredMessageCount error: $e');
      rethrow;
    }
  }

  /// Deletes all summary blocks for a branch.
  Future<void> deleteAllSummaryBlocks(String branchId) async {
    try {
      final db = await database;
      log('DELETE summaries WHERE branch_id=$branchId', name: 'DB_DELETE');
      await db.delete(
        'summaries',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      log('deleteAllSummaryBlocks error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteAllSummaryBlocks error: $e');
      rethrow;
    }
  }

  /// Deletes all summary blocks from the database.
  Future<void> clearAllSummaries() async {
    try {
      final db = await database;
      log('DELETE FROM summaries', name: 'DB_DELETE');
      await db.delete('summaries');
    } catch (e) {
      log('clearAllSummaries error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.clearAllSummaries error: $e');
      rethrow;
    }
  }

  // ── PERSONA PROMPTS ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPersonaPrompts(String personaId) async {
    try {
      final db = await database;
      log('SELECT persona_prompts WHERE persona_id=$personaId', name: 'DB_READ');
      final rows = await db.query(
        'persona_prompts',
        where: 'persona_id = ?',
        whereArgs: [personaId],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
      log('getPersonaPrompts error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getPersonaPrompts error: $e');
      rethrow;
    }
  }

  Future<void> upsertPersonaPrompts({
    required String personaId,
    required String nsfw,
    required String erotic,
    required String beach,
    required String romantic,
    required String romantic2,
    required String office,
  }) async {
    try {
      final db = await database;
      final data = {
        'persona_id': personaId,
        'nsfw':       nsfw,
        'erotic':     erotic,
        'beach':      beach,
        'romantic':   romantic,
        'romantic2':  romantic2,
        'office':     office,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      log('UPSERT persona_prompts: $data', name: 'DB_WRITE');
      await db.insert(
        'persona_prompts',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      log('upsertPersonaPrompts error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.upsertPersonaPrompts error: $e');
      rethrow;
    }
  }

  Future<void> deletePersonaPrompts(String personaId) async {
    try {
      final db = await database;
      log('DELETE persona_prompts WHERE persona_id=$personaId', name: 'DB_DELETE');
      await db.delete(
        'persona_prompts',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
      log('deletePersonaPrompts error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deletePersonaPrompts error: $e');
      rethrow;
    }
  }

  // ── SCENE GENERATION LOG ─────────────────────────────────────────────────

  Future<void> insertSceneGenerationLog({
    required String id,
    required String branchId,
    required String personaName,
    required String sceneWindow,
    String? rawLlmJson,
    required String finalPrompt,
    required String imagePath,
  }) async {
    try {
      final db = await database;
      await db.insert('scene_generation_log', {
        'id': id,
        'branch_id': branchId,
        'persona_name': personaName,
        'extracted_at': DateTime.now().millisecondsSinceEpoch,
        'scene_window': sceneWindow,
        'raw_llm_json': rawLlmJson,
        'final_prompt': finalPrompt,
        'image_path': imagePath,
      });
    } catch (e) {
      // debugPrint('[DB] insertSceneGenerationLog error: $e');
    }
  }

  /// Returns all messages where imageLocalPath IS NOT NULL and timestamp < cutoffMs
  Future<List<Map<String, dynamic>>> getOldChatImageMessages(int cutoffMs) async {
    final db = await database;
    return db.query('messages',
      where: 'imageLocalPath IS NOT NULL AND timestamp < ?',
      whereArgs: [cutoffMs],
    );
  }

  /// Deletes messages by list of ids
  Future<void> deleteMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.delete('messages',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  // ── PERSONAS ────────────────────────────────────────────────────────────


  /// Returns all personas from the database.
  Future<List<Map<String, dynamic>>> getAllPersonas() async {
    try {
      final db = await database;
      log('SELECT personas ORDER BY updated_at DESC', name: 'DB_READ');
      return await db.query('personas', orderBy: 'updated_at DESC');
    } catch (e) {
      log('getAllPersonas error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getAllPersonas error: $e');
      rethrow;
    }
  }

  /// Returns a single persona by id, or null if not found.
  Future<Map<String, dynamic>?> getPersonaById(String id) async {
    try {
      final db = await database;
      log('SELECT personas WHERE id=$id', name: 'DB_READ');
      final rows = await db.query(
        'personas',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
      log('getPersonaById error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getPersonaById error: $e');
      rethrow;
    }
  }

  /// Inserts a new persona.
  Future<void> insertPersona(PersonaModel persona) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final data = {
        'id': persona.id,
        'name': persona.name,
        'description': persona.description,
        'greeting': persona.greeting,
        'avatar_path': persona.avatarPath,
        'avatar_asset_path': persona.avatarAssetPath,
        'behavior': persona.behavior,
        'gallery_mode': persona.galleryMode,
        'created_at': now,
        'updated_at': now,
      };
      log('INSERT INTO personas: $data', name: 'DB_WRITE');
      await db.insert('personas', data);
    } catch (e) {
      log('insertPersona error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertPersona error: $e');
      rethrow;
    }
  }

  /// Updates an existing persona.
  Future<void> updatePersona(PersonaModel persona) async {
    try {
      final db = await database;
      final data = {
        'name': persona.name,
        'description': persona.description,
        'greeting': persona.greeting,
        'avatar_path': persona.avatarPath,
        'avatar_asset_path': persona.avatarAssetPath,
        'behavior': persona.behavior,
        'gallery_mode': persona.galleryMode,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      log('UPDATE personas WHERE id=${persona.id}, data: $data', name: 'DB_WRITE');
      await db.update(
        'personas',
        data,
        where: 'id = ?',
        whereArgs: [persona.id],
      );
    } catch (e) {
      log('updatePersona error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.updatePersona error: $e');
      rethrow;
    }
  }

  /// Deletes a persona by id.
  Future<void> deletePersona(String id) async {
    try {
      final db = await database;
      log('DELETE personas WHERE id=$id', name: 'DB_DELETE');
      await db.delete('personas', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      log('deletePersona error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deletePersona error: $e');
      rethrow;
    }
  }

  // ── MULTI PRESETS ───────────────────────────────────────────────────────

  Future<void> _createMultiPresetsTable(Database db) async {
    await db.execute('''
    CREATE TABLE multi_presets (
      id           TEXT PRIMARY KEY,
      name         TEXT NOT NULL,
      persona_ids  TEXT NOT NULL,
      greeting     TEXT NOT NULL,
      behavior     TEXT NOT NULL,
      created_at   INTEGER NOT NULL,
      updated_at   INTEGER NOT NULL
    )
  ''');
  }

  /// Returns all multi-presets from the database.
  Future<List<Map<String, dynamic>>> getAllMultiPresets() async {
    try {
      final db = await database;
      log('SELECT multi_presets ORDER BY updated_at DESC', name: 'DB_READ');
      return await db.query('multi_presets', orderBy: 'updated_at DESC');
    } catch (e) {
      log('getAllMultiPresets error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getAllMultiPresets error: $e');
      rethrow;
    }
  }

  /// Returns a single multi-preset by id, or null if not found.
  Future<Map<String, dynamic>?> getMultiPresetById(String id) async {
    try {
      final db = await database;
      log('SELECT multi_presets WHERE id=$id', name: 'DB_READ');
      final rows = await db.query(
        'multi_presets',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
      log('getMultiPresetById error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.getMultiPresetById error: $e');
      rethrow;
    }
  }

  /// Inserts a new multi-preset.
  Future<void> insertMultiPreset(Map<String, dynamic> preset) async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      final data = {
        'id': preset['id'],
        'name': preset['name'],
        'persona_ids': preset['persona_ids'],
        'greeting': preset['greeting'],
        'behavior': preset['behavior'],
        'created_at': now,
        'updated_at': now,
      };
      log('INSERT INTO multi_presets: $data', name: 'DB_WRITE');
      await db.insert('multi_presets', data);
    } catch (e) {
      log('insertMultiPreset error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.insertMultiPreset error: $e');
      rethrow;
    }
  }

  /// Updates an existing multi-preset.
  Future<void> updateMultiPreset(Map<String, dynamic> preset) async {
    try {
      final db = await database;
      final data = {
        'name': preset['name'],
        'persona_ids': preset['persona_ids'],
        'greeting': preset['greeting'],
        'behavior': preset['behavior'],
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      log('UPDATE multi_presets WHERE id=${preset['id']}, data: $data', name: 'DB_WRITE');
      await db.update(
        'multi_presets',
        data,
        where: 'id = ?',
        whereArgs: [preset['id']],
      );
    } catch (e) {
      log('updateMultiPreset error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.updateMultiPreset error: $e');
      rethrow;
    }
  }

  /// Deletes a multi-preset by id.
  Future<void> deleteMultiPreset(String id) async {
    try {
      final db = await database;
      log('DELETE multi_presets WHERE id=$id', name: 'DB_DELETE');
      await db.delete('multi_presets', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      log('deleteMultiPreset error: $e', name: 'DB_ERROR');
      print('DatabaseHelper.deleteMultiPreset error: $e');
      rethrow;
    }
  }
}
