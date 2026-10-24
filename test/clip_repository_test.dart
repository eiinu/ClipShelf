import 'dart:convert';
import 'dart:typed_data';

import 'package:clipshelf/models/clip.dart';
import 'package:clipshelf/services/clip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late SqliteClipRepository repository;
  setUp(() => repository = SqliteClipRepository(sqlite3.openInMemory()));
  tearDown(() => repository.close());

  test(
    'legacy JSON imports once without losing tags, flags or PNG bytes',
    () async {
      final clip = Clip(
        id: 'old-id',
        createdAt: DateTime.utc(2026, 10, 24),
        content: ClipContent(
          kind: ClipKind.image,
          image: Uint8List.fromList([137, 80, 78, 71]),
        ),
        favorite: true,
        pinned: true,
        tags: ['work'],
      );
      final json = jsonEncode([clip.toJson()]);
      repository.importLegacy(json);
      repository.importLegacy(json);
      final items = await repository.load();
      expect(items, hasLength(1));
      expect(items.single.toJson(), clip.toJson());
      expect(items.single.content.fingerprint, clip.content.fingerprint);
    },
  );

  test('failed replacement rolls the SQLite transaction back', () async {
    final clip = Clip(
      id: 'one',
      createdAt: DateTime.utc(2026, 10, 24),
      content: const ClipContent(kind: ClipKind.text, text: 'keep me'),
    );
    await repository.save([clip]);
    await expectLater(
      repository.save([clip, clip]),
      throwsA(isA<SqliteException>()),
    );
    expect((await repository.load()).single.content.text, 'keep me');
  });

  test('bad legacy data cannot mark import complete', () {
    expect(
      () => repository.importLegacy('[{"kind":"unknown"}]'),
      throwsA(anything),
    );
    expect(repository.database.select('SELECT * FROM metadata'), isEmpty);
  });
}
