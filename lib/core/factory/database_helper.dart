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
        version: 28,
        onCreate: (db, version) async {
          await _createAllTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {

          if (oldVersion < 27) {
            await db.execute('ALTER TABLE personas ADD COLUMN seed INTEGER');
          }
          if (oldVersion < 22) {
            await db.execute('ALTER TABLE personas ADD COLUMN role TEXT');
          }
          if (oldVersion < 19) {
            await db.execute(
              'ALTER TABLE personas ADD COLUMN user_gender TEXT',
            );
            await db.execute('ALTER TABLE personas ADD COLUMN user_age TEXT');
            await db.execute(
              'ALTER TABLE personas ADD COLUMN user_hair_color TEXT',
            );
            await db.execute(
              'ALTER TABLE personas ADD COLUMN user_ethnicity TEXT',
            );
            await db.execute(
              'ALTER TABLE personas ADD COLUMN user_appearance_enabled INTEGER',
            );
          }

        },
      );
      await _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_branches_entity ON branches(entity_id)',
      );
      await _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_branch ON messages(branch_id)',
      );
      await _db!.execute(
        'CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)',
      );
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
      is_hidden       INTEGER NOT NULL DEFAULT 0,
      is_greeting INTEGER NOT NULL DEFAULT 0,
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
    age_verified     INTEGER NOT NULL DEFAULT 0,
    user_appearance_enabled INTEGER,
    user_gender       TEXT,
    user_age          TEXT,
    user_hair_color   TEXT,
    user_ethnicity    TEXT,
    role              TEXT,
    seed              INTEGER,
    created_at       INTEGER NOT NULL,
    updated_at       INTEGER NOT NULL
  )
