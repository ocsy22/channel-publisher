import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
import '../services/ffmpeg_service.dart';
import '../services/telegram_service.dart';
import '../services/caption_service.dart';
import '../utils/io_helper.dart' if (dart.library.html) '../utils/io_helper_web.dart';

class AppProvider extends ChangeNotifier {
  final _uuid = const Uuid();

  // ==================== 状态 ====================
  int _selectedNav = 0;
  int get selectedNav => _selectedNav;

  BotConfig _botConfig = BotConfig();
  BotConfig get botConfig => _botConfig;

  String _watchFolder = '';
  String get watchFolder => _watchFolder;

  List<VideoFile> _videos = [];
  List<VideoFile> get videos => _videos;

  VideoFile? _selectedVideo;
  VideoFile? get selectedVideo => _selectedVideo;

  // 多选发布用的选中集合
  final Set<String> _selectedSliceIds = {};
  Set<String> get selectedSliceIds => _selectedSliceIds;

  List<PublishTask> _tasks = [];
  List<PublishTask> get tasks => _tasks;

  List<PublishRecord> _history = [];
  List<PublishRecord> get history => _history;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  BotInfo? _botInfo;
  BotInfo? get botInfo => _botInfo;

  bool _ffmpegAvailable = false;
  bool get ffmpegAvailable => _ffmpegAvailable;
  String _ffmpegVersion = '检测中...';
  String get ffmpegVersion => _ffmpegVersion;

  String _logOutput = '';
  String get logOutput => _logOutput;

  // 统计
  int get totalPublished => _history.length;
  int get totalProcessing =>
      _videos.where((v) => v.status == VideoStatus.processing).length;
  int get totalPending =>
      _videos.where((v) => v.status == VideoStatus.pending).length;
  int get totalReady =>
      _videos.where((v) => v.status == VideoStatus.ready).length;

  AppProvider() {
    _loadSettings();
    _checkFfmpeg();
  }

  // ==================== 导航 ====================
  void setNav(int index) {
    _selectedNav = index;
    notifyListeners();
  }

  // ==================== ffmpeg 检测 ====================
  Future<void> _checkFfmpeg() async {
    try {
      _ffmpegAvailable = await FfmpegService.instance.isAvailable();
      if (_ffmpegAvailable) {
        _ffmpegVersion = await FfmpegService.instance.getVersion();
        _addLog('✅ ffmpeg 已检测到');
      } else {
        _ffmpegVersion = '未找到';
        _addLog('⚠️ 未检测到 ffmpeg，视频处理功能不可用');
        _addLog('💡 请下载 ffmpeg 并放到与 exe 同目录或系统 PATH');
        _addLog('   下载地址：https://www.gyan.dev/ffmpeg/builds/');
      }
    } catch (e) {
      _ffmpegAvailable = false;
      _ffmpegVersion = '未找到';
      _addLog('⚠️ ffmpeg 未找到: $e');
    }
    notifyListeners();
  }

