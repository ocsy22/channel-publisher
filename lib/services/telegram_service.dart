import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// 真实 Telegram Bot API 服务
class TelegramService {
  static TelegramService? _instance;
  static TelegramService get instance => _instance ??= TelegramService._();
  TelegramService._();

  static const String _baseUrl = 'https://api.telegram.org';
  static const Duration _timeout = Duration(minutes: 10);

  // ==================== Bot 验证 ====================

  Future<BotInfo?> testConnection(String token) async {
    if (token.isEmpty) throw Exception('Bot Token 不能为空');

    final url = '$_baseUrl/bot$token/getMe';
    if (kDebugMode) debugPrint('TG testConnection: $url');

    final resp = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(resp.body);
    if (data['ok'] == true) {
      final result = data['result'];
      return BotInfo(
        id: result['id'],
        username: '@${result['username']}',
        firstName: result['first_name'] ?? '',
        canJoinGroups: result['can_join_groups'] ?? false,
        canReadMessages: result['can_read_all_group_messages'] ?? false,
      );
    }
    final desc = data['description'] ?? 'Unknown error (${resp.statusCode})';
    throw Exception('Telegram 错误: $desc');
  }

  // ==================== 获取频道信息 ====================

  Future<ChannelInfo?> getChannelInfo(String token, String channelId) async {
    try {
      final resp = await http
          .get(Uri.parse(
              '$_baseUrl/bot$token/getChat?chat_id=${Uri.encodeComponent(channelId)}'))
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        final result = data['result'];
        return ChannelInfo(
          id: result['id'].toString(),
          title: result['title'] ?? channelId,
          username:
              result['username'] != null ? '@${result['username']}' : '',
          type: result['type'] ?? 'channel',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==================== 发送视频 ====================

  /// 发送单个视频（带封面+文案）
  Future<TelegramMessage> sendVideo({
    required String token,
    required String chatId,
    required String videoPath,
    String? coverPath,
    String? caption,
    String? parseMode,
    bool? hasSpoiler,
    void Function(int sent, int total)? onProgress,
  }) async {
    // 验证文件
    final videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      throw Exception('视频文件不存在: $videoPath');
    }
    final videoSize = videoFile.lengthSync();
    if (videoSize == 0) {
      throw Exception('视频文件为空: $videoPath');
    }
    // Telegram 视频限制 2GB
    if (videoSize > 2 * 1024 * 1024 * 1024) {
      throw Exception(
          '视频文件超过 2GB 限制: ${(videoSize / 1024 / 1024).toStringAsFixed(0)} MB');
    }

    if (kDebugMode) {
      debugPrint(
          'TG sendVideo: chatId=$chatId file=${videoFile.uri.pathSegments.last} size=${(videoSize / 1024 / 1024).toStringAsFixed(1)}MB');
    }

    final uri = Uri.parse('$_baseUrl/bot$token/sendVideo');
    final request = http.MultipartRequest('POST', uri);
    request.fields['chat_id'] = chatId;

    if (caption != null && caption.isNotEmpty) {
      // Telegram caption 限制 1024 字符
      final cap =
          caption.length > 1024 ? caption.substring(0, 1020) + '...' : caption;
      request.fields['caption'] = cap;
      request.fields['parse_mode'] = parseMode ?? 'HTML';
    }

    if (hasSpoiler == true) {
      request.fields['has_spoiler'] = 'true';
    }

    // 添加视频文件
    request.files.add(await http.MultipartFile.fromPath(
      'video',
      videoPath,
      filename: videoFile.uri.pathSegments.last,
    ));

    // 添加封面（thumbnail）
    if (coverPath != null && coverPath.isNotEmpty) {
      final coverFile = File(coverPath);
      if (coverFile.existsSync()) {
        request.files.add(await http.MultipartFile.fromPath(
          'thumbnail',
          coverPath,
          filename: 'cover.jpg',
        ));
      }
    }

    onProgress?.call(0, videoSize);

    final streamedResp = await request.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamedResp);

    onProgress?.call(videoSize, videoSize);

    if (kDebugMode) {
      debugPrint(
          'TG sendVideo response: ${resp.statusCode} body=${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');
    }

    final data = jsonDecode(resp.body);
    if (data['ok'] == true) {
      final result = data['result'];
      return TelegramMessage(
        messageId: result['message_id'],
        date: result['date'],
        chatId: chatId,
      );
    }

    final errorDesc = data['description'] ?? resp.body;
    // 常见错误提示
    String hint = '';
    if (errorDesc.contains('chat not found')) {
      hint = '\n💡 提示：请确认频道ID正确，Bot已被添加为管理员';
    } else if (errorDesc.contains('not enough rights') ||
        errorDesc.contains('CHAT_WRITE_FORBIDDEN')) {
      hint = '\n💡 提示：Bot 没有发送消息权限，请在频道设置中将Bot设为管理员并开启"发帖"权限';
    } else if (errorDesc.contains('wrong file identifier') ||
        errorDesc.contains('Bad Request')) {
      hint = '\n💡 提示：文件格式可能不被支持，请确认视频为MP4格式';
    }

    throw Exception('Telegram API 错误: $errorDesc$hint');
  }

  /// 发送媒体组（多个视频一起发）
  Future<List<TelegramMessage>> sendMediaGroup({
    required String token,
    required String chatId,
    required List<MediaItem> items,
    String? caption,
  }) async {
    if (items.isEmpty) throw Exception('媒体组不能为空');
    if (items.length > 10)
      throw Exception('媒体组最多10个，当前：${items.length}');

    final uri = Uri.parse('$_baseUrl/bot$token/sendMediaGroup');
    final request = http.MultipartRequest('POST', uri);
    request.fields['chat_id'] = chatId;

    final mediaList = <Map<String, dynamic>>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final file = File(item.filePath);
      if (!file.existsSync()) {
        if (kDebugMode) debugPrint('Skipping missing file: ${item.filePath}');
        continue;
      }

      final attachName = 'file$i';
      request.files.add(await http.MultipartFile.fromPath(
        attachName,
        item.filePath,
        filename: file.uri.pathSegments.last,
      ));

      final mediaEntry = <String, dynamic>{
        'type': item.type == MediaType.video ? 'video' : 'photo',
        'media': 'attach://$attachName',
      };

      if (i == 0 && caption != null && caption.isNotEmpty) {
        mediaEntry['caption'] = caption.length > 1024
            ? caption.substring(0, 1020) + '...'
            : caption;
        mediaEntry['parse_mode'] = 'HTML';
      }

      if (item.coverPath != null) {
        final thumbFile = File(item.coverPath!);
        if (thumbFile.existsSync()) {
          final thumbName = 'thumb$i';
          request.files.add(await http.MultipartFile.fromPath(
            thumbName,
            item.coverPath!,
            filename: 'cover$i.jpg',
          ));
          mediaEntry['thumbnail'] = 'attach://$thumbName';
        }
      }

      mediaList.add(mediaEntry);
    }

    if (mediaList.isEmpty) throw Exception('没有有效的媒体文件');

    request.fields['media'] = jsonEncode(mediaList);

    final streamedResp = await request.send().timeout(_timeout);
    final resp = await http.Response.fromStream(streamedResp);

    final data = jsonDecode(resp.body);
    if (data['ok'] == true) {
      final results = data['result'] as List;
      return results
          .map((r) => TelegramMessage(
                messageId: r['message_id'],
                date: r['date'],
                chatId: chatId,
              ))
          .toList();
    }
    throw Exception(
        'Telegram 媒体组发送失败: ${data['description'] ?? resp.body}');
  }

