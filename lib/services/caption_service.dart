import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;
import 'package:flutter/foundation.dart';

enum CaptionMode {
  normal, // 普通内容
  adult,  // 成人内容
}

class CaptionService {
  static CaptionService? _instance;
  static CaptionService get instance => _instance ??= CaptionService._();
  CaptionService._();

  bool _ignoreSsl = true;

  void setIgnoreSsl(bool v) => _ignoreSsl = v;

  http.Client _client() {
    if (kIsWeb) return http.Client();
    final hc = HttpClient()
      ..badCertificateCallback =
          (cert, host, port) => _ignoreSsl;
    return http_io.IOClient(hc);
  }

  // ==================== AI生成文案+标签 ====================

  Future<CaptionResult> generateCaption({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
    String? customPrompt,
    int partIndex = 1,
    int totalParts = 1,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _generateWithAI(
          fileName: fileName,
          mode: mode,
          apiKey: apiKey,
          model: model ?? 'gpt-3.5-turbo',
          customPrompt: customPrompt,
          partIndex: partIndex,
          totalParts: totalParts,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('AI caption failed, fallback: $e');
      }
    }
    return _generateFromTemplate(
      fileName: fileName,
      mode: mode,
      partIndex: partIndex,
      totalParts: totalParts,
    );
  }