  // ==================== 设置 ====================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('bot_config');
      if (configJson != null) {
        _botConfig = BotConfig.fromJson(jsonDecode(configJson));
        // 同步SSL设置到服务
        _syncSslSetting();
      }
      _watchFolder = prefs.getString('watch_folder') ?? '';
      // 加载历史记录
      final historyJson = prefs.getString('publish_history');
      if (historyJson != null) {
        final list = jsonDecode(historyJson) as List;
        _history = list.map((e) => PublishRecord.fromJson(e)).toList();
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Load settings error: $e');
    }
  }

  /// 同步SSL设置到各服务
  void _syncSslSetting() {
    TelegramService.instance.setIgnoreSslErrors(_botConfig.ignoreSslErrors);
    CaptionService.instance.setIgnoreSsl(_botConfig.ignoreSslErrors);
    if (kDebugMode) debugPrint('SSL setting synced: ignoreSsl=${_botConfig.ignoreSslErrors}');
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bot_config', jsonEncode(_botConfig.toJson()));
      await prefs.setString('watch_folder', _watchFolder);
    } catch (e) {
      if (kDebugMode) debugPrint('Save settings error: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'publish_history',
        jsonEncode(_history.take(200).map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }

  void updateBotConfig(BotConfig config) {
    _botConfig = config;
    // 重置连接状态（token改变后需重新连接）
    _botConfig.isConnected = false;
    _botInfo = null;
    // 同步SSL设置到服务层
    _syncSslSetting();
    saveSettings();
    notifyListeners();
  }

  void setWatchFolder(String path) {
    _watchFolder = path;
    saveSettings();
    _addLog('📁 监控文件夹: $path');
    notifyListeners();
  }

  // ==================== 获取输出目录 ====================

  /// 获取切片/封面输出根目录
  /// 优先使用用户自定义目录，否则使用系统AppData避免默认C盘
  Future<String> _getOutputBaseDir() async {
    // 用户自定义目录
    if (_botConfig.outputDir.isNotEmpty) {
      final customDir = Directory(_botConfig.outputDir);
      try {
        if (!customDir.existsSync()) {
          customDir.createSync(recursive: true);
        }
        _addLog('📂 使用自定义输出目录: ${_botConfig.outputDir}');
        return _botConfig.outputDir;
      } catch (e) {
        _addLog('⚠️ 自定义目录不可用: $e，使用默认目录');
      }
    }
    // 默认使用系统ApplicationDocuments（通常不在C盘，或用户数据盘）
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final outputDir = p.join(docsDir.path, 'ChannelPublisher');
      await Directory(outputDir).create(recursive: true);
      return outputDir;
    } catch (_) {
      // 最后回退到AppSupport
      final appDir = await getApplicationSupportDirectory();
      return appDir.path;
    }
  }

  // ==================== Bot 连接（真实 API）====================
  Future<bool> testBotConnection() async {
    if (_botConfig.botToken.isEmpty) {
      _addLog('❌ 请先填写 Bot Token');
      return false;
    }
    _isConnecting = true;
    notifyListeners();

    // 同步最新SSL设置
    _syncSslSetting();
    _addLog('🔗 正在连接 Telegram (忽略SSL=${_botConfig.ignoreSslErrors})...');

    try {
      final info = await TelegramService.instance.testConnection(_botConfig.botToken);
      _botInfo = info;
      _botConfig.isConnected = true;
      _addLog('✅ Bot 连接成功！Bot: ${info.username} (${info.firstName}) ID:${info.id}');

      // 获取频道信息
      if (_botConfig.channelId.isNotEmpty) {
        _addLog('📢 正在获取频道信息...');
        final chInfo = await TelegramService.instance.getChannelInfo(
          _botConfig.botToken,
          _botConfig.channelId,
        );
        if (chInfo != null) {
          _botConfig.channelName = chInfo.title;
          _addLog('📢 频道: ${chInfo.title} (${chInfo.id}) 类型:${chInfo.type}');
        } else {
          _addLog('⚠️ 未能获取频道信息，请确认频道ID格式正确且Bot已加入频道');
        }
      }

      saveSettings();
      _isConnecting = false;
      notifyListeners();
      return true;
    } catch (e) {
      _botConfig.isConnected = false;
      _addLog('❌ 连接失败: $e');
      _isConnecting = false;
      notifyListeners();
      return false;
    }
  }

  // ==================== 视频管理 ====================
  void selectVideo(VideoFile? video) {
    _selectedVideo = video;
    notifyListeners();
  }

  void addVideosFromPicker(List<PlatformFile> files) {
    int added = 0;
    for (final file in files) {
      final fileName = file.name;
      final key = file.path ?? 'web://$fileName';
      final exists = _videos.any((v) => v.path == key);
      if (!exists) {
        final video = VideoFile(
          id: _uuid.v4(),
          path: key,
          fileName: fileName,
          duration: 0,
          fileSize: file.size,
        );
        _videos.add(video);
        added++;
        _addLog('➕ 添加: $fileName');
        // 异步获取真实视频信息
        _loadVideoInfo(video);
      }
    }
    if (added > 0 && _selectedVideo == null) {
      _selectedVideo = _videos.first;
    }
    notifyListeners();
  }

  Future<void> _loadVideoInfo(VideoFile video) async {
    if (!_ffmpegAvailable || video.path.startsWith('web://')) return;
    try {
      final info = await FfmpegService.instance.getVideoInfo(video.path);
      video.duration = info.duration;
      video.fileSize = info.fileSize > 0 ? info.fileSize : video.fileSize;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> scanFolder(String folderPath) async {
    setWatchFolder(folderPath);
    final videoExts = [
      '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', '.ts'
    ];
    int added = 0;

    if (!kIsWeb) {
      try {
        await for (final entityPath in listDirectory(folderPath)) {
          final name =
              entityPath.split('/').last.split('\\').last;
          final ext = name.contains('.')
              ? '.${name.split('.').last.toLowerCase()}'
              : '';
          if (videoExts.contains(ext) &&
              !_videos.any((v) => v.path == entityPath)) {
            final video = VideoFile(
              id: _uuid.v4(),
              path: entityPath,
              fileName: name,
              duration: 0,
              fileSize: 0,
            );
            try {
              final stat = await File(entityPath).stat();
              video.fileSize = stat.size;
            } catch (_) {}
            _videos.add(video);
            added++;
            _addLog('➕ 发现: $name');
            _loadVideoInfo(video);
          }
        }
        if (added > 0 && _selectedVideo == null) {
          _selectedVideo = _videos.first;
        }
        _addLog('📁 扫描完成，发现 $added 个视频');
        notifyListeners();
        return;
      } catch (e) {
        _addLog('⚠️ 扫描失败: $e');
      }
    }

    _addLog('⚠️ Web 模式不支持文件夹扫描，请直接添加视频文件');
    notifyListeners();
  }

  void removeVideo(String id) {
    _videos.removeWhere((v) => v.id == id);
    if (_selectedVideo?.id == id) {
      _selectedVideo = _videos.isNotEmpty ? _videos.first : null;
    }
    notifyListeners();
  }

  // ==================== 多选管理 ====================
  void toggleSliceSelection(String sliceId) {
    if (_selectedSliceIds.contains(sliceId)) {
      _selectedSliceIds.remove(sliceId);
    } else {
      _selectedSliceIds.add(sliceId);
    }
    notifyListeners();
  }

  void selectAllSlices(VideoFile video) {
    for (final s in video.slices) {
      _selectedSliceIds.add(s.id);
    }
    notifyListeners();
  }

  void clearSliceSelection() {
    _selectedSliceIds.clear();
    notifyListeners();
  }

  bool isSliceSelected(String sliceId) => _selectedSliceIds.contains(sliceId);

  // ==================== 视频处理（真实 ffmpeg）====================
  Future<void> processVideo(VideoFile video) async {
    if (video.status == VideoStatus.processing) return;
    if (!_ffmpegAvailable) {
      _addLog('❌ ffmpeg 未安装，无法处理视频');
      _addLog('💡 请下载 ffmpeg.exe 放到程序同目录');
      video.status = VideoStatus.failed;
      video.errorMessage = 'ffmpeg 未找到，请安装后重试';
      notifyListeners();
      return;
    }

    video.status = VideoStatus.processing;
    video.progress = 0;
    video.slices.clear();
    notifyListeners();

    _addLog('🎬 开始处理: ${video.fileName}');

    try {
      // 获取输出基础目录（自定义或默认）
      final baseOutputDir = await _getOutputBaseDir();
      final outputDir = p.join(baseOutputDir, 'slices', video.id);
      final coverDir = p.join(baseOutputDir, 'covers', video.id);

      _addLog('📂 输出目录: $baseOutputDir');

      final baseName = video.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      // 1. 视频切片
      _addLog('✂️ 开始切片 (每片 ${video.sliceConfig.sliceDuration.toInt()} 秒)...');
      final sliceResults = await FfmpegService.instance.sliceVideo(
        inputPath: video.path,
        sliceDuration: video.sliceConfig.sliceDuration,
        outputDir: outputDir,
        baseName: baseName,
        onProgress: (current, total, status) {
          video.progress = current / total * 0.6;
          _addLog('  $status');
          notifyListeners();
        },
      );

      if (sliceResults.isEmpty) {
        throw Exception('切片结果为空，请检查视频文件格式和ffmpeg是否正常');
      }

      _addLog('✅ 切片完成: ${sliceResults.length} 个片段');

      // 2. 为每个片段生成封面+文案+标签
      for (int i = 0; i < sliceResults.length; i++) {
        final slice = sliceResults[i];
        video.progress = 0.6 + (i / sliceResults.length) * 0.4;
        notifyListeners();

        // 生成封面
        String? coverPath;
        if (video.sliceConfig.generateCover) {
          final coverOutput = p.join(coverDir, 'cover_${i + 1}.jpg');
          coverPath = await FfmpegService.instance.extractCover(
            videoPath: slice.path,
            outputPath: coverOutput,
            watermarkText: video.sliceConfig.addWatermark
                ? video.sliceConfig.watermarkText
                : null,
          );
          if (coverPath != null) {
            _addLog('  🖼️ 封面生成: ${p.basename(coverPath)}');
          }
        }

        // 生成文案+标签
        CaptionResult? captionResult;
        if (video.sliceConfig.generateCaption) {
          captionResult = await CaptionService.instance.generateCaption(
            fileName: video.fileName,
            mode: video.sliceConfig.captionMode,
            apiKey: _botConfig.aiApiKey,
            model: _botConfig.aiModel,
            customPrompt: video.sliceConfig.captionPrompt.isNotEmpty
                ? video.sliceConfig.captionPrompt
                : null,
            partIndex: i + 1,
            totalParts: sliceResults.length,
          );
          if (captionResult.tags.isNotEmpty) {
            _addLog('  🏷️ 标签: ${captionResult.tags.join(' ')}');
          }
        }

        // 如果没有生成文案但需要标签，单独生成标签
        List<String> tags = captionResult?.tags ?? [];
        if (tags.isEmpty && video.sliceConfig.generateTags) {
          tags = await CaptionService.instance.generateTags(
            fileName: video.fileName,
            mode: video.sliceConfig.captionMode,
            apiKey: _botConfig.aiApiKey,
            model: _botConfig.aiModel,
          );
        }

        final videoSlice = VideoSlice(
          id: _uuid.v4(),
          originalVideoId: video.id,
          fileName: slice.fileName,
          realPath: slice.path,
          startTime: slice.startTime,
          endTime: slice.endTime,
          duration: slice.duration,
          coverPath: coverPath,
          title: captionResult?.title,
          caption: captionResult?.caption,
          tags: tags,
          status: VideoStatus.ready,
          progress: 1.0,
        );
        video.slices.add(videoSlice);
      }

      video.status = VideoStatus.ready;
      video.progress = 1.0;
      _addLog('✅ ${video.fileName} 处理完成！共 ${video.slices.length} 个片段');
    } catch (e) {
      video.status = VideoStatus.failed;
      video.errorMessage = e.toString();
      _addLog('❌ 处理失败: $e');
    }
    notifyListeners();
  }

  Future<void> processAllPending() async {
    final pending =
        _videos.where((v) => v.status == VideoStatus.pending).toList();
    _addLog('🚀 开始批量处理 ${pending.length} 个视频...');
    for (final video in pending) {
      await processVideo(video);
    }
    _addLog('✅ 批量处理完成');
  }

  // ==================== 测试发布 ====================
  Future<bool> sendTestMessage() async {
    if (!_botConfig.isConnected || _botConfig.channelId.isEmpty) {
      _addLog('❌ 请先连接Bot并填写频道ID');
      return false;
    }
    _syncSslSetting();
    try {
      _addLog('📤 发送测试消息...');
      final msg = await TelegramService.instance.sendMessage(
        token: _botConfig.botToken,
        chatId: _botConfig.channelId,
        text: '✅ <b>Channel Publisher 连接测试</b>\n\n'
            '🤖 Bot 工作正常！\n'
            '📢 频道: ${_botConfig.channelName.isNotEmpty ? _botConfig.channelName : _botConfig.channelId}\n'
            '⏰ 时间: ${DateTime.now().toString().substring(0, 16)}\n\n'
            '现在可以开始使用视频切片和自动发布功能了 🎬',
        parseMode: 'HTML',
      );
      _addLog('✅ 测试消息发送成功! msgId=${msg.messageId}');
      notifyListeners();
      return true;
    } catch (e) {
      _addLog('❌ 测试消息失败: $e');
      notifyListeners();
      return false;
    }
  }

  // ==================== 发布（真实 Telegram API）====================

  /// 构建发布文案（标题+内容+标签）
  String _buildCaption(VideoSlice slice) {
    final parts = <String>[];
    if (slice.title != null && slice.title!.isNotEmpty) {
      parts.add('<b>${slice.title}</b>');
    }
    if (slice.caption != null && slice.caption!.isNotEmpty) {
      parts.add(slice.caption!);
    }
    // 追加标签
    if (slice.tags.isNotEmpty) {
      parts.add('\n${slice.tags.join(' ')}');
    }
    return parts.join('\n\n');
  }

  /// 发布单个切片
  Future<void> publishSlice(VideoSlice slice, VideoFile video) async {
    if (!_botConfig.isConnected) {
      _addLog('❌ 请先连接 Telegram Bot');
      return;
    }
    if (slice.realPath == null || slice.realPath!.isEmpty) {
      _addLog('❌ 视频文件路径为空，请先处理视频');
      return;
    }
    if (!await File(slice.realPath!).exists()) {
      _addLog('❌ 视频文件不存在: ${slice.realPath}');
      return;
    }
    if (slice.status == VideoStatus.publishing ||
        slice.status == VideoStatus.published) return;

    _syncSslSetting();
    slice.status = VideoStatus.publishing;
    notifyListeners();

    final task = PublishTask(
      id: _uuid.v4(),
      videoSliceId: slice.id,
      videoFileName: slice.fileName,
      status: TaskStatus.running,
      type: TaskType.publish,
      message: '准备上传...',
    );
    _tasks.insert(0, task);
    notifyListeners();

    try {
      _addLog('📤 发布: ${slice.fileName} → ${_botConfig.channelId}');
      if (slice.tags.isNotEmpty) {
        _addLog('  🏷️ 标签: ${slice.tags.join(' ')}');
      }

      final caption = _buildCaption(slice);
      final msg = await TelegramService.instance.sendVideo(
        token: _botConfig.botToken,
        chatId: _botConfig.channelId,
        videoPath: slice.realPath!,
        coverPath: slice.coverPath,
        caption: caption,
        parseMode: 'HTML',
        onProgress: (sent, total) {
          if (total > 0) {
            task.progress = sent / total;
            task.message = '上传中 ${(sent / total * 100).toInt()}%';
            notifyListeners();
          }
        },
      );

      slice.status = VideoStatus.published;
      slice.publishedAt = DateTime.now();
      task.status = TaskStatus.done;
      task.message = '发布成功 ✓ (msgId: ${msg.messageId})';
      task.completedAt = DateTime.now();
      task.progress = 1.0;

      final record = PublishRecord(
        id: _uuid.v4(),
        channelId: _botConfig.channelId,
        channelName: _botConfig.channelName.isNotEmpty
            ? _botConfig.channelName
            : _botConfig.channelId,
        videoFileName: slice.fileName,
        title: slice.title ?? '',
        caption: caption,
        tags: List.from(slice.tags),
        messageId: msg.messageId,
        publishedAt: DateTime.now(),
      );
      _history.insert(0, record);
      _saveHistory();

      _addLog('✅ 发布成功! msgId=${msg.messageId}');
    } catch (e) {
      slice.status = VideoStatus.failed;
      task.status = TaskStatus.error;
      task.message = '发布失败: $e';
      _addLog('❌ 发布失败: $e');
    }
    notifyListeners();
  }

  /// 多选发布（共用一张封面）
  Future<void> publishSelectedSlices({
    String? sharedCoverPath,
    bool asMediaGroup = false,
  }) async {
    if (!_botConfig.isConnected) {
      _addLog('❌ 请先连接 Telegram Bot');
      return;
    }
    if (_selectedSliceIds.isEmpty) {
      _addLog('⚠️ 请先选择要发布的片段');
      return;
    }

    // 收集所有选中的切片
    final selectedSlices = <MapEntry<VideoSlice, VideoFile>>[];
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (_selectedSliceIds.contains(slice.id)) {
          selectedSlices.add(MapEntry(slice, video));
        }
      }
    }

    if (selectedSlices.isEmpty) return;

    _addLog('📤 开始多选发布 ${selectedSlices.length} 个片段...');

    if (asMediaGroup && selectedSlices.length <= 10) {
      // 媒体组发布（Telegram 最多10个）
      await _publishAsMediaGroup(selectedSlices, sharedCoverPath);
    } else {
      // 逐个发布
      for (final entry in selectedSlices) {
        // 如果有共用封面，覆盖单个封面
        if (sharedCoverPath != null) {
          entry.key.coverPath = sharedCoverPath;
        }
        await publishSlice(entry.key, entry.value);
        // 发布间隔
        if (_botConfig.publishInterval > 0 && entry != selectedSlices.last) {
          _addLog('⏱️ 等待 ${_botConfig.publishInterval} 秒...');
          await Future.delayed(
              Duration(seconds: _botConfig.publishInterval));
        }
      }
    }

    _selectedSliceIds.clear();
    notifyListeners();
    _addLog('✅ 多选发布完成');
  }

  Future<void> _publishAsMediaGroup(
    List<MapEntry<VideoSlice, VideoFile>> slices,
    String? sharedCoverPath,
  ) async {
    final mediaItems = <MediaItem>[];
    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i].key;
      if (slice.realPath == null || !await File(slice.realPath!).exists()) {
        continue;
      }
      mediaItems.add(MediaItem(
        filePath: slice.realPath!,
        coverPath: i == 0 ? (sharedCoverPath ?? slice.coverPath) : null,
        type: MediaType.video,
      ));
    }

    if (mediaItems.isEmpty) {
      _addLog('❌ 没有有效的视频文件');
      return;
    }

    try {
      // 取第一个片段的文案和标签
      final firstSlice = slices.first.key;
      final caption = _buildCaption(firstSlice);

      _addLog('📤 发送媒体组 (${mediaItems.length} 个)...');
      final msgs = await TelegramService.instance.sendMediaGroup(
        token: _botConfig.botToken,
        chatId: _botConfig.channelId,
        items: mediaItems,
        caption: caption,
      );

      for (int i = 0; i < slices.length && i < msgs.length; i++) {
        final slice = slices[i].key;
        slice.status = VideoStatus.published;
        slice.publishedAt = DateTime.now();
        _history.insert(
            0,
            PublishRecord(
              id: _uuid.v4(),
              channelId: _botConfig.channelId,
              channelName: _botConfig.channelName.isNotEmpty
                  ? _botConfig.channelName
                  : _botConfig.channelId,
              videoFileName: slice.fileName,
              title: slice.title ?? '',
              caption: caption,
              tags: List.from(slice.tags),
              messageId: msgs[i].messageId,
              publishedAt: DateTime.now(),
            ));
      }
      _saveHistory();
      _addLog('✅ 媒体组发布成功，共 ${msgs.length} 条消息');
    } catch (e) {
      _addLog('❌ 媒体组发布失败: $e');
    }
    notifyListeners();
  }

  Future<void> publishAllReady() async {
    final allReady = <MapEntry<VideoSlice, VideoFile>>[];
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.status == VideoStatus.ready) {
          allReady.add(MapEntry(slice, video));
        }
      }
    }
    if (allReady.isEmpty) {
      _addLog('⚠️ 没有已就绪的片段');
      return;
    }
    _addLog('🚀 发布所有就绪片段: ${allReady.length} 个');
    for (final entry in allReady) {
      await publishSlice(entry.key, entry.value);
      if (_botConfig.publishInterval > 0) {
        await Future.delayed(Duration(seconds: _botConfig.publishInterval));
      }
    }
  }

  // ==================== 文案编辑 ====================
  void updateSliceTitle(String sliceId, String title) {
    _forEachSlice(sliceId, (s) => s.title = title);
  }

  void updateSliceCaption(String sliceId, String caption) {
    _forEachSlice(sliceId, (s) => s.caption = caption);
  }

  void updateSliceCover(String sliceId, String coverPath) {
    _forEachSlice(sliceId, (s) => s.coverPath = coverPath);
  }

  void updateSliceTags(String sliceId, List<String> tags) {
    _forEachSlice(sliceId, (s) => s.tags = tags);
  }

  void _forEachSlice(String sliceId, void Function(VideoSlice) fn) {
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.id == sliceId) {
          fn(slice);
          notifyListeners();
          return;
        }
      }
    }
  }

  Future<void> regenerateCaption(VideoSlice slice) async {
    _addLog('🤖 AI 重新生成文案...');
    try {
      final video =
          _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final result = await CaptionService.instance.generateCaption(
        fileName: video.fileName,
        mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey,
        model: _botConfig.aiModel,
        customPrompt: video.sliceConfig.captionPrompt.isNotEmpty
            ? video.sliceConfig.captionPrompt
            : null,
      );
      slice.title = result.title;
      slice.caption = result.caption;
      if (result.tags.isNotEmpty) {
        slice.tags = result.tags;
        _addLog('🏷️ 标签更新: ${result.tags.join(' ')}');
      }
      _addLog('✅ 文案已更新');
    } catch (e) {
      _addLog('❌ 文案生成失败: $e');
    }
    notifyListeners();
  }

  /// 重新生成标签
  Future<void> regenerateTags(VideoSlice slice) async {
    _addLog('🏷️ 重新生成标签...');
    try {
      final video =
          _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final tags = await CaptionService.instance.generateTags(
        fileName: video.fileName,
        mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey,
        model: _botConfig.aiModel,
      );
      slice.tags = tags;
      _addLog('✅ 标签已更新: ${tags.join(' ')}');
    } catch (e) {
      _addLog('❌ 标签生成失败: $e');
    }
    notifyListeners();
  }

  /// 单独重新生成标题
  Future<void> regenerateTitle(VideoSlice slice) async {
    _addLog('🤖 AI 重新生成标题...');
    try {
      final video =
          _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final result = await CaptionService.instance.generateCaption(
        fileName: video.fileName,
        mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey,
        model: _botConfig.aiModel,
        customPrompt: video.sliceConfig.captionPrompt.isNotEmpty
            ? video.sliceConfig.captionPrompt
            : null,
      );
      slice.title = result.title;
      _addLog('✅ 标题已更新: ${result.title}');
    } catch (e) {
      _addLog('❌ 标题生成失败: $e');
    }
    notifyListeners();
  }

  /// 切换成人/普通模式并重新生成文案
  Future<void> toggleCaptionMode(VideoSlice slice) async {
    final video = _videos.firstWhere(
      (v) => v.id == slice.originalVideoId,
      orElse: () => _videos.first,
    );
    // 切换模式
    final newMode = video.sliceConfig.captionMode == CaptionMode.adult
        ? CaptionMode.normal
        : CaptionMode.adult;
    video.sliceConfig.captionMode = newMode;
    _addLog(
        '🔄 切换文案模式为: ${newMode == CaptionMode.adult ? "成人模式🔞" : "普通模式"}');
    notifyListeners();
    // 重新生成文案+标签
    await regenerateCaption(slice);
  }

  /// 手动设置封面路径
  Future<void> changeCover(String sliceId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          _forEachSlice(sliceId, (s) => s.coverPath = path);
          _addLog('🖼️ 封面已更新');
        }
      }
    } catch (e) {
      _addLog('❌ 选择封面失败: $e');
    }
  }

  void updateSliceConfig(String videoId, SliceConfig config) {
    try {
      final video = _videos.firstWhere((v) => v.id == videoId);
      video.sliceConfig = config;
      notifyListeners();
    } catch (_) {}
  }

  // ==================== 日志 ====================
  void _addLog(String message) {
    final now = DateTime.now();
    final t =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logOutput = '[$t] $message\n$_logOutput';
    if (_logOutput.length > 8000) {
      _logOutput = _logOutput.substring(0, 8000);
    }
    notifyListeners();
  }

  void clearLog() {
    _logOutput = '';
    notifyListeners();
  }
}