  /// 只发送文字消息（测试用）
  Future<TelegramMessage> sendMessage({
    required String token,
    required String chatId,
    required String text,
    String parseMode = 'HTML',
  }) async {
    final resp = await http
        .post(
          Uri.parse('$_baseUrl/bot$token/sendMessage'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'chat_id': chatId,
            'text': text,
            'parse_mode': parseMode,
          }),
        )
        .timeout(const Duration(seconds: 30));

    final data = jsonDecode(resp.body);
    if (data['ok'] == true) {
      return TelegramMessage(
        messageId: data['result']['message_id'],
        date: data['result']['date'],
        chatId: chatId,
      );
    }
    throw Exception('sendMessage 失败: ${data['description']}');
  }

  /// 发送图片
  Future<TelegramMessage> sendPhoto({
    required String token,
    required String chatId,
    required String photoPath,
    String? caption,
  }) async {
    final uri = Uri.parse('$_baseUrl/bot$token/sendPhoto');
    final request = http.MultipartRequest('POST', uri);
    request.fields['chat_id'] = chatId;
    if (caption != null && caption.isNotEmpty) {
      request.fields['caption'] = caption;
      request.fields['parse_mode'] = 'HTML';
    }
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      photoPath,
      filename: 'cover.jpg',
    ));

    final streamedResp =
        await request.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamedResp);
    final data = jsonDecode(resp.body);
    if (data['ok'] == true) {
      return TelegramMessage(
        messageId: data['result']['message_id'],
        date: data['result']['date'],
        chatId: chatId,
      );
    }
    throw Exception('sendPhoto 失败: ${data['description']}');
  }
}

// ==================== 数据模型 ====================

class BotInfo {
  final int id;
  final String username;
  final String firstName;
  final bool canJoinGroups;
  final bool canReadMessages;

  BotInfo({
    required this.id,
    required this.username,
    required this.firstName,
    required this.canJoinGroups,
    required this.canReadMessages,
  });
}

class ChannelInfo {
  final String id;
  final String title;
  final String username;
  final String type;

  ChannelInfo({
    required this.id,
    required this.title,
    required this.username,
    required this.type,
  });
}

class TelegramMessage {
  final int messageId;
  final int date;
  final String chatId;

  TelegramMessage({
    required this.messageId,
    required this.date,
    required this.chatId,
  });
}

class MediaItem {
  final String filePath;
  final String? coverPath;
  final MediaType type;

  MediaItem({
    required this.filePath,
    this.coverPath,
    this.type = MediaType.video,
  });
}

enum MediaType { video, photo }
