import 'dart:convert';

import 'package:clipshelf/controllers/shelf_controller.dart';
import 'package:clipshelf/models/clip.dart';
import 'package:clipshelf/services/clip_repository.dart';
import 'package:clipshelf/services/clipboard_service.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryRepository implements ClipRepository {
  List<Clip> items = [];
  bool fail = false;
  @override
  Future<List<Clip>> load() async => List.of(items);
  @override
  Future<void> save(List<Clip> clips) async {
    if (fail) throw StateError('disk full');
    items = List.of(clips);
  }

  @override
  void close() {}
}

class FakeClipboard implements ClipboardService {
  ClipContent? content;
  bool fail = false;
  @override
  Future<ClipContent?> read() async {
    if (fail) throw StateError('clipboard unavailable');
    return content;
  }

  @override
  Future<void> write(ClipContent content) async {
    this.content = content;
  }
}

void main() {
  late MemoryRepository repository;
  late FakeClipboard clipboard;
  late ShelfController shelf;
  final now = DateTime.utc(2026, 10, 24);

  setUp(() async {
    repository = MemoryRepository();
    clipboard = FakeClipboard();
    shelf = ShelfController(
      repository: repository,
      clipboard: clipboard,
      now: () => now,
    );
    await shelf.initialize(monitor: false);
  });
  tearDown(() async {
    await shelf.shutdown();
    shelf.dispose();
  });

  test(
    'polling suppresses consecutive duplicates and our own writes',
    () async {
      clipboard.content = const ClipContent(kind: ClipKind.text, text: 'one');
      await shelf.poll();
      await shelf.poll();
      expect(shelf.clips, hasLength(1));
      await shelf.copy(const ClipContent(kind: ClipKind.text, text: 'two'));
      await shelf.poll();
      expect(shelf.clips, hasLength(1));
      clipboard.content = const ClipContent(kind: ClipKind.text, text: 'three');
      await shelf.poll();
      expect(shelf.clips, hasLength(2));
      expect(repository.items, hasLength(2));
    },
  );

  test('HTML keeps a linked plain text companion', () async {
    await shelf.capture(
      const ClipContent(
        kind: ClipKind.html,
        html: '<b>Hello</b>',
        text: 'Hello',
      ),
    );
    expect(shelf.clips, hasLength(2));
    expect(shelf.clips.first.content.kind, ClipKind.html);
    expect(shelf.clips[0].groupId, shelf.clips[1].groupId);
    expect(shelf.selected?.content.html, '<b>Hello</b>');
  });

  test(
    'favorites, normalized tags, search, pinning and deletion persist',
    () async {
      await shelf.capture(
        const ClipContent(kind: ClipKind.text, text: 'hello'),
      );
      final clip = shelf.clips.single;
      await shelf.update(clip.copyWith(favorite: true, pinned: true));
      await shelf.addTag(shelf.clips.single, '  Work   notes  ');
      await shelf.addTag(shelf.clips.single, 'Work notes');
      expect(shelf.tags, ['Work notes']);
      shelf.setFilter('favorites');
      shelf.search('WORK');
      expect(shelf.filtered, hasLength(1));
      shelf.setFilter('image');
      expect(shelf.filtered, isEmpty);
      shelf.setFilter('tag:Work notes');
      await shelf.remove(clip.id);
      expect(shelf.filter, 'all');
      expect(repository.items, isEmpty);
    },
  );

  test(
    'invalid import makes no partial changes; repeated import is idempotent',
    () async {
      await shelf.capture(const ClipContent(kind: ClipKind.text, text: 'keep'));
      final json = shelf.exportJson();
      expect(await shelf.importJson(json), 0);
      final valid = shelf.clips.single.toJson()..['id'] = 'new';
      await expectLater(
        shelf.importJson(
          jsonEncode([
            valid,
            {'kind': 'invalid'},
          ]),
        ),
        throwsA(anything),
      );
      expect(shelf.clips, hasLength(1));
    },
  );

  test('storage failure is visible and failed import is rolled back', () async {
    await shelf.capture(const ClipContent(kind: ClipKind.text, text: 'keep'));
    final incoming = shelf.clips.single.toJson()..['id'] = 'new';
    repository.fail = true;
    await expectLater(
      shelf.importJson(jsonEncode([incoming])),
      throwsStateError,
    );
    expect(shelf.clips, hasLength(1));
    expect(shelf.error, contains('保存历史失败'));
    expect(repository.items, hasLength(1));
  });

  test(
    'paused capture stops reading and recovers from platform failures',
    () async {
      shelf.togglePause();
      clipboard.content = const ClipContent(kind: ClipKind.text, text: 'hello');
      await shelf.poll();
      expect(shelf.clips, isEmpty);
      shelf.togglePause();
      clipboard.fail = true;
      await shelf.poll();
      expect(shelf.clipboardError, isNotNull);
      clipboard.fail = false;
      await shelf.poll();
      expect(shelf.clipboardError, isNull);
      expect(shelf.clips, hasLength(1));
    },
  );

  test(
    'retention removes expired entries and honors the seven-day boundary',
    () async {
      final clips = [
        Clip(
          id: 'expired',
          content: const ClipContent(kind: ClipKind.text, text: 'old'),
          createdAt: now.subtract(const Duration(days: 8)),
        ),
        Clip(
          id: 'boundary',
          content: const ClipContent(kind: ClipKind.text, text: 'boundary'),
          createdAt: now.subtract(const Duration(days: 7)),
        ),
      ];
      await shelf.importJson(
        jsonEncode(clips.map((clip) => clip.toJson()).toList()),
      );
      expect(shelf.clips.map((clip) => clip.id), ['boundary']);
    },
  );
}
