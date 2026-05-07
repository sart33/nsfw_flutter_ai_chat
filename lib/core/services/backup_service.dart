import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsfw_chat/core/extensions/context_extensions.dart';
import 'package:nsfw_chat/core/factory/database_helper.dart';
import 'package:nsfw_chat/core/utils/app_snack_bar.dart';
import 'package:nsfw_chat/presentation/providers/multi_preset_provider.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../presentation/providers/persona_provider.dart';
import '../../presentation/providers/recent_chats_provider.dart';
import '../config/app_theme.dart';

class BackupService {
  BackupService._();

  /// Exports the app data (database + persona files) into a .usbackup ZIP archive.
  static Future<void> exportBackup(BuildContext context) async {
    try {
      // ── Resolve paths ──────────────────────────────────────────────
      final dbPath = await getDatabasesPath();
      final dbFile = File(p.join(dbPath, 'chat_history.db'));
      final docsDir = await getApplicationDocumentsDirectory();

      // ── Build manifest ─────────────────────────────────────────────
      String platform;
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isWindows) {
        platform = 'windows';
      } else if (Platform.isMacOS) {
        platform = 'macos';
      } else if (Platform.isLinux) {
        platform = 'linux';
      } else {
        platform = 'unknown';
      }

      final manifest = {
        'app': 'uncensored_souls',
        'schema_version': 16,
        'platform': platform,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'docs_base': docsDir.path,
      };
      final manifestBytes = utf8.encode(jsonEncode(manifest));

      // ── Build archive ──────────────────────────────────────────────
      final archive = Archive();

      // 1. manifest.json
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));

      // 2. database.db
      if (await dbFile.exists()) {
        final dbBytes = await dbFile.readAsBytes();
        archive.addFile(ArchiveFile('database.db', dbBytes.length, dbBytes));
      }

      // 3. characters/ files
      final charactersDir = Directory(p.join(docsDir.path, 'characters'));
      if (await charactersDir.exists()) {
        final personaDirs = await charactersDir.list().toList();
        for (final entity in personaDirs) {
          if (entity is! Directory) continue;
          final personaId = p.basename(entity.path);

          // avatar subfolder
          final avatarDir = Directory(p.join(entity.path, 'avatar'));
          if (await avatarDir.exists()) {
            final avatarFiles = await avatarDir.list().toList();
            for (final f in avatarFiles) {
              if (f is! File) continue;
              final bytes = await f.readAsBytes();
              final archivePath = 'characters/$personaId/avatar/${p.basename(f.path)}';
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            }
          }

          // gallery subfolder
          final galleryDir = Directory(p.join(entity.path, 'gallery'));
          if (await galleryDir.exists()) {
            final galleryFiles = await galleryDir.list().toList();
            for (final f in galleryFiles) {
              if (f is! File) continue;
              final bytes = await f.readAsBytes();
              final archivePath = 'characters/$personaId/gallery/${p.basename(f.path)}';
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            }
          }

          // chat_images subfolder
          final chatImagesDir = Directory(p.join(entity.path, 'chat_images'));
          if (await chatImagesDir.exists()) {
            final chatFiles = await chatImagesDir.list().toList();
            for (final f in chatFiles) {
              if (f is! File) continue;
              final bytes = await f.readAsBytes();
              final archivePath = 'characters/$personaId/chat_images/${p.basename(f.path)}';
              archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
            }
          }
        }
      }

      // ── Encode ─────────────────────────────────────────────────────
      final encoder = ZipEncoder();
      final zipBytes = encoder.encode(archive);

      // ── Save file ──────────────────────────────────────────────────
      final dateStr = DateTime.now().toIso8601String().substring(0, 10).replaceAll('-', '');
      final suggestedName = 'uncensored_souls_backup_$dateStr.usbackup';


      String savePath;
      if (Platform.isAndroid) {
        await _withLoadingDialog(
          context,
          context.l10n.backupExporting,
              () async {
            const channel = MethodChannel('app/permissions');
            await channel.invokeMethod<String>('saveFileToDownloads', {
              'fileName': suggestedName,
              'bytes': zipBytes,
            });
          },
        );
        if (context.mounted) {
          AppSnackBar.showSuccess(context.l10n.backupExportDownloadDirSuccess);
        }
        return; // <-- выходим, не падаем в общий блок
      }

        final result = await FilePicker.platform.saveFile(
          dialogTitle: context.l10n.backupExport,
          fileName: suggestedName,
        );
        if (result == null) return;
        savePath = result;

      await _withLoadingDialog(
        context,
        context.l10n.backupExporting,
            () async {
              await File(savePath).writeAsBytes(zipBytes);
        },
      );
      if (context.mounted) {
        AppSnackBar.showSuccess(context.l10n.backupExportSuccess);
      }
    } catch (e) {
      if (context.mounted) {
        // AppSnackBar.show(e.toString());
        AppSnackBar.show(context.l10n.backupErrorExportFailed, isError: true);
      }
    }
  }


  /// Imports app data from a .usbackup ZIP archive.
  static Future<void> importBackup(BuildContext context, WidgetRef ref) async {
    try {
      // ── Pick file ──────────────────────────────────────────────────
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.single.path;
      if (filePath == null) return;


      // ── Read and decode ZIP ────────────────────────────────────────
      final zipBytes = await File(filePath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      // ── Parse manifest ─────────────────────────────────────────────
      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) {
        if (context.mounted) {
          AppSnackBar.show(context.l10n.backupErrorInvalidFile, isError: true);
        }
        return;
      }
      final manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<
          String,
          dynamic>;
      if (manifest['app'] != 'uncensored_souls') {
        if (context.mounted) {
          AppSnackBar.show(context.l10n.backupErrorInvalidFile, isError: true);
        }
        return;
      }

      final docsBase = manifest['docs_base'] as String;
      final docsDir = await getApplicationDocumentsDirectory();

      // ── Confirm dialog ─────────────────────────────────────────────
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) =>
            AlertDialog(
              title: Text(context.l10n.backupImportConfirmTitle),
              content: Text(context.l10n.backupImportConfirmMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(context.l10n.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(context.l10n.confirm),
                ),
              ],
            ),
      );

      if (confirmed != true) return;
      await _withLoadingDialog(
          context,
          context.l10n.backupImporting,
              () async {
            // ── Extract database to temp file ──────────────────────────────
            final dbFileEntry = archive.findFile('database.db');
            if (dbFileEntry == null) {
              throw Exception('invalid_file'); // поймаем ниже
            }
            final tempDbPath = p.join(docsDir.path, 'backup_temp.db');
            final tempDbFile = File(tempDbPath);
            await tempDbFile.writeAsBytes(dbFileEntry.content as List<int>);


            final Database tempDb;
            if (Platform.isWindows || Platform.isMacOS ||
                Platform.isLinux) {
              final ffiFactory = databaseFactoryFfi;
              tempDb = await ffiFactory.openDatabase(tempDbPath);
            } else {
              tempDb = await openDatabase(tempDbPath);
            }

            final tables = [
              'personas',
              'branches',
              'messages',
              'gallery_images',
              'summaries',
              'persona_prompts',
              'scene_generation_log',
              'multi_presets',
            ];

            final tableData = <String, List<Map<String, dynamic>>>{};
            for (final table in tables) {
              final rows = await tempDb.query(table);
              // Создаём изменяемую копию каждой строки
              tableData[table] =
                  rows
                      .map((row) => Map<String, dynamic>.from(row))
                      .toList();
            }
            await tempDb.close();

            // ── Extract image files from ZIP ───────────────────────────────
            for (final entry in archive) {
              if (entry.isFile && entry.name.startsWith('characters/')) {
                final destPath = p.join(docsDir.path, entry.name);
                final destFile = File(destPath);
                await destFile.parent.create(recursive: true);
                await destFile.writeAsBytes(entry.content);
              }
            }

            // ── Path patching ──────────────────────────────────────────────
            void patchPaths(List<Map<String, dynamic>> rows,
                String column) {
              for (final row in rows) {
                final val = row[column];
                if (val is String && val.startsWith(docsBase)) {
                  row[column] = val.replaceFirst(docsBase, docsDir.path);
                }
              }
            }

            patchPaths(tableData['personas'] ?? [], 'avatar_path');
            patchPaths(tableData['gallery_images'] ?? [], 'local_path');
            patchPaths(tableData['messages'] ?? [], 'imageLocalPath');
            patchPaths(
                tableData['scene_generation_log'] ?? [], 'image_path');

            // ── Merge into live database ───────────────────────────────────
            final liveDb = await DatabaseHelper.instance.database;

            // Order: personas, multi_presets, persona_prompts, branches, summaries, messages, gallery_images, scene_generation_log
            final insertOrder = [
              'personas',
              'multi_presets',
              'persona_prompts',
              'branches',
              'summaries',
              'messages',
              'gallery_images',
              'scene_generation_log',
            ];

            for (final table in insertOrder) {
              final rows = tableData[table] ?? [];
              for (final row in rows) {
                await liveDb.insert(
                  table,
                  row,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }

            // ── Cleanup ────────────────────────────────────────────────────
            await tempDbFile.delete();
              }
      );
      await DatabaseHelper.instance.reopenDatabase();
      ref.invalidate(personaProvider);
      ref.invalidate(recentChatsProvider);
      ref.invalidate(multiPresetProvider);
      if (context.mounted) {
        if (Platform.isAndroid) {
          AppSnackBar.showSuccess(context.l10n.backupExportDownloadDirSuccess);

        } else {
          AppSnackBar.showSuccess(context.l10n.backupImportSuccess);
        }
      }
    } catch (e) {

      if (context.mounted) {
        if (e.toString().contains('invalid_file')) {
          AppSnackBar.show(context.l10n.backupErrorInvalidFile, isError: true);
        } else {
          AppSnackBar.show(context.l10n.backupErrorImportFailed, isError: true);
        }
      }
    }
  }

  static Future<T> _withLoadingDialog<T>(
      BuildContext context,
      String message,
      Future<T> Function() operation,
      ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: AppTheme.surface,
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppTheme.primaryAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      return await operation();
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
