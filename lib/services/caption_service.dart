import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

enum CaptionMode {
  normal,   // 普通内容
  adult,    // 成人内容
}

class CaptionService {
  static CaptionService? _instance;
  static CaptionService get instance => _instance ??= CaptionService._();
  CaptionService._();

  // ==================== AI 生成文案（OpenAI 兼容 API）====================

  Future<CaptionResult> generateCaption({
    required String fileName,
    required CaptionMode mode,
    String? apiKey,
    String? model,
    String? customPrompt,
    int partIndex = 1,
    int totalParts = 1,
  }) async {
    // 有 API key 就用 AI，否则用本地模板
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
        if (kDebugMode) debugPrint('AI caption failed, using template: $e');
      }
    }
    // 回退到本地模板
    return _generateFromTemplate(
      fileName: fileName,
      mode: mode,
      partIndex: partIndex,
      totalParts: totalParts,
    );
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
        ? '''你是一个专业的成人内容频道运营者，专门为成人视频频道创作吸引人的标题和描述。
要求：
- 标题要吸引眼球，暗示性强但不过分直白
- 描述要勾起好奇心，使用暗示性语言
- 加入相关emoji
- 使用中文
- 加上相关hashtag（#成人 #福利 等）
- 风格：神秘、诱惑、吸引力'''
        : '''你是一个专业的视频频道运营者，专门为视频频道创作吸引人的标题和描述。
要求：
- 标题简洁有力，吸引点击
- 描述突出视频亮点
- 加入相关emoji
- 使用中文
- 加上相关hashtag''';

    final userContent = customPrompt?.isNotEmpty == true
        ? customPrompt!
        : '''视频文件名：$fileName
这是第 $partIndex 部分，共 $totalParts 部分
请生成一个吸引人的标题和描述文案。
返回JSON格式：{"title": "标题", "caption": "描述文案"}''';

    final resp = await http.post(
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
        'max_tokens': 500,
        'temperature': 0.8,
      }),
    ).timeout(const Duration(seconds: 30));

    if (resp.statusCode != 200) {
      throw Exception('OpenAI API error ${resp.statusCode}: ${resp.body}');
    }

    final data = jsonDecode(resp.body);
    final content = data['choices'][0]['message']['content'] as String;

    // 尝试解析 JSON
    try {
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(content);
      if (jsonMatch != null) {
        final parsed = jsonDecode(jsonMatch.group(0)!);
        return CaptionResult(
          title: parsed['title'] ?? _defaultTitle(mode, partIndex),
          caption: parsed['caption'] ?? content,
        );
      }
    } catch (_) {}

    // 解析失败直接用原文
    return CaptionResult(
      title: _defaultTitle(mode, partIndex),
      caption: content,
    );
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
      '🔥 精彩视频 P$part ${total > 1 ? "| 共$total集" : ""}',
      '💎 独家内容 第$part集 ${total > 1 ? "/$total" : ""}',
      '⭐ 精品推荐 P$part${total > 1 ? "/$total" : ""} | 高清必看',
      '🎯 今日精选 第$part期${total > 1 ? " 共$total期" : ""}',
    ];
    final captions = [
      '🔥 精彩内容持续更新！\n\n'
      '这是一段精心制作的高质量视频内容，每一帧都值得细细品味。\n\n'
      '📌 关注频道，每天更新优质内容\n'
      '💬 欢迎转发分享给好友\n\n'
      '#精彩视频 #高清 #推荐 #必看',

      '💎 独家高清内容分享！\n\n'
      '本期为您带来最优质的视频体验，绝对不会让您失望！\n\n'
      '🔔 开启通知，不错过每次更新\n'
      '👍 喜欢请转发支持\n\n'
      '#独家 #高清 #精品 #每日更新',
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
    );
  }

  CaptionResult _adultTemplate(String baseName, int part, int total) {
    final titles = [
      '🔞 福利来袭 P$part${total > 1 ? "/$total" : ""} | 不可错过',
      '💋 独家私藏 第$part集${total > 1 ? " 共$total集" : ""} | 高清无码',
      '🌶️ 劲爆内容 P$part${total > 1 ? "/$total" : ""} | 限时分享',
      '🔥 顶级资源 第$part期${total > 1 ? "/$total" : ""} | 收藏必备',
      '💦 今日福利 P$part${total > 1 ? "/$total" : ""} | 高清私享',
    ];
    final captions = [
      '🔞 今日精选福利内容，绝对让你大饱眼福！\n\n'
      '💋 高清画质，精彩绝伦，不看后悔！\n'
      '🌶️ 内容火辣，成人向，请确认年龄后观看\n\n'
      '📌 关注频道获取每日最新福利\n'
      '🔔 开启通知第一时间收到更新\n\n'
      '#福利 #成人 #高清 #私藏 #每日更新',

      '💦 顶级资源限时分享！\n\n'
      '🔥 精心筛选，品质保证，高清无水印\n'
      '💋 喜欢的朋友快快收藏转发！\n\n'
      '⚠️ 本内容仅限18岁以上成年人观看\n'
      '📲 关注频道，每天更新海量资源\n\n'
      '#成人福利 #高清资源 #18+ #必看 #收藏',

      '🌶️ 私藏精品，今日限定分享！\n\n'
      '每一个细节都经过精心挑选，只为给你最好的体验。\n'
      '🔞 成人内容，18+观看\n\n'
      '💬 想要更多？关注频道每日更新\n'
      '❤️ 觉得好看请转发给朋友\n\n'
      '#福利视频 #成人内容 #18禁 #高清 #精品',
    ];

    return CaptionResult(
      title: titles[part % titles.length],
      caption: captions[part % captions.length],
    );
  }

  String _defaultTitle(CaptionMode mode, int part) {
    return mode == CaptionMode.adult
        ? '🔞 福利内容 P$part'
        : '🎬 精彩视频 P$part';
  }
}

class CaptionResult {
  final String title;
  final String caption;

  CaptionResult({required this.title, required this.caption});
}
