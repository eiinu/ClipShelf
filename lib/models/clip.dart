import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum ClipKind { text, html, image }

/// Clipboard content, independent of the operating system and persistence.
class ClipContent {
  const ClipContent({required this.kind, this.text, this.html, this.image});

  final ClipKind kind;
  final String? text;
  final String? html;
  final Uint8List? image;

  String get fingerprint => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            kind.name,
            text,
            html,
            image == null ? null : base64Encode(image!),
          ]),
        ),
      )
      .toString();

  String get sourceText => kind == ClipKind.html ? html ?? '' : text ?? '';
  String get preview => kind == ClipKind.image
      ? 'PNG 图片'
      : sourceText
            .replaceAll(RegExp(r'\s+'), ' ')
            .runes
            .take(180)
            .map(String.fromCharCode)
            .join();
  String get title {
    if (kind == ClipKind.image) return 'PNG 图片';
    final lines = sourceText.split('\n').map((line) => line.trim());
    final first = lines.firstWhere(
      (line) => line.isNotEmpty,
      orElse: () => '空内容',
    );
    return String.fromCharCodes(first.runes.take(48));
  }
}

class Clip {
  const Clip({
    required this.id,
    required this.content,
    required this.createdAt,
    this.favorite = false,
    this.pinned = false,
    this.tags = const [],
    this.groupId,
    this.source = 'System clipboard',
  });

  final String id;
  final ClipContent content;
  final DateTime createdAt;
  final bool favorite;
  final bool pinned;
  final List<String> tags;
  final String? groupId;
  final String source;

  Clip copyWith({bool? favorite, bool? pinned, List<String>? tags}) => Clip(
    id: id,
    content: content,
    createdAt: createdAt,
    favorite: favorite ?? this.favorite,
    pinned: pinned ?? this.pinned,
    tags: List.unmodifiable(tags ?? this.tags),
    groupId: groupId,
    source: source,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': content.kind.name,
    'text': content.text,
    'html': content.html,
    'image_data_url': content.image == null
        ? null
        : 'data:image/png;base64,${base64Encode(content.image!)}',
    'createdAt': createdAt.toUtc().toIso8601String(),
    'favorite': favorite,
    'pinned': pinned,
    'tags': tags,
    'groupId': groupId,
    'source': source,
    'title': content.title,
    'preview': content.preview,
  };

  factory Clip.fromJson(Map<String, dynamic> json) {
    final kind = ClipKind.values.byName(json['kind'] as String);
    final dataUrl = json['image_data_url'] as String?;
    Uint8List? image;
    if (dataUrl != null && dataUrl.isNotEmpty) {
      if (!dataUrl.startsWith('data:image/png;base64,')) {
        throw const FormatException('仅支持 PNG 图片数据');
      }
      image = base64Decode(dataUrl.substring('data:image/png;base64,'.length));
    }
    final text = json['text'] as String?;
    final html = json['html'] as String?;
    if ((kind == ClipKind.image && (image == null || image.isEmpty)) ||
        (kind == ClipKind.html && html == null) ||
        (kind == ClipKind.text && text == null)) {
      throw const FormatException('剪贴板内容不完整');
    }
    final id = json['id'] as String;
    if (id.isEmpty) throw const FormatException('记录 ID 不能为空');
    return Clip(
      id: id,
      content: ClipContent(kind: kind, text: text, html: html, image: image),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      favorite: json['favorite'] as bool? ?? false,
      pinned: json['pinned'] as bool? ?? false,
      tags: List.unmodifiable((json['tags'] as List? ?? []).cast<String>()),
      groupId: json['groupId'] as String?,
      source: json['source'] as String? ?? 'Imported',
    );
  }
}

List<Clip> decodeClips(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) throw const FormatException('历史文件应为 JSON 数组');
  return decoded
      .map((item) => Clip.fromJson(item as Map<String, dynamic>))
      .toList();
}
