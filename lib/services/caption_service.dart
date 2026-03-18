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
      ..badCertificateCallback = (cert, host, port) => _ignoreSsl;
    return http_io.IOClient(hc);
  }

  // ==================== 统一AI调用（支持多Provider）====================

  /// 统一AI文字生成接口（OpenAI兼容格式）
  /// [baseUrl] API根地址，如 https://api.deepseek.com/v1
  /// [apiKey] API密钥
  /// [model] 模型名
  /// [systemPrompt] 系统提示词
  /// [userPrompt] 用户提示词
  Future<String?> _callAI({
    required String baseUrl,
    required String apiKey,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = 800,
    double temperature = 0.8,
  }) async {
    final url = baseUrl.endsWith('/') ? '${baseUrl}chat/completions' : '$baseUrl/chat/completions';
    final client = _client();
    try {
      if (kDebugMode) debugPrint('AI call: $url model=$model');
      final resp = await client.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': maxTokens,
          'temperature': temperature,
        }),
      ).timeout(const Duration(seconds: 40));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['choices']?[0]?['message']?['content'] as String?;
      }
      if (kDebugMode) {
        debugPrint('AI error ${resp.statusCode}: ${resp.body.substring(0, resp.body.length.clamp(0, 300))}');
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('AI call exception: $e');
      return null;
    } finally {
      client.close();
    }
  }

  // ==================== 生成文案（标题+内容+标签）====================

  Future<CaptionResult> generateCaption({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? customPrompt,
    int partIndex = 1,
    int totalParts = 1,
    // 格式选项
    bool enableEmoji = true,
    bool enableTags = true,
    bool enableTgQuote = false,
    String tgChannelLink = '',
    bool enableBoldTitle = true,
    int maxCaptionLength = 200,
    String customTemplate = '',
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final result = await _generateWithAI(
          fileName: fileName,
          mode: mode,
          apiKey: apiKey,
          model: model ?? 'gpt-3.5-turbo',
          baseUrl: baseUrl ?? 'https://api.openai.com/v1',
          customPrompt: customPrompt,
          partIndex: partIndex,
          totalParts: totalParts,
          enableEmoji: enableEmoji,
          enableTags: enableTags,
          maxCaptionLength: maxCaptionLength,
        );
        return result;
      } catch (e) {
        if (kDebugMode) debugPrint('AI caption failed, fallback: $e');
      }
    }
    return _generateFromTemplate(
      fileName: fileName,
      mode: mode,
      partIndex: partIndex,
      totalParts: totalParts,
      enableEmoji: enableEmoji,
      enableTags: enableTags,
    );
  }

  Future<CaptionResult> _generateWithAI({
    required String fileName,
    required CaptionMode mode,
    required String apiKey,
    required String model,
    required String baseUrl,
    String? customPrompt,
    required int partIndex,
    required int totalParts,
    bool enableEmoji = true,
    bool enableTags = true,
    int maxCaptionLength = 200,
  }) async {
    final emojiNote = enableEmoji ? '适当使用emoji表情' : '不要使用任何emoji表情';
    final tagsNote = enableTags ? '生成3-5个hashtag标签（如#自慰 #福利 #18+）' : '不需要标签';
    final lenNote = '文案描述控制在$maxCaptionLength字以内';

    final systemPrompt = mode == CaptionMode.adult
        ? '''你是专业的成人视频频道运营者，根据视频文件名分析内容，创作吸引观众的中文标题、描述文案和标签。
要求：
- 标题要暗示性强、吸引眼球（20字以内）
- 描述勾起好奇心，不要太露骨但要有诱惑感，$lenNote
- $emojiNote
- $tagsNote
- 直接返回JSON格式，不要有其他文字'''
        : '''你是专业的视频频道运营者，根据视频文件名分析内容，创作吸引观众的中文标题、描述文案和标签。
要求：
- 标题简洁有力，吸引眼球（20字以内）
- 描述突出视频亮点，$lenNote
- $emojiNote
- $tagsNote
- 直接返回JSON格式，不要有其他文字''';

    final userPrompt = customPrompt?.isNotEmpty == true
        ? '$customPrompt\n\n视频文件名：$fileName，第$partIndex/$totalParts部分\n返回JSON：{"title":"标题","caption":"描述","tags":["#标签1","#标签2","#标签3"]}'
        : '视频文件名：$fileName，第$partIndex/$totalParts部分\n请分析内容并返回JSON：{"title":"标题","caption":"描述","tags":["#标签1","#标签2","#标签3"]}';

    final content = await _callAI(
      baseUrl: baseUrl,
      apiKey: apiKey,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      maxTokens: 600,
    );

    if (content != null) {
      try {
        final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
        if (jsonMatch != null) {
          final parsed = jsonDecode(jsonMatch.group(0)!);
          final rawTags = parsed['tags'];
          final tags = rawTags is List
              ? rawTags.map((e) => e.toString()).toList()
              : _defaultTags(fileName, mode);
          return CaptionResult(
            title: parsed['title'] ?? _defaultTitle(mode, partIndex),
            caption: parsed['caption'] ?? content,
            tags: enableTags ? tags : [],
          );
        }
      } catch (_) {}
      return CaptionResult(
        title: _defaultTitle(mode, partIndex),
        caption: content.length > maxCaptionLength
            ? content.substring(0, maxCaptionLength)
            : content,
        tags: enableTags ? _defaultTags(fileName, mode) : [],
      );
    }
    throw Exception('AI调用失败');
  }

  // ==================== 生成标签（单独调用）====================

  Future<List<String>> generateTags({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
    String? baseUrl,
  }) async {
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final systemPrompt = mode == CaptionMode.adult
            ? '你是成人视频频道运营专家。根据文件名分析视频情节，生成3-5个中文hashtag标签。'
              '要求：标签具体描述视频情节，使用"#"开头，只返回JSON数组如["#自慰","#独处","#18+"]'
            : '你是视频频道运营专家。根据文件名分析内容，生成3-5个中文hashtag标签。'
              '要求：标签描述视频主题，使用"#"开头，只返回JSON数组如["#精彩","#高清","#推荐"]';

        final content = await _callAI(
          baseUrl: baseUrl ?? 'https://api.openai.com/v1',
          apiKey: apiKey,
          model: model ?? 'gpt-3.5-turbo',
          systemPrompt: systemPrompt,
          userPrompt: '视频文件名：$fileName\n请生成3-5个hashtag标签，只返回JSON数组。',
          maxTokens: 120,
          temperature: 0.7,
        );

        if (content != null) {
          final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(content);
          if (jsonMatch != null) {
            final list = jsonDecode(jsonMatch.group(0)!) as List;
            return list
                .map((e) => e.toString().startsWith('#') ? e.toString() : '#${e.toString()}')
                .take(5)
                .toList();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AI tags failed: $e');
      }
    }
    return _defaultTags(fileName, mode);
  }

  // ==================== 生成封面文字 ====================

  Future<String> generateCoverText({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
    String? baseUrl,
    String? presetTexts,  // 预设文字逗号分隔
  }) async {
    // 先尝试AI生成
    if (apiKey != null && apiKey.isNotEmpty) {
      try {
        final systemPrompt = mode == CaptionMode.adult
            ? '你是成人视频封面文案专家。给视频封面生成一句极具吸引力的中文文字（6-12字），'
              '要直接、刺激、引人点击。例如：高潮喷水、操到发抖、无套内射、骚穴特写、疯狂抽插。'
              '只返回文字本身，不要标点符号。'
            : '你是视频封面文案专家。给视频封面生成一句吸引观众的中文标语（6-12字），'
              '要直击痛点、吸引眼球。只返回文字本身，不要标点符号。';

        final content = await _callAI(
          baseUrl: baseUrl ?? 'https://api.openai.com/v1',
          apiKey: apiKey,
          model: model ?? 'gpt-3.5-turbo',
          systemPrompt: systemPrompt,
          userPrompt: '视频文件名：$fileName\n请生成封面文字（6-12字），直接返回文字。',
          maxTokens: 50,
          temperature: 0.9,
        );

        if (content != null && content.trim().isNotEmpty) {
          // 清理多余字符
          return content.trim()
              .replaceAll('"', '')
              .replaceAll('"', '')
              .replaceAll('"', '')
              .replaceAll('\n', '');
        }
      } catch (e) {
        if (kDebugMode) debugPrint('AI cover text failed: $e');
      }
    }

    // 使用预设文字（随机选一个）
    if (presetTexts != null && presetTexts.isNotEmpty) {
      final items = presetTexts.split(',').where((s) => s.trim().isNotEmpty).toList();
      if (items.isNotEmpty) {
        items.shuffle();
        return items.first.trim();
      }
    }

    // 默认文字
    if (mode == CaptionMode.adult) {
      final defaults = ['高清福利', '今日福利', '顶级资源', '私藏精品', '18+限制级'];
      defaults.shuffle();
      return defaults.first;
    }
    return '精彩视频';
  }

  // ==================== 模板生成 ====================

  CaptionResult _generateFromTemplate({
    required String fileName,
    required CaptionMode mode,
    required int partIndex,
    required int totalParts,
    bool enableEmoji = true,
    bool enableTags = true,
  }) {
    final baseName = fileName
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[_\-]'), ' ')
        .trim();

    if (mode == CaptionMode.adult) {
      return _adultTemplate(baseName, partIndex, totalParts, enableEmoji, enableTags);
    }
    return _normalTemplate(baseName, partIndex, totalParts, enableEmoji, enableTags);
  }

  CaptionResult _normalTemplate(String baseName, int part, int total,
      bool enableEmoji, bool enableTags) {
    final e = enableEmoji;
    final titles = [
      '${e ? "🔥 " : ""}精彩视频 P$part${total > 1 ? " | 共${total}集" : ""}',
      '${e ? "💎 " : ""}独家内容 第${part}集${total > 1 ? "/$total" : ""}',
      '${e ? "⭐ " : ""}精品推荐 P$part/${total > 1 ? total.toString() : "1"}',
    ];
    final captions = [
      '${e ? "🔥 " : ""}精彩内容持续更新！高质量视频，每一帧都值得细细品味。\n${e ? "📌 " : ""}关注频道，每天更新优质内容',
      '${e ? "💎 " : ""}独家高清内容！最优质的视频体验，绝对不会让您失望！',
    ];
    final tagSets = [
      ['#精彩视频', '#高清', '#推荐', '#必看'],
      ['#独家内容', '#高清视频', '#每日更新', '#精品'],
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
      tags: enableTags ? tagSets[part % tagSets.length] : [],
    );
  }

  CaptionResult _adultTemplate(String baseName, int part, int total,
      bool enableEmoji, bool enableTags) {
    final lowerName = baseName.toLowerCase();
    final e = enableEmoji;

    final List<String> autoTags = [];
    final keywordMap = {
      'solo': '#自慰', 'masturbat': '#自慰', 'finger': '#手指',
      'toy': '#玩具', 'dildo': '#玩具', 'vibrat': '#震动棒',
      'anal': '#肛交', 'oral': '#口交', 'blowjob': '#口交',
      'lesbian': '#百合', 'massage': '#按摩', 'shower': '#洗澡',
      'outdoor': '#户外', 'office': '#办公室', 'uniform': '#制服',
      'nurse': '#护士', 'teacher': '#老师', 'milf': '#熟女',
      'teen': '#少女', 'asian': '#亚洲', 'japanese': '#日本',
      'chinese': '#华人', 'korean': '#韩国', 'creampie': '#内射',
      'cumshot': '#颜射', '自慰': '#自慰', '口交': '#口交',
      '制服': '#制服', '护士': '#护士', '熟女': '#熟女',
      '户外': '#户外', '内射': '#内射', '无套': '#无套',
    };

    for (final entry in keywordMap.entries) {
      if (lowerName.contains(entry.key)) {
        autoTags.add(entry.value);
        if (autoTags.length >= 3) break;
      }
    }

    for (final t in ['#18+', '#福利', '#高清', '#成人']) {
      if (!autoTags.contains(t)) autoTags.add(t);
      if (autoTags.length >= 5) break;
    }

    final titles = [
      '${e ? "🔞 " : ""}福利来袭 P$part${total > 1 ? "/$total" : ""} | 不可错过',
      '${e ? "💋 " : ""}独家私藏 第${part}集${total > 1 ? " 共${total}集" : ""}',
      '${e ? "🌶️ " : ""}劲爆内容 P$part${total > 1 ? "/$total" : ""} | 限时',
    ];
    final captions = [
      '${e ? "🔞 " : ""}今日精选福利，绝对大饱眼福！${e ? "\n💋 " : "\n"}高清画质，精彩绝伦${e ? "\n🌶️ " : "\n"}内容火辣，18+向\n${e ? "📌 " : ""}关注频道获取每日最新福利',
      '${e ? "💦 " : ""}顶级资源限时分享！${e ? "\n🔥 " : "\n"}精心筛选，品质保证，高清无水印${e ? "\n⚠️ " : "\n"}本内容仅限18岁以上成年人',
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
      tags: enableTags ? autoTags.take(5).toList() : [],
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
