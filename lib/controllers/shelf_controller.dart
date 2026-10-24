import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/clip.dart';
import '../services/clip_repository.dart';
import '../services/clipboard_service.dart';

class ShelfController extends ChangeNotifier {
  ShelfController({
    required this.repository,
    required this.clipboard,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final ClipRepository repository;
  final ClipboardService clipboard;
  final DateTime Function() now;
  final _uuid = const Uuid();
  List<Clip> _clips = [];
  String filter = 'all';
  String query = '';
  String? selectedId;
  String? error;
  String? clipboardError;
  bool paused = false;
  bool ready = false;
  bool _busy = false;
  bool _disposed = false;
  String? _lastFingerprint;
  Timer? _timer;
  Future<void> _writes = Future.value();

  List<Clip> get clips => List.unmodifiable(_clips);
  List<String> get tags =>
      _clips.expand((clip) => clip.tags).toSet().toList()..sort();
  int get favoriteCount => _clips.where((clip) => clip.favorite).length;
  List<Clip> get filtered {
    final search = query.trim().toLowerCase();
    return _clips.where((clip) {
      final matches = switch (filter) {
        'all' => true,
        'favorites' => clip.favorite,
        'text' || 'html' || 'image' => clip.content.kind.name == filter,
        _ =>
          filter.startsWith('tag:') && clip.tags.contains(filter.substring(4)),
      };
      return matches &&
          (search.isEmpty ||
              [
                clip.content.title,
                clip.content.preview,
                clip.content.text ?? '',
                clip.content.html ?? '',
                clip.source,
                ...clip.tags,
              ].join(' ').toLowerCase().contains(search));
    }).toList();
  }

  Clip? get selected {
    final items = filtered;
    if (items.isEmpty) return null;
    return items.firstWhere(
      (clip) => clip.id == selectedId,
      orElse: () => items.first,
    );
  }

  Future<void> initialize({bool monitor = true}) async {
    try {
      _clips = await repository.load();
      _prune();
      _sort();
      ready = true;
      await _persist();
      if (monitor) {
        _timer = Timer.periodic(
          const Duration(milliseconds: 750),
          (_) => unawaited(poll()),
        );
      }
    } catch (exception) {
      error = '读取历史失败：$exception';
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sort() => _clips.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });
  void _prune() {
    final cutoff = now().subtract(const Duration(days: 7));
    _clips.removeWhere((clip) => clip.createdAt.isBefore(cutoff));
  }

  Future<void> poll() async {
    if (_busy || paused || !ready || _disposed) return;
    _busy = true;
    try {
      final content = await clipboard.read();
      if (_disposed) return;
      if (clipboardError != null) {
        clipboardError = null;
        _notify();
      }
      if (content == null) {
        _lastFingerprint = null;
        return;
      }
      if (content.fingerprint == _lastFingerprint) return;
      _lastFingerprint = content.fingerprint;
      await capture(content);
    } catch (exception) {
      clipboardError = '剪贴板读取失败：$exception';
      _notify();
    } finally {
      _busy = false;
    }
  }

  Future<void> capture(ClipContent content) async {
    if (!ready || _disposed) return;
    _prune();
    final timestamp = now();
    final grouped =
        content.kind == ClipKind.html && (content.text?.isNotEmpty ?? false);
    final groupId = grouped ? _uuid.v4() : null;
    final main = Clip(
      id: _uuid.v4(),
      content: content,
      createdAt: timestamp,
      groupId: groupId,
    );
    _clips.add(main);
    if (grouped) {
      _clips.add(
        Clip(
          id: _uuid.v4(),
          content: ClipContent(kind: ClipKind.text, text: content.text),
          createdAt: timestamp.subtract(const Duration(microseconds: 1)),
          groupId: groupId,
        ),
      );
    }
    selectedId = main.id;
    _sort();
    _notify();
    await _persist();
  }

  void setFilter(String value) {
    filter = value;
    selectedId = null;
    _notify();
  }

  void search(String value) {
    query = value;
    _notify();
  }

  void select(String id) {
    selectedId = id;
    _notify();
  }

  void togglePause() {
    paused = !paused;
    _notify();
  }

  Future<void> update(Clip clip) async {
    _clips = _clips.map((item) => item.id == clip.id ? clip : item).toList();
    _sort();
    if (filter.startsWith('tag:') && !tags.contains(filter.substring(4))) {
      filter = 'all';
    }
    _notify();
    await _persist();
  }

  Future<void> addTag(Clip clip, String value) async {
    final tag = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (tag.isEmpty) return;
    await update(clip.copyWith(tags: {...clip.tags, tag}.toList()));
  }

  Future<void> remove(String id) async {
    _clips.removeWhere((clip) => clip.id == id);
    if (filter.startsWith('tag:') && !tags.contains(filter.substring(4))) {
      filter = 'all';
    }
    _notify();
    await _persist();
  }

  Future<void> copy(ClipContent content) async {
    // Prevent a write racing a pending read and capturing our own copy.
    if (_busy) throw StateError('剪贴板正在读取，请稍后重试');
    _busy = true;
    try {
      await clipboard.write(content);
      _lastFingerprint = content.fingerprint;
      // The OS may normalize HTML or PNG bytes when writing. Remember the
      // actual representation so the next poll does not record our own copy.
      try {
        _lastFingerprint =
            (await clipboard.read())?.fingerprint ?? _lastFingerprint;
      } catch (_) {
        // The write succeeded; a later read failure must not report copy failure.
      }
    } finally {
      _busy = false;
    }
  }

  Future<int> importJson(String value) async {
    if (!ready) throw StateError('历史存储尚未就绪');
    final incoming = decodeClips(
      value,
    ); // Validate everything before modifying state.
    final ids = _clips.map((clip) => clip.id).toSet();
    final cutoff = now().subtract(const Duration(days: 7));
    final additions = incoming
        .where((clip) => !clip.createdAt.isBefore(cutoff) && ids.add(clip.id))
        .toList();
    final previous = List<Clip>.of(_clips);
    _clips.addAll(additions);
    _prune();
    _sort();
    if (!await _persist()) {
      _clips = previous;
      _notify();
      throw StateError(error ?? '导入保存失败');
    }
    _notify();
    return additions.length;
  }

  String exportJson() =>
      const JsonEncoder.withIndent('  ')
          .convert(_clips.map((clip) => clip.toJson()).toList());

  Future<bool> _persist() async {
    final snapshot = List<Clip>.of(_clips);
    var success = true;
    _writes = _writes.then((_) async {
      try {
        await repository.save(snapshot);
        error = null;
      } catch (exception) {
        error = '保存历史失败：$exception';
        success = false;
      }
      _notify();
    });
    await _writes;
    return success;
  }

  Future<void> shutdown() async {
    _timer?.cancel();
    // Pending clipboard work checks _disposed before changing history.
    _disposed = true;
    await _writes;
    repository.close();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
