import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Clip;
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';

import '../controllers/shelf_controller.dart';
import '../models/clip.dart';

class ShelfApp extends StatelessWidget {
  const ShelfApp({super.key, required this.controller, this.desktopWarning});
  final ShelfController controller;
  final String? desktopWarning;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ClipShelf',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff4d648d),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xfffafbfe),
      visualDensity: VisualDensity.compact,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
    ),
    home: ShelfScreen(controller: controller, desktopWarning: desktopWarning),
  );
}

class ShelfScreen extends StatefulWidget {
  const ShelfScreen({super.key, required this.controller, this.desktopWarning});
  final ShelfController controller;
  final String? desktopWarning;
  @override
  State<ShelfScreen> createState() => _ShelfScreenState();
}

class _ShelfScreenState extends State<ShelfScreen> {
  final _searchFocus = FocusNode();
  ShelfController get shelf => widget.controller;

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _import() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON 历史文件', extensions: ['json']),
        ],
      );
      if (file == null) return;
      final count = await shelf.importJson(await file.readAsString());
      _message('已导入 $count 条记录');
    } catch (error) {
      _message('导入失败：$error');
    }
  }

  Future<void> _export() async {
    try {
      final location = await getSaveLocation(
        suggestedName: 'clips.json',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'JSON 历史文件', extensions: ['json']),
        ],
      );
      if (location == null) return;
      await File(location.path).writeAsString(shelf.exportJson(), flush: true);
      _message('历史记录已导出');
    } catch (error) {
      _message('导出失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: shelf,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xffe3e8ef))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 22),
                    const SizedBox(width: 8),
                    const Text(
                      'ClipShelf',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: TextField(
                        focusNode: _searchFocus,
                        onChanged: shelf.search,
                        decoration: const InputDecoration(
                          hintText: '搜索内容或标签',
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: shelf.ready ? shelf.togglePause : null,
                      tooltip: shelf.paused ? '继续监听' : '暂停监听',
                      icon: Icon(shelf.paused ? Icons.play_arrow : Icons.pause),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '历史管理',
                      onSelected: (value) {
                        if (value == 'import') _import();
                        if (value == 'export') _export();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'import',
                          enabled: shelf.ready,
                          child: const Text('导入旧版 clips.json'),
                        ),
                        PopupMenuItem(
                          value: 'export',
                          enabled: shelf.ready,
                          child: const Text('导出历史记录'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final list = _ClipList(shelf: shelf);
                    final detail = _ClipDetail(
                      key: ValueKey(shelf.selected?.id),
                      shelf: shelf,
                      onMessage: _message,
                    );
                    if (constraints.maxWidth < 1000) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 58,
                            child: _Filters(shelf: shelf, horizontal: true),
                          ),
                          SizedBox(height: 190, child: list),
                          const Divider(height: 1),
                          Expanded(child: detail),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 160, child: _Filters(shelf: shelf)),
                        const VerticalDivider(width: 1),
                        SizedBox(width: 310, child: list),
                        const VerticalDivider(width: 1),
                        Expanded(child: detail),
                      ],
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                color: Colors.white,
                child: Row(
                  children: [
                    Icon(
                      shelf.paused ? Icons.pause_circle_outline : Icons.circle,
                      size: 10,
                      color: shelf.paused ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${shelf.paused ? "已暂停" : "监听中"} · ${shelf.filtered.length} 条 · ${shelf.favoriteCount} 个收藏',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const Spacer(),
                    const Text(
                      '保留最近 7 天',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              if (shelf.error ?? shelf.clipboardError ?? widget.desktopWarning
                  case final String warning)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  color: const Color(0xfffff1dc),
                  child: SelectableText(
                    warning,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.shelf, this.horizontal = false});
  final ShelfController shelf;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final filters = <(String, String, IconData)>[
      ('all', '全部', Icons.inbox_outlined),
      ('favorites', '收藏', Icons.star_outline),
      ('text', '文本', Icons.notes),
      ('html', 'HTML', Icons.code),
      ('image', '图片', Icons.image_outlined),
      ...shelf.tags.map((tag) => ('tag:$tag', tag, Icons.tag)),
    ];
    if (horizontal) {
      return ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        children: [
          for (final (key, label, icon) in filters)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(label),
                avatar: Icon(icon, size: 16),
                selected: shelf.filter == key,
                onSelected: (_) => shelf.setFilter(key),
              ),
            ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      children: [
        for (final (key, label, icon) in filters)
          ListTile(
            dense: true,
            selected: shelf.filter == key,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer
                .withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            leading: Icon(icon, size: 20),
            title: Text(label, overflow: TextOverflow.ellipsis),
            onTap: () => shelf.setFilter(key),
          ),
      ],
    );
  }
}

String _kindLabel(ClipKind kind) => switch (kind) {
  ClipKind.text => '文本',
  ClipKind.html => 'HTML',
  ClipKind.image => '图片',
};

class _ClipList extends StatelessWidget {
  const _ClipList({required this.shelf});
  final ShelfController shelf;

  @override
  Widget build(BuildContext context) {
    final items = shelf.filtered;
    if (items.isEmpty) {
      return const Center(
        child: Text('暂无记录，复制一些内容试试', style: TextStyle(color: Colors.blueGrey)),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final clip = items[index];
        final date = clip.createdAt.toLocal();
        final time =
            '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
        return Material(
          color: shelf.selected?.id == clip.id
              ? const Color(0xffeaf0fa)
              : Colors.transparent,
          child: InkWell(
            onTap: () => shelf.select(clip.id),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xffe3e8ef))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _kindLabel(clip.content.kind),
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            if (clip.pinned)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.push_pin, size: 12),
                              ),
                            if (clip.groupId != null)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.link, size: 12),
                              ),
                            const Spacer(),
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (clip.content.image != null)
                          Image.memory(
                            clip.content.image!,
                            height: 40,
                            width: 70,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Text('图片无法显示'),
                          )
                        else
                          Text(
                            clip.content.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        if (clip.tags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              clip.tags.map((tag) => '#$tag').join(' '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: clip.favorite ? '取消收藏' : '加入收藏',
                    icon: Icon(
                      clip.favorite ? Icons.star : Icons.star_border,
                      size: 18,
                    ),
                    color: clip.favorite
                        ? Colors.amber.shade800
                        : Colors.blueGrey,
                    onPressed: () =>
                        shelf.update(clip.copyWith(favorite: !clip.favorite)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ClipDetail extends StatefulWidget {
  const _ClipDetail({super.key, required this.shelf, required this.onMessage});
  final ShelfController shelf;
  final ValueChanged<String> onMessage;
  @override
  State<_ClipDetail> createState() => _ClipDetailState();
}

class _ClipDetailState extends State<_ClipDetail> {
  final _tag = TextEditingController();
  String _language = 'plaintext';
  String? _formatted;
  bool _copying = false;
  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  Future<void> _copy(Clip clip) async {
    setState(() => _copying = true);
    try {
      final formatted = _formatted;
      await widget.shelf.copy(
        formatted == null
            ? clip.content
            : ClipContent(kind: ClipKind.text, text: formatted),
      );
      widget.onMessage('已复制到剪贴板');
    } catch (error) {
      widget.onMessage('复制失败：$error');
    } finally {
      if (mounted) setState(() => _copying = false);
    }
  }

  void _format(Clip clip) {
    try {
      setState(
        () =>
            _formatted = const JsonEncoder.withIndent('  ')
                .convert(jsonDecode(clip.content.sourceText)),
      );
    } catch (error) {
      widget.onMessage('JSON 格式化失败：$error');
    }
  }

  Future<void> _addTag(Clip clip) async {
    final value = _tag.text;
    _tag.clear();
    await widget.shelf.addTag(clip, value);
  }

  @override
  Widget build(BuildContext context) {
    final clip = widget.shelf.selected;
    if (clip == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.content_paste_outlined,
              size: 44,
              color: Colors.blueGrey,
            ),
            SizedBox(height: 12),
            Text('每一份内容，都有它的位置。', style: TextStyle(color: Colors.blueGrey)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  clip.content.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              IconButton(
                tooltip: clip.pinned ? '取消置顶' : '置顶',
                icon: Icon(
                  clip.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 20,
                ),
                onPressed: () =>
                    widget.shelf.update(clip.copyWith(pinned: !clip.pinned)),
              ),
              IconButton(
                tooltip: '删除',
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => widget.shelf.remove(clip.id),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tag,
                  decoration: const InputDecoration(
                    hintText: '添加标签',
                    prefixIcon: Icon(Icons.tag, size: 18),
                  ),
                  onSubmitted: (_) => _addTag(clip),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _addTag(clip),
                child: const Text('添加'),
              ),
            ],
          ),
          if (clip.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final tag in clip.tags)
                    InputChip(
                      label: Text(tag),
                      onDeleted: () => widget.shelf.update(
                        clip.copyWith(
                          tags: clip.tags
                              .where((value) => value != tag)
                              .toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              if (clip.content.kind != ClipKind.image)
                DropdownButton<String>(
                  value: _language,
                  items: const [
                    DropdownMenuItem(value: 'plaintext', child: Text('纯文本')),
                    DropdownMenuItem(value: 'html', child: Text('HTML')),
                    DropdownMenuItem(
                      value: 'markdown',
                      child: Text('Markdown'),
                    ),
                    DropdownMenuItem(value: 'json', child: Text('JSON')),
                    DropdownMenuItem(
                      value: 'javascript',
                      child: Text('JavaScript'),
                    ),
                    DropdownMenuItem(
                      value: 'typescript',
                      child: Text('TypeScript'),
                    ),
                    DropdownMenuItem(value: 'xml', child: Text('XML')),
                  ],
                  onChanged: (value) => setState(() {
                    _language = value!;
                    _formatted = null;
                  }),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_language == 'json' &&
                      clip.content.kind != ClipKind.image)
                    TextButton(
                      onPressed: () => _format(clip),
                      child: const Text('格式化 JSON'),
                    ),
                  FilledButton.icon(
                    onPressed: _copying ? null : () => _copy(clip),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('复制'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xffe3e8ef)),
              ),
              child: clip.content.kind == ClipKind.image
                  ? InteractiveViewer(
                      child: Center(
                        child: Image.memory(
                          clip.content.image!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Text('图片数据无法显示'),
                        ),
                      ),
                    )
                  : SelectionArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: _language == 'plaintext'
                              ? Text(
                                  _formatted ?? clip.content.sourceText,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                )
                              : HighlightView(
                                  _formatted ?? clip.content.sourceText,
                                  language: _language,
                                  theme: githubTheme,
                                  textStyle: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    height: 1.6,
                                  ),
                                ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