''');

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


    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_branches_entity ON branches(entity_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_branch ON messages(branch_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)',
    );
  }

  // ── BRANCHES ────────────────────────────────────────────────────────────

  /// Returns all branches for a given entity, newest-updated first.
  Future<List<Map<String, dynamic>>> getBranchesForEntity(
    String entityId,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        'branches',
        where: 'entity_id = ?',
        whereArgs: [entityId],
        orderBy: 'updated_at DESC',
      );
      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Returns up to [limit] most recently updated branches
  /// whose entity_id starts with 'single:'.
  Future<List<Map<String, dynamic>>> getRecentSingleBranches({
    int limit = 5,
  }) async {
    try {
      final db = await database;
      final results = await db.rawQuery(
        '''
    SELECT 
      b.id,
      b.entity_id,
      b.preview,
      b.updated_at,
    
    COALESCE(MAX(m.timestamp), b.updated_at) AS real_updated_at,
    
      p.name as persona_name,
      p.avatar_path,
      p.avatar_asset_path,
      p.age_verified as persona_age_verified
    
    FROM branches b
    
    LEFT JOIN messages m 
      ON m.branch_id = b.id
    
    LEFT JOIN personas p 
      ON p.id = REPLACE(b.entity_id, 'single:', '')
    
    WHERE b.entity_id LIKE 'single:%'
    AND p.id IS NOT NULL
    
    GROUP BY b.id
    
    ORDER BY real_updated_at DESC
    
    LIMIT ?
  ''',
        [limit],
      );

      return results;
    } catch (e) {
      rethrow;
    }
  }



  /// Up to [limit] most recently updated branches whose entity_id starts with 'multi:'.
  Future<List<Map<String, dynamic>>> getRecentMultiBranches({
    int limit = 8,
  }) async {
    try {
      final db = await database;
      final results = await db.rawQuery(
        '''
      SELECT
        b.id,
        b.entity_id,
        b.preview,
        b.updated_at,
        COALESCE(MAX(m.timestamp), b.updated_at) AS real_updated_at,
        mp.name        AS preset_name,
        mp.persona_ids AS persona_ids,
        mp.greeting    AS greeting
      FROM branches b
      LEFT JOIN messages m       ON m.branch_id = b.id
      LEFT JOIN multi_presets mp ON mp.id = REPLACE(b.entity_id, 'multi:', '')
      WHERE b.entity_id LIKE 'multi:%'
        AND mp.id IS NOT NULL
      GROUP BY b.id
      ORDER BY real_updated_at DESC
      LIMIT ?
      ''',
        [limit],
      );
      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Inserts a new branch row.
  Future<void> insertBranch(String id, String entityId, String? preview) async {
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
      await db.insert('branches', data);
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the preview text of a branch.
  Future<void> updateBranchPreview(String branchId, String preview) async {
    try {
      final db = await database;
      await db.update(
        'branches',
        {'preview': preview},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Touches the updated_at timestamp of a branch to now.
  Future<void> updateBranchTimestamp(String branchId) async {
    try {
      final db = await database;
      await db.update(
        'branches',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a branch and all its messages and summary blocks.
  Future<void> deleteBranch(String branchId) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete(
          'messages',
          where: 'branch_id = ?',
          whereArgs: [branchId],
        );
        await txn.delete(
          'summaries',
          where: 'branch_id = ?',
          whereArgs: [branchId],
        );
        await txn.delete('branches', where: 'id = ?', whereArgs: [branchId]);
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all branches and their messages and summary blocks for a given entity.
  Future<void> deleteAllForEntity(String entityId) async {
    try {
      final db = await database;
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
          await txn.delete(
            'messages',
            where: 'branch_id = ?',
            whereArgs: [branchId],
          );
          await txn.delete(
            'summaries',
            where: 'branch_id = ?',
            whereArgs: [branchId],
          );
        }
        await txn.delete(
          'branches',
          where: 'entity_id = ?',
          whereArgs: [entityId],
        );
      });
    } catch (e) {
      rethrow;
    }
  }

  // ── BRANCH SUMMARY ──────────────────────────────────────────────────────

  /// Returns the stored context summary for [branchId], or null if absent.
  Future<String?> getBranchSummary(String branchId) async {
    try {
      final db = await database;
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
      rethrow;
    }
  }

  /// Saves (overwrites) the context summary for [branchId].
  Future<void> saveBranchSummary(String branchId, String summary) async {
    try {
      final db = await database;
      await db.update(
        'branches',
        {'context_summary': summary},
        where: 'id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── MESSAGES ────────────────────────────────────────────────────────────

  /// Returns all messages for a branch, ordered by timestamp ascending.
  Future<List<Map<String, dynamic>>> getMessages(String branchId) async {
    try {
      final db = await database;
      final results = await db.query(
        'messages',
        where: 'branch_id = ?',
        whereArgs: [branchId],
        orderBy: 'timestamp ASC',
      );
      return results;
    } catch (e) {
      rethrow;
    }
  }

  /// Inserts a single message row.
  Future<void> insertMessage(
    Map<String, dynamic> message,
    String branchId,
  ) async {
    try {
      final db = await database;
      final row = Map<String, dynamic>.from(message);
      row['branch_id'] = branchId;
      await db.insert('messages', row);
    } catch (e) {
      rethrow;
    }
  }

  Future<int> countRealCharacterMessages() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages '
      'WHERE is_user = 0 '
      'AND is_hidden = 0 '
      'AND is_greeting = 0 '
      'AND imageLocalPath IS NULL '
      "AND trim(content) != ''",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Deletes a single message by id.
  Future<void> deleteMessage(String messageId) async {
    try {
      final db = await database;
      await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all summary blocks for [branchId] that cover more than [messageCount] messages.
  Future<void> deleteSummaryBlocksAfter(
    String branchId,
    int messageCount,
  ) async {
    final db = await database;
    await db.delete(
      'summaries',
      where: 'branch_id = ? AND messages_covered > ?',
      whereArgs: [branchId, messageCount],
    );
  }

  /// Deletes the message with [messageId] and every message after it
  /// (by timestamp) within the same branch.
  Future<void> deleteMessagesFromId(String messageId, String branchId) async {
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

      await db.delete(
        'messages',
        where: 'branch_id = ? AND timestamp >= ?',
        whereArgs: [branchId, ts],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the content of an existing message.
  Future<void> updateMessageContent(String messageId, String newContent) async {
    try {
      final db = await database;
      await db.update(
        'messages',
        {'content': newContent},
        where: 'id = ?',
        whereArgs: [messageId],
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── GALLERY IMAGES ───────────────────────────────────────────────────────

  /// Returns all gallery image rows for [personaId].
  Future<List<Map<String, dynamic>>> getGalleryForPersona(
    String personaId,
  ) async {
    try {
      final db = await database;
      return await db.query(
        'gallery_images',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Returns a single gallery image row by [id], or null if not found.
  Future<Map<String, dynamic>?> getGalleryImageById(String id) async {
    try {
      final db = await database;
      final rows = await db.query(
        'gallery_images',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
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
      await db.insert('gallery_images', data);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a single gallery image record by [id].
  Future<void> deleteGalleryImage(String id) async {
    try {
      final db = await database;
      await db.delete('gallery_images', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all gallery image records for [personaId].
  Future<void> deleteAllGalleryForPersona(String personaId) async {
    try {
      final db = await database;
      await db.delete(
        'gallery_images',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Returns the list of template_ids already used for [personaId].
  Future<List<int>> getUsedTemplateIds(String personaId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'gallery_images',
        columns: ['template_id'],
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
      return rows.map((r) => r['template_id'] as int).toList();
    } catch (e) {
      rethrow;
    }
  }

  // ── SUMMARY BLOCKS ──────────────────────────────────────────────────────

  /// Returns all summary blocks for a branch, ordered by block_number ascending.
  Future<List<Map<String, dynamic>>> getSummaryBlocks(
    String branchId, {
    int? limit,
  }) async {
    try {
      final db = await database;
      List<Map<String, dynamic>> results;
      if (limit != null) {
        // Берём последние N по block_number, потом разворачиваем
        final reversed = await db.query(
          'summaries',
          where: 'branch_id = ?',
          whereArgs: [branchId],
          orderBy: 'block_number DESC',
          limit: limit,
        );
        results = reversed.reversed.toList();
      } else {
        results = await db.query(
          'summaries',
          where: 'branch_id = ?',
          whereArgs: [branchId],
          orderBy: 'block_number ASC',
        );
      }
      return results;
    } catch (e) {
      log('getSummaryBlocks error: $e', name: 'DB_ERROR');
      rethrow;
    }
  }

  /// Returns the next block number for a branch (max + 1, or 1 if no blocks).
  Future<int> getNextBlockNumber(String branchId) async {
    try {
      final db = await database;
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
      await db.insert('summaries', data);
    } catch (e) {
      rethrow;
    }
  }

  /// Returns the maximum messages_covered value for a branch.
  Future<int> getCoveredMessageCount(String branchId) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT MAX(messages_covered) as covered FROM summaries WHERE branch_id = ?',
        [branchId],
      );
      if (rows.isEmpty || rows.first['covered'] == null) return 0;
      return rows.first['covered'] as int;
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all summary blocks for a branch.
  Future<void> deleteAllSummaryBlocks(String branchId) async {
    try {
      final db = await database;
      await db.delete(
        'summaries',
        where: 'branch_id = ?',
        whereArgs: [branchId],
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes all summary blocks from the database.
  Future<void> clearAllSummaries() async {
    try {
      final db = await database;
      await db.delete('summaries');
    } catch (e) {
      rethrow;
    }
  }

  // ── PERSONA PROMPTS ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getPersonaPrompts(String personaId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'persona_prompts',
        where: 'persona_id = ?',
        whereArgs: [personaId],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
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
        'nsfw': nsfw,
        'erotic': erotic,
        'beach': beach,
        'romantic': romantic,
        'romantic2': romantic2,
        'office': office,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      await db.insert(
        'persona_prompts',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePersonaPrompts(String personaId) async {
    try {
      final db = await database;
      await db.delete(
        'persona_prompts',
        where: 'persona_id = ?',
        whereArgs: [personaId],
      );
    } catch (e) {
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
    } catch (e) {}
  }

  /// Returns all messages where imageLocalPath IS NOT NULL and timestamp < cutoffMs
  Future<List<Map<String, dynamic>>> getOldChatImageMessages(
    int cutoffMs,
  ) async {
    final db = await database;
    return db.query(
      'messages',
      where: 'imageLocalPath IS NOT NULL AND timestamp < ?',
      whereArgs: [cutoffMs],
    );
  }

  /// Deletes messages by list of ids
  Future<void> deleteMessagesByIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    final placeholders = ids.map((_) => '?').join(',');
    await db.delete('messages', where: 'id IN ($placeholders)', whereArgs: ids);
  }

  // ── PERSONAS ────────────────────────────────────────────────────────────

  /// Returns all personas from the database.
  Future<List<Map<String, dynamic>>> getAllPersonas() async {
    try {
      final db = await database;
      return await db.query('personas', orderBy: 'updated_at DESC');
    } catch (e) {
      rethrow;
    }
  }

  /// Returns a single persona by id, or null if not found.
  Future<Map<String, dynamic>?> getPersonaById(String id) async {
    try {
      final db = await database;
      final rows = await db.query(
        'personas',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
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
        'age_verified': persona.ageVerified ? 1 : 0,
        'role': persona.role,
        'seed': persona.seed,        // NEW
        'created_at': now,
        'updated_at': now,
      };
      await db.insert('personas', data);
    } catch (e) {
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
        'age_verified': persona.ageVerified ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'user_appearance_enabled':
            persona.userAppearanceEnabled == null
                ? null
                : (persona.userAppearanceEnabled! ? 1 : 0),
        'user_gender': persona.userGender,
        'user_age': persona.userAge,
        'user_hair_color': persona.userHairColor,
        'user_ethnicity': persona.userEthnicity,
        'seed': persona.seed,        // NEW

      };
      await db.update(
        'personas',
        data,
        where: 'id = ?',
        whereArgs: [persona.id],
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> setPersonaAgeVerified(String id, bool verified) async {
    final db = await database;
    await db.update(
      'personas',
      {'age_verified': verified ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPersonaAvatarPath(String id, String path) async {
    final db = await database;
    await db.update(
      'personas',
      {
        'avatar_path': path,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Deletes a persona by id.
  Future<void> deletePersona(String id) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        final branches = await txn.query(
          'branches',
          columns: ['id'],
          where: "entity_id = ?",
          whereArgs: ['single:$id'],
        );
        for (final branch in branches) {
          final branchId = branch['id'] as String;
          await txn.delete(
            'messages',
            where: 'branch_id = ?',
            whereArgs: [branchId],
          );
          await txn.delete(
            'summaries',
            where: 'branch_id = ?',
            whereArgs: [branchId],
          );
        }
        await txn.delete(
          'branches',
          where: "entity_id = ?",
          whereArgs: ['single:$id'],
        );
        await txn.delete('personas', where: 'id = ?', whereArgs: [id]);
      });
    } catch (e) {
      rethrow;
    }
  }

  // ── MULTI PRESETS ───────────────────────────────────────────────────────

  /// Returns all multi-presets from the database.
  Future<List<Map<String, dynamic>>> getAllMultiPresets() async {
    try {
      final db = await database;
      return await db.query('multi_presets', orderBy: 'updated_at DESC');
    } catch (e) {
      rethrow;
    }
  }

  /// Returns a single multi-preset by id, or null if not found.
  Future<Map<String, dynamic>?> getMultiPresetById(String id) async {
    try {
      final db = await database;
      final rows = await db.query(
        'multi_presets',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows.first;
    } catch (e) {
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
      await db.insert('multi_presets', data);
    } catch (e) {

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

      await db.update(
        'multi_presets',
        data,
        where: 'id = ?',
        whereArgs: [preset['id']],
      );
    } catch (e) {

      rethrow;
    }
  }

  /// Deletes a multi-preset by id.
  Future<void> deleteMultiPreset(String id) async {
    try {
      final db = await database;
      await db.delete('multi_presets', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> reopenDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _initCompleter = null;
    }
    await initDB();
  }
}
