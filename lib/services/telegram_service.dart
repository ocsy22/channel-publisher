import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as http_io;

/// Telegram Bot API 服务
/// 支持：自定义HttpClient绕过所有SSL证书验证（代理/VPN/企业网络环境）
class TelegramService {
  static TelegramService? _instance;
  static TelegramService get instance => _instance ??= TelegramService._();
  TelegramService._();

  static const String _baseUrl = 'https://api.telegram.org';
  static const Duration _timeout = Duration(minutes: 10);

  // 是否忽略SSL错误，默认true（支持代理/VPN环境）
  bool _ignoreSslErrors = true;

  void setIgnoreSslErrors(bool ignore) {
    _ignoreSslErrors = ignore;
    if (kDebugMode) debugPrint('TelegramService: ignoreSsl=$ignore');
  }

  /// 创建HTTP客户端 - 根据配置决定是否绕过SSL验证
  http.Client _createHttpClient({bool? forceIgnoreSsl}) {
    if (kIsWeb) return http.Client();
    final shouldIgnore = forceIgnoreSsl ?? _ignoreSslErrors;
    
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 30);
    
    if (shouldIgnore) {
      // 完全忽略所有SSL证书错误（支持VPN/代理/企业防火墙）
      httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
        if (kDebugMode) {
          debugPrint('⚠️ SSL证书绕过: host=$host port=$port '
              'issuer=${cert.issuer} subject=${cert.subject}');
        }
        return true; // 始终允许
      };
    }
    
    return http_io.IOClient(httpClient);
  }

  /// GET请求
  Future<http.Response> _get(String url, {Duration? timeout}) async {
    if (kDebugMode) debugPrint('TG GET: $url (ignoreSsl=$_ignoreSslErrors)');
    final client = _createHttpClient();
    try {
      final resp = await client
          .get(Uri.parse(url))
          .timeout(timeout ?? const Duration(seconds: 20));
      if (kDebugMode) {
        debugPrint('TG GET resp: ${resp.statusCode} len=${resp.body.length}');
      }
      return resp;
    } on HandshakeException catch (e) {
      if (kDebugMode) debugPrint('TG HandshakeException: $e');
      rethrow;
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('TG SocketException: $e');
      rethrow;
    } on TimeoutException catch (e) {
      if (kDebugMode) debugPrint('TG TimeoutException: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  /// POST JSON请求
  Future<http.Response> _postJson(String url, Map<String, dynamic> body,
      {Duration? timeout}) async {
    if (kDebugMode) debugPrint('TG POST: $url body=${jsonEncode(body)}');
    final client = _createHttpClient();
    try {
      final resp = await client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(body),
          )
          .timeout(timeout ?? const Duration(seconds: 30));
      if (kDebugMode) {
        debugPrint('TG POST resp: ${resp.statusCode} body=${resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body}');
      }
      return resp;
    } on HandshakeException catch (e) {
      if (kDebugMode) debugPrint('TG POST HandshakeException: $e');
      rethrow;
    } on SocketException catch (e) {
      if (kDebugMode) debugPrint('TG POST SocketException: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  // ==================== Bot 验证 ====================

  /// 测试Bot连接
  /// 返回BotInfo，失败抛出详细异常
  Future<BotInfo> testConnection(String token) async {
    if (token.isEmpty) throw Exception('Bot Token 不能为空');

    final token_ = token.trim();
    if (!RegExp(r'^\d+:[A-Za-z0-9_-]{35,}$').hasMatch(token_)) {
      throw Exception(
          '❌ Token格式错误！\n\n'
          '正确格式：123456789:ABCDEFGabcdef...\n'
          '请从 @BotFather 获取正确的Token');
    }

    final url = '$_baseUrl/bot$token_/getMe';
    if (kDebugMode) debugPrint('TG testConnection URL: $url ignoreSsl=$_ignoreSslErrors');

    http.Response resp;
    try {
      resp = await _get(url, timeout: const Duration(seconds: 25));
    } on HandshakeException catch (e) {
      throw Exception(
          '❌ SSL握手失败\n\n'
          '错误详情：${e.message}\n\n'
          '解决方法：\n'
          '1. 点击"忽略SSL证书"开关（已默认开启）\n'
          '2. 如果已开启仍然失败，请检查网络代理设置\n'
          '3. 确认能访问 api.telegram.org');
    } on SocketException catch (e) {
      throw Exception(
          '❌ 网络连接失败\n\n'
          '错误：${e.message}\n\n'
          '解决方法：\n'
          '1. 检查网络连接\n'
          '2. 确认能访问 api.telegram.org\n'
          '3. 如在中国大陆，需要开启VPN/代理');
    } on TimeoutException {
      throw Exception(
          '❌ 连接超时（25秒）\n\n'
          '解决方法：\n'
          '1. 检查网络速度\n'
          '2. 确认Telegram在你的网络可访问\n'
          '3. 尝试开启/切换VPN节点');
    }

    if (kDebugMode) {
      debugPrint('TG testConnection response: ${resp.statusCode} body=${resp.body}');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body);
    } catch (e) {
      throw Exception('❌ 响应解析失败 (HTTP ${resp.statusCode}): ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');
    }

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

    final code = data['error_code'] ?? resp.statusCode;
    final desc = data['description'] ?? '未知错误';
    
    String hint = '';
    if (code == 401) {
      hint = '\n\n💡 Token无效，请重新从 @BotFather 获取';
    } else if (code == 404) {
      hint = '\n\n💡 Bot不存在，请检查Token是否完整';
    }
    throw Exception('❌ Telegram API 错误 (code: $code): $desc$hint');
  }

  // ==================== 获取频道信息 ====================

  Future<ChannelInfo?> getChannelInfo(String token, String channelId) async {
    try {
      final resp = await _get(
        '$_baseUrl/bot$token/getChat?chat_id=${Uri.encodeComponent(channelId)}',
        timeout: const Duration(seconds: 15),
      );
      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        final result = data['result'];
        return ChannelInfo(
          id: result['id'].toString(),
          title: result['title'] ?? channelId,
          username: result['username'] != null ? '@${result['username']}' : '',
          type: result['type'] ?? 'channel',
        );
      }
      if (kDebugMode) debugPrint('getChannelInfo failed: ${data['description']}');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('getChannelInfo error: $e');
      return null;
    }
  }

  // ==================== 发送视频 ====================

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
    if (kIsWeb) throw Exception('Web平台不支持文件上传，请使用Windows客户端');
    
    // 验证文件
    final videoFile = File(videoPath);
    if (!videoFile.existsSync()) {
      throw Exception('视频文件不存在: $videoPath');
    }
    final videoSize = videoFile.lengthSync();
    if (videoSize == 0) throw Exception('视频文件为空: $videoPath');
    if (videoSize > 2 * 1024 * 1024 * 1024) {
      throw Exception(
          '视频超过2GB: ${(videoSize / 1024 / 1024).toStringAsFixed(0)}MB，Telegram限制单文件2GB');
    }

    if (kDebugMode) {
      debugPrint('TG sendVideo: chatId=$chatId '
          'file=${videoFile.uri.pathSegments.last} '
          'size=${(videoSize / 1024 / 1024).toStringAsFixed(1)}MB '
          'ignoreSsl=$_ignoreSslErrors');
    }

    final uri = Uri.parse('$_baseUrl/bot$token/sendVideo');
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 60);
    if (_ignoreSslErrors) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }
    final ioClient = http_io.IOClient(httpClient);

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = chatId;

      if (caption != null && caption.isNotEmpty) {
        // 去掉HTML标签中的特殊字符，避免parse_mode报错
        final cap = caption.length > 1024
            ? '${caption.substring(0, 1020)}...'
            : caption;
        request.fields['caption'] = cap;
        request.fields['parse_mode'] = parseMode ?? 'HTML';
      }

      if (hasSpoiler == true) request.fields['has_spoiler'] = 'true';

      request.files.add(await http.MultipartFile.fromPath(
        'video',
        videoPath,
        filename: videoFile.uri.pathSegments.last,
      ));

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

      final streamedResp = await ioClient.send(request).timeout(_timeout);
      final resp = await http.Response.fromStream(streamedResp);

      onProgress?.call(videoSize, videoSize);

      if (kDebugMode) {
        debugPrint('TG sendVideo response: ${resp.statusCode} '
            'body=${resp.body.length > 400 ? resp.body.substring(0, 400) : resp.body}');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body);
      } catch (e) {
        throw Exception('响应解析失败(${resp.statusCode}): ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');
      }

      if (data['ok'] == true) {
        final result = data['result'];
        return TelegramMessage(
          messageId: result['message_id'],
          date: result['date'],
          chatId: chatId,
        );
      }

      final errorCode = data['error_code'] ?? resp.statusCode;
      final errorDesc = data['description'] ?? resp.body;
      String hint = '';
      if (errorDesc.toString().contains('chat not found')) {
        hint = '\n💡 频道ID错误，格式应为 @channelname 或 -100xxxxxxxxx\n💡 确认Bot已被添加为频道管理员';
      } else if (errorDesc.toString().contains('not enough rights') ||
          errorDesc.toString().contains('CHAT_WRITE_FORBIDDEN') ||
          errorDesc.toString().contains('have no rights')) {
        hint = '\n💡 Bot缺少发帖权限！\n请到频道设置→管理员→你的Bot→开启"发送消息"权限';
      } else if (errorDesc.toString().contains('wrong file') ||
          errorDesc.toString().contains('Bad Request')) {
        hint = '\n💡 文件格式问题，确认视频为MP4格式';
      } else if (errorCode == 429) {
        hint = '\n💡 请求频率过快，请等待后重试';
      }
      throw Exception('Telegram API 错误 ($errorCode): $errorDesc$hint');
    } on HandshakeException catch (e) {
      throw Exception('SSL握手失败（${e.message}）\n请在设置中开启"忽略SSL证书"选项');
    } on SocketException catch (e) {
      throw Exception('网络连接失败（${e.message}）\n请检查网络和VPN设置');
    } on TimeoutException {
      throw Exception('上传超时！视频文件可能过大或网络速度过慢');
    } finally {
      ioClient.close();
    }
  }

  /// 发送媒体组（最多10个）
  Future<List<TelegramMessage>> sendMediaGroup({
    required String token,
    required String chatId,
    required List<MediaItem> items,
    String? caption,
  }) async {
    if (items.isEmpty) throw Exception('媒体组为空');
    if (items.length > 10) throw Exception('媒体组最多10个，当前：${items.length}');

    final uri = Uri.parse('$_baseUrl/bot$token/sendMediaGroup');

    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 60);
    if (_ignoreSslErrors) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }
    final ioClient = http_io.IOClient(httpClient);

    try {
      final request = http.MultipartRequest('POST', uri);
      request.fields['chat_id'] = chatId;
      final mediaList = <Map<String, dynamic>>[];

      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final file = File(item.filePath);
        if (!file.existsSync()) {
          if (kDebugMode) debugPrint('Media file not found: ${item.filePath}');
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
          mediaEntry['caption'] =
              caption.length > 1024 ? '${caption.substring(0, 1020)}...' : caption;
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

      final streamedResp = await ioClient.send(request).timeout(_timeout);
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
      throw Exception('媒体组发送失败: ${data['description'] ?? resp.body}');
    } on HandshakeException catch (e) {
      throw Exception('SSL握手失败（请开启忽略SSL设置）: ${e.message}');
    } finally {
      ioClient.close();
    }
  }

  /// 发送文字消息
  Future<TelegramMessage> sendMessage({
    required String token,
    required String chatId,
    required String text,
    String parseMode = 'HTML',
  }) async {
    try {
      final resp = await _postJson(
        '$_baseUrl/bot$token/sendMessage',
        {
          'chat_id': chatId,
          'text': text,
          'parse_mode': parseMode,
        },
        timeout: const Duration(seconds: 30),
      );

      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        return TelegramMessage(
          messageId: data['result']['message_id'],
          date: data['result']['date'],
          chatId: chatId,
        );
      }
      final code = data['error_code'] ?? resp.statusCode;
      final desc = data['description'] ?? '未知错误';
      String hint = '';
      if (code == 400 && desc.toString().contains('chat not found')) {
        hint = '\n💡 频道ID不正确，请检查格式(@channel 或 -100xxxx)';
      } else if (desc.toString().contains('not enough rights')) {
        hint = '\n💡 Bot没有发帖权限，请在频道管理员中开启';
      }
      throw Exception('sendMessage失败 (code=$code): $desc$hint');
    } on HandshakeException catch (e) {
      throw Exception('SSL握手失败（请开启忽略SSL设置）: ${e.message}');
    }
  }

  /// 发送图片
  Future<TelegramMessage> sendPhoto({
    required String token,
    required String chatId,
    required String photoPath,
    String? caption,
  }) async {
    final uri = Uri.parse('$_baseUrl/bot$token/sendPhoto');

    final httpClient = HttpClient();
    if (_ignoreSslErrors) {
      httpClient.badCertificateCallback = (cert, host, port) => true;
    }
    final ioClient = http_io.IOClient(httpClient);

    try {
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
          await ioClient.send(request).timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamedResp);
      final data = jsonDecode(resp.body);
      if (data['ok'] == true) {
        return TelegramMessage(
          messageId: data['result']['message_id'],
          date: data['result']['date'],
          chatId: chatId,
        );
      }
      throw Exception('sendPhoto失败: ${data['description']}');
    } finally {
      ioClient.close();
    }
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
