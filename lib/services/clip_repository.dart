import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/clip.dart';

abstract class ClipRepository {
  Future<List<Clip>> load();
  Future<void> save(List<Clip> clips);
  void close();
}

class SqliteClipRepository implements ClipRepository {
  SqliteClipRepository(this.database) {
    database.execute('PRAGMA journal_mode=WAL');
    database.execute(
      'CREATE TABLE IF NOT EXISTS clips (id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
    );
    database.execute(
      'CREATE TABLE IF NOT EXISTS metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
  }

  final Database database;

  static Future<SqliteClipRepository> openDefault() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final repository = SqliteClipRepository(
      sqlite3.open(p.join(directory.path, 'clipshelf.sqlite')),
    );
    try {
      if (repository.hasImportedLegacy) return repository;
      final candidates = <String>[p.join(directory.path, 'clips.json')];
      final home = Platform.environment['HOME'];
      if (Platform.isMacOS && home != null) {
        candidates.add(
          p.join(
            home,
            'Library',
            'Application Support',
            'me.eiinu.clipshelf',
            'clips.json',
          ),
        );
      } else if (Platform.isLinux && home != null) {
        candidates.add(
          p.join(
            Platform.environment['XDG_DATA_HOME'] ??
                p.join(home, '.local', 'share'),
            'me.eiinu.clipshelf',
            'clips.json',
          ),
        );
      } else if (Platform.isWindows) {
        final appData = Platform.environment['APPDATA'];
        if (appData != null) {
          candidates.add(p.join(appData, 'me.eiinu.clipshelf', 'clips.json'));
        }
      }
      for (final path in candidates.toSet()) {
        final file = File(path);
        if (await file.exists()) {
          repository.importLegacy(await file.readAsString());
          break;
        }
      }
      return repository;
    } catch (_) {
      repository.close();
      rethrow;
    }
  }

  /// Import only once, in one transaction. The source file remains untouched.
  bool get hasImportedLegacy => database
      .select("SELECT value FROM metadata WHERE key='legacy_imported'")
      .isNotEmpty;

  void importLegacy(String json) {
    if (hasImportedLegacy) return;
    final clips = decodeClips(json);
    database.execute('BEGIN IMMEDIATE');
    try {
      for (final clip in clips) {
        database.execute(
          'INSERT OR IGNORE INTO clips (id,payload) VALUES (?,?)',
          [clip.id, jsonEncode(clip.toJson())],
        );
      }
      database.execute(
        "INSERT INTO metadata (key,value) VALUES ('legacy_imported','1')",
      );
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  Future<List<Clip>> load() async => database
      .select('SELECT payload FROM clips')
      .map(
        (row) => Clip.fromJson(
          jsonDecode(row['payload'] as String) as Map<String, dynamic>,
        ),
      )
      .toList();

  @override
  Future<void> save(List<Clip> clips) async {
    database.execute('BEGIN IMMEDIATE');
    try {
      database.execute('DELETE FROM clips');
      for (final clip in clips) {
        database.execute('INSERT INTO clips (id,payload) VALUES (?,?)', [
          clip.id,
          jsonEncode(clip.toJson()),
        ]);
      }
      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  void close() => database.dispose();
}