  /// 单独生成标签（3-5个hashtag）
  Future<List<String>> generateTags({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        return await _generateTagsWithAI(
          fileName: fileName,
          mode: mode,
          apiKey: apiKey,
          model: model ?? 'gpt-3.5-turbo',
        );
      } catch (e) {
        if (kDebugMode) debugPrint('AI tags failed, fallback: $e');
      }
    }
    return _defaultTags(fileName, mode);
  }

  Future<List<String>> _generateTagsWithAI({
    required String fileName,
    required CaptionMode mode,
    required String apiKey,
    required String model,
  }) async {
    final systemPrompt = mode == CaptionMode.adult
        ? '''你是成人视频频道运营专家。根据文件名分析视频内容，生成3-5个中文hashtag标签。
要求：
- 标签要具体描述视频情节/类型
- 使用"#"开头
- 只返回JSON数组格式，例如：["#自慰", "#独处", "#高清", "#福利", "#18+"]
- 标签简短有力（2-4个字）'''
        : '''你是视频频道运营专家。根据文件名分析视频内容，生成3-5个中文hashtag标签。
要求：
- 标签描述视频主题/内容
- 使用"#"开头
- 只返回JSON数组格式，例如：["#精彩", "#高清", "#推荐", "#必看"]
- 标签简短（2-4个字）''';

    final client = _client();
    try {
      final resp = await client
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {
                  'role': 'user',
                  'content': '视频文件名：$fileName\n请生成3-5个hashtag标签，只返回JSON数组。'
                },
              ],
              'max_tokens': 100,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['choices'][0]['message']['content'] as String;
        try {
          final jsonMatch =
              RegExp(r'\[.*\]', dotAll: true).firstMatch(content);
          if (jsonMatch != null) {
            final list = jsonDecode(jsonMatch.group(0)!) as List;
            return list
                .map((e) => e.toString().startsWith('#') ? e.toString() : '#${e.toString()}')
                .take(5)
                .toList();
          }
        } catch (_) {}
      }
    } finally {
      client.close();
    }
    return _defaultTags(fileName, mode);
  }

  Future<CaptionResult> _generateWithAI({
    required String fileName,
    required CaptionMode mode,
    required String apiKey,
    required String model,
    String? customPrompt,
    required int partIndex,
    required int totalParts,
  }) async {
    final systemPrompt = mode == CaptionMode.adult
        ? '''你是专业的成人频道运营者，专门创作吸引人的标题和描述及hashtag。
要求：
- 标题吸引眼球，暗示性强但不过分直白
- 描述勾起好奇心，加入相关emoji
- 使用中文
- 自动生成3-5个相关hashtag
- 风格：神秘、诱惑'''
        : '''你是专业的视频频道运营者，创作吸引人的标题和描述及hashtag。
要求：
- 标题简洁有力
- 描述突出视频亮点
- 加入相关emoji和中文
- 自动生成3-5个相关hashtag''';

    final userContent = customPrompt?.isNotEmpty == true
        ? '$customPrompt\n\n视频文件名：$fileName，第$partIndex/$totalParts部分\n返回JSON：{"title":"标题","caption":"描述","tags":["#标签1","#标签2"]}'
        : '视频文件名：$fileName，第$partIndex/$totalParts部分\n返回JSON：{"title":"标题","caption":"描述","tags":["#标签1","#标签2","#标签3"]}';

    final client = _client();
    try {
      final resp = await client
          .post(
            Uri.parse('https://api.openai.com/v1/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userContent},
              ],
              'max_tokens': 600,
              'temperature': 0.8,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final content = data['choices'][0]['message']['content'] as String;
        try {
          final jsonMatch =
              RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
          if (jsonMatch != null) {
            final parsed = jsonDecode(jsonMatch.group(0)!);
            final rawTags = parsed['tags'];
            final tags = rawTags is List
                ? rawTags.map((e) => e.toString()).toList()
                : _defaultTags(fileName, mode);
            return CaptionResult(
              title: parsed['title'] ?? _defaultTitle(mode, partIndex),
              caption: parsed['caption'] ?? content,
              tags: tags,
            );
          }
        } catch (_) {}
        return CaptionResult(
          title: _defaultTitle(mode, partIndex),
          caption: content,
          tags: _defaultTags(fileName, mode),
        );
      }
    } finally {
      client.close();
    }
    throw Exception('AI API调用失败');
  }

  CaptionResult _generateFromTemplate({
    required String fileName,
    required CaptionMode mode,
    required int partIndex,
    required int totalParts,
  }) {
    final baseName = fileName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .trim();

    if (mode == CaptionMode.adult) {
      return _adultTemplate(baseName, partIndex, totalParts);
    } else {
      return _normalTemplate(baseName, partIndex, totalParts);
    }
  }

  CaptionResult _normalTemplate(String baseName, int part, int total) {
    final titles = [
      '🔥 精彩视频 P$part${total > 1 ? " | 共${total}集" : ""}',
      '💎 独家内容 第${part}集${total > 1 ? "/$total" : ""}',
      '⭐ 精品推荐 P$part${total > 1 ? "/$total" : ""} | 高清必看',
    ];
    final captions = [
      '🔥 精彩内容持续更新！\n\n高质量视频内容，每一帧都值得细细品味。\n\n'
          '📌 关注频道，每天更新优质内容\n💬 欢迎转发分享',
      '💎 独家高清内容！\n\n最优质的视频体验，绝对不会让您失望！\n\n'
          '🔔 开启通知，不错过每次更新\n👍 喜欢请转发支持',
    ];
    final tagSets = [
      ['#精彩视频', '#高清', '#推荐', '#必看'],
      ['#独家内容', '#高清视频', '#每日更新', '#精品'],
      ['#精品视频', '#高清资源', '#推荐', '#关注'],
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
      tags: tagSets[part % tagSets.length],
    );
  }

  CaptionResult _adultTemplate(String baseName, int part, int total) {
    final lowerName = baseName.toLowerCase();

    // 根据文件名关键词智能匹配标签
    final List<String> autoTags = [];

    // 分析文件名中的关键词（无论语言）
    final keywordMap = {
      'solo': '#自慰',
      'masturbat': '#自慰',
      'finger': '#手指',
      'toy': '#玩具',
      'dildo': '#玩具',
      'vibrat': '#震动棒',
      'anal': '#肛交',
      'oral': '#口交',
      'blowjob': '#口交',
      'lesbian': '#百合',
      'massage': '#按摩',
      'shower': '#洗澡',
      'bath': '#浴室',
      'outdoor': '#户外',
      'office': '#办公室',
      'uniform': '#制服',
      'nurse': '#护士',
      'teacher': '#老师',
      'step': '#继母',
      'milf': '#熟女',
      'teen': '#少女',
      'asian': '#亚洲',
      'japanese': '#日本',
      'chinese': '#华人',
      'korean': '#韩国',
      'creampie': '#内射',
      'cumshot': '#颜射',
      '自慰': '#自慰',
      '手淫': '#自慰',
      '口交': '#口交',
      '肛': '#肛交',
      '制服': '#制服',
      '护士': '#护士',
      '老师': '#老师',
      '熟女': '#熟女',
      '少女': '#少女',
      '户外': '#户外',
    };

    for (final entry in keywordMap.entries) {
      if (lowerName.contains(entry.key)) {
        autoTags.add(entry.value);
        if (autoTags.length >= 3) break;
      }
    }

    // 补充通用成人标签
    final adultBase = ['#18+', '#福利', '#高清', '#成人内容', '#私藏资源'];

    for (final t in adultBase) {
      if (!autoTags.contains(t)) autoTags.add(t);
      if (autoTags.length >= 5) break;
    }

    final titles = [
      '🔞 福利来袭 P$part${total > 1 ? "/$total" : ""} | 不可错过',
      '💋 独家私藏 第${part}集${total > 1 ? " 共${total}集" : ""} | 高清',
      '🌶️ 劲爆内容 P$part${total > 1 ? "/$total" : ""} | 限时分享',
      '🔥 顶级资源 第${part}期${total > 1 ? "/$total" : ""}',
    ];
    final captions = [
      '🔞 今日精选福利，绝对让你大饱眼福！\n\n'
          '💋 高清画质，精彩绝伦\n'
          '🌶️ 内容火辣，18+向\n\n'
          '📌 关注频道获取每日最新福利\n🔔 开启通知第一时间收到更新',
      '💦 顶级资源限时分享！\n\n'
          '🔥 精心筛选，品质保证，高清无水印\n'
          '💋 喜欢的快快收藏转发！\n\n'
          '⚠️ 本内容仅限18岁以上成年人\n📲 关注频道，每天更新海量资源',
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
      tags: autoTags.take(5).toList(),
    );
  }

  List<String> _defaultTags(String fileName, CaptionMode mode) {
    if (mode == CaptionMode.adult) {
      return ['#18+', '#福利', '#高清', '#成人', '#私藏'];
    }
    return ['#精彩', '#高清', '#推荐', '#必看'];
  }

  String _defaultTitle(CaptionMode mode, int part) {
    return mode == CaptionMode.adult ? '🔞 福利内容 P$part' : '🎬 精彩视频 P$part';
  }
}

class CaptionResult {
  final String title;
  final String caption;
  final List<String> tags;

  CaptionResult({
    required this.title,
    required this.caption,
    List<String>? tags,
  }) : tags = tags ?? [];
}
