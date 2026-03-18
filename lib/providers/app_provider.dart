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

  final List<VideoFile> _videos = [];
  List<VideoFile> get videos => _videos;

  VideoFile? _selectedVideo;
  VideoFile? get selectedVideo => _selectedVideo;

  final Set<String> _selectedSliceIds = {};
  Set<String> get selectedSliceIds => _selectedSliceIds;

  final List<PublishTask> _tasks = [];
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
  int get totalProcessing => _videos.where((v) => v.status == VideoStatus.processing).length;
  int get totalPending    => _videos.where((v) => v.status == VideoStatus.pending).length;
  int get totalReady      => _videos.where((v) => v.status == VideoStatus.ready).length;

  AppProvider() {
    _loadSettings();
    _checkFfmpeg();
  }

  // ==================== 导航 ====================
  void setNav(int index) { _selectedNav = index; notifyListeners(); }

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
        _addLog('💡 请下载 ffmpeg 并放到程序同目录或系统 PATH');
        _addLog('   下载：https://www.gyan.dev/ffmpeg/builds/');
      }
    } catch (e) {
      _ffmpegAvailable = false;
      _ffmpegVersion = '未找到';
      _addLog('⚠️ ffmpeg 检测异常: $e');
    }
    notifyListeners();
  }

  // ==================== 设置加载/保存 ====================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('bot_config');
      if (configJson != null) {
        _botConfig = BotConfig.fromJson(jsonDecode(configJson));
        _syncSslSetting();
      }
      _watchFolder = prefs.getString('watch_folder') ?? '';
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

  void _syncSslSetting() {
    TelegramService.instance.setIgnoreSslErrors(_botConfig.ignoreSslErrors);
    CaptionService.instance.setIgnoreSsl(_botConfig.ignoreSslErrors);
  }

  Future<void> saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bot_config', jsonEncode(_botConfig.toJson()));
      await prefs.setString('watch_folder', _watchFolder);
      _syncSslSetting();
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
    _botConfig.isConnected = false;
    _botInfo = null;
    _syncSslSetting();
    saveSettings();
    notifyListeners();
  }

  /// 局部更新 BotConfig（不重置连接状态），用于开关类快速操作
  void updateBotConfigPartial(BotConfig config) {
    _botConfig = config;
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
  Future<String> _getOutputBaseDir() async {
    if (_botConfig.outputDir.isNotEmpty) {
      final customDir = Directory(_botConfig.outputDir);
      try {
        if (!customDir.existsSync()) customDir.createSync(recursive: true);
        return _botConfig.outputDir;
      } catch (e) {
        _addLog('⚠️ 自定义目录不可用: $e，使用默认目录');
      }
    }
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final outputDir = p.join(docsDir.path, 'ChannelPublisher');
      await Directory(outputDir).create(recursive: true);
      return outputDir;
    } catch (_) {
      final appDir = await getApplicationSupportDirectory();
      return appDir.path;
    }
  }

  // ==================== Bot连接 ====================
  Future<bool> testBotConnection() async {
    if (_botConfig.botToken.isEmpty) { _addLog('❌ 请先填写 Bot Token'); return false; }
    _isConnecting = true;
    notifyListeners();
    _syncSslSetting();
    _addLog('🔗 正在连接 Telegram (忽略SSL=${_botConfig.ignoreSslErrors})...');

    try {
      final info = await TelegramService.instance.testConnection(_botConfig.botToken);
      _botInfo = info;
      _botConfig.isConnected = true;
      _addLog('✅ Bot连接成功！${info.username} (${info.firstName})');

      if (_botConfig.channelId.isNotEmpty) {
        final chInfo = await TelegramService.instance.getChannelInfo(
            _botConfig.botToken, _botConfig.channelId);
        if (chInfo != null) {
          _botConfig.channelName = chInfo.title;
          _addLog('📢 频道: ${chInfo.title} (${chInfo.id})');
        } else {
          _addLog('⚠️ 未能获取频道信息，确认频道ID正确且Bot已加入频道');
        }
      }
      await saveSettings();
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
  void selectVideo(VideoFile? video) { _selectedVideo = video; notifyListeners(); }

  void addVideosFromPicker(List<PlatformFile> files) {
    int added = 0;
    for (final file in files) {
      final fileName = file.name;
      final key = file.path ?? 'web://$fileName';
      if (!_videos.any((v) => v.path == key)) {
        final video = VideoFile(id: _uuid.v4(), path: key, fileName: fileName,
            duration: 0, fileSize: file.size);
        _videos.add(video);
        added++;
        _addLog('➕ 添加: $fileName');
        _loadVideoInfo(video);
      }
    }
    if (added > 0 && _selectedVideo == null) _selectedVideo = _videos.first;
    notifyListeners();
  }

  Future<void> _loadVideoInfo(VideoFile video) async {
    if (!_ffmpegAvailable || video.path.startsWith('web://')) return;
    try {
      final info = await FfmpegService.instance.getVideoInfo(video.path);
      video.duration = info.duration;
      if (info.fileSize > 0) video.fileSize = info.fileSize;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> scanFolder(String folderPath) async {
    setWatchFolder(folderPath);
    final videoExts = ['.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm','.m4v','.ts'];
    int added = 0;
    if (!kIsWeb) {
      try {
        await for (final entityPath in listDirectory(folderPath)) {
          final name = entityPath.split('/').last.split('\\').last;
          final ext = name.contains('.') ? '.${name.split('.').last.toLowerCase()}' : '';
          if (videoExts.contains(ext) && !_videos.any((v) => v.path == entityPath)) {
            final video = VideoFile(id: _uuid.v4(), path: entityPath, fileName: name,
                duration: 0, fileSize: 0);
            try { video.fileSize = (await File(entityPath).stat()).size; } catch (_) {}
            _videos.add(video);
            added++;
            _addLog('➕ 发现: $name');
            _loadVideoInfo(video);
          }
        }
        if (added > 0 && _selectedVideo == null) _selectedVideo = _videos.first;
        _addLog('📁 扫描完成，发现 $added 个视频');
        notifyListeners();
        return;
      } catch (e) { _addLog('⚠️ 扫描失败: $e'); }
    }
    _addLog('⚠️ Web 模式不支持文件夹扫描');
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
    for (final s in video.slices) _selectedSliceIds.add(s.id);
    notifyListeners();
  }

  void clearSliceSelection() { _selectedSliceIds.clear(); notifyListeners(); }
  bool isSliceSelected(String sliceId) => _selectedSliceIds.contains(sliceId);

  // ==================== 视频处理（真实ffmpeg）====================
  Future<void> processVideo(VideoFile video) async {
    if (video.status == VideoStatus.processing) return;
    if (!_ffmpegAvailable) {
      _addLog('❌ ffmpeg 未安装，请下载后放到程序同目录');
      video.status = VideoStatus.failed;
      video.errorMessage = 'ffmpeg 未找到';
      notifyListeners();
      return;
    }

    video.status = VideoStatus.processing;
    video.progress = 0;
    video.slices.clear();
    notifyListeners();
    _addLog('🎬 开始处理: ${video.fileName}');

    try {
      final baseOutputDir = await _getOutputBaseDir();
      final outputDir = p.join(baseOutputDir, 'slices', video.id);
      final coverDir  = p.join(baseOutputDir, 'covers', video.id);
      _addLog('📂 输出目录: $baseOutputDir');

      final baseName = video.fileName.replaceAll(RegExp(r'\.[^.]+$'), '');

      // 1. 视频切片
      _addLog('✂️ 切片 (每片 ${video.sliceConfig.sliceDuration.toInt()}s)...');
      final sliceResults = await FfmpegService.instance.sliceVideo(
        inputPath: video.path,
        sliceDuration: video.sliceConfig.sliceDuration,
        outputDir: outputDir,
        baseName: baseName,
        onProgress: (current, total, status) {
          video.progress = current / total * 0.5;
          _addLog('  $status');
          notifyListeners();
        },
      );

      if (sliceResults.isEmpty) throw Exception('切片结果为空，请检查视频文件');
      _addLog('✅ 切片完成: ${sliceResults.length} 个');

      // 2. 为每个片段生成封面+文字+文案+标签
      for (int i = 0; i < sliceResults.length; i++) {
        final slice = sliceResults[i];
        video.progress = 0.5 + (i / sliceResults.length) * 0.5;
        notifyListeners();

        // 获取封面文字（AI或预设）
        String? coverText;
        if (_botConfig.enableCoverText) {
          coverText = await CaptionService.instance.generateCoverText(
            fileName: video.fileName,
            mode: video.sliceConfig.captionMode,
            apiKey: _botConfig.aiApiKey,
            model: _botConfig.defaultModel,
            baseUrl: _botConfig.effectiveBaseUrl,
            presetTexts: _botConfig.coverTextPreset,
          );
          if (coverText != null) _addLog('  📝 封面文字: $coverText');
        }

        // 截取多张封面
        String? mainCoverPath;
        final extraCovers = <String>[];

        if (video.sliceConfig.generateCover) {
          final totalCovers = 1 + video.sliceConfig.extraCoverCount;
          final covers = await FfmpegService.instance.extractMultiCovers(
            videoPath: slice.path,
            outputDir: coverDir,
            baseName: '${baseName}_part${(i + 1).toString().padLeft(3, '0')}',
            count: totalCovers,
            watermarkText: video.sliceConfig.addWatermark ? video.sliceConfig.watermarkText : null,
            overlayText: coverText,
          );

          if (covers.isNotEmpty) {
            mainCoverPath = covers.first;
            if (covers.length > 1) extraCovers.addAll(covers.sublist(1));
            _addLog('  🖼️ 封面 ${covers.length} 张: ${covers.map(p.basename).join(', ')}');
          }
        }

        // 生成文案+标签
        CaptionResult? captionResult;
        if (video.sliceConfig.generateCaption) {
          captionResult = await CaptionService.instance.generateCaption(
            fileName: video.fileName,
            mode: video.sliceConfig.captionMode,
            apiKey: _botConfig.aiApiKey,
            model: _botConfig.defaultModel,
            baseUrl: _botConfig.effectiveBaseUrl,
            customPrompt: video.sliceConfig.captionPrompt.isNotEmpty
                ? video.sliceConfig.captionPrompt : null,
            partIndex: i + 1,
            totalParts: sliceResults.length,
            enableEmoji: _botConfig.enableEmoji,
            enableTags: _botConfig.enableTags,
            maxCaptionLength: _botConfig.captionMaxLength,
          );
          if (captionResult.tags.isNotEmpty) {
            _addLog('  🏷️ 标签: ${captionResult.tags.join(' ')}');
          }
        }

        // 独立生成标签
        List<String> tags = captionResult?.tags ?? [];
        if (tags.isEmpty && video.sliceConfig.generateTags && _botConfig.enableTags) {
          tags = await CaptionService.instance.generateTags(
            fileName: video.fileName,
            mode: video.sliceConfig.captionMode,
            apiKey: _botConfig.aiApiKey,
            model: _botConfig.defaultModel,
            baseUrl: _botConfig.effectiveBaseUrl,
          );
        }

        video.slices.add(VideoSlice(
          id: _uuid.v4(),
          originalVideoId: video.id,
          fileName: slice.fileName,
          realPath: slice.path,
          startTime: slice.startTime,
          endTime: slice.endTime,
          duration: slice.duration,
          coverPath: mainCoverPath,
          extraCoverPaths: extraCovers,
          coverText: coverText,
          title: captionResult?.title,
          caption: captionResult?.caption,
          tags: tags,
          status: VideoStatus.ready,
          progress: 1.0,
        ));
      }

      video.status = VideoStatus.ready;
      video.progress = 1.0;
      _addLog('✅ ${video.fileName} 处理完成！${video.slices.length} 个片段');
    } catch (e) {
      video.status = VideoStatus.failed;
      video.errorMessage = e.toString();
      _addLog('❌ 处理失败: $e');
    }
    notifyListeners();
  }

  Future<void> processAllPending() async {
    final pending = _videos.where((v) => v.status == VideoStatus.pending).toList();
    _addLog('🚀 批量处理 ${pending.length} 个视频...');
    for (final video in pending) await processVideo(video);
    _addLog('✅ 批量处理完成');
  }

  // ==================== 测试消息 ====================
  Future<bool> sendTestMessage() async {
    if (!_botConfig.isConnected || _botConfig.channelId.isEmpty) {
      _addLog('❌ 请先连接Bot并填写频道ID'); return false;
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

  // ==================== 构建发布文案 ====================
  String _buildCaption(VideoSlice slice) {
    final parts = <String>[];

    // 标题
    if (slice.title != null && slice.title!.isNotEmpty) {
      final t = _botConfig.enableBoldTitle
          ? '<b>${slice.title}</b>'
          : slice.title!;
      parts.add(t);
    }

    // 正文
    if (slice.caption != null && slice.caption!.isNotEmpty) {
      parts.add(slice.caption!);
    }

    // TG频道引用
    if (_botConfig.enableTgQuote && _botConfig.tgChannelLink.isNotEmpty) {
      final link = _botConfig.tgChannelLink.startsWith('@')
          ? _botConfig.tgChannelLink
          : '@${_botConfig.tgChannelLink}';
      parts.add('📢 关注频道: $link');
    }

    // 标签
    if (_botConfig.enableTags && slice.tags.isNotEmpty) {
      parts.add(slice.tags.join(' '));
    }

    return parts.join('\n\n');
  }

  // ==================== 发布（真实API）====================
  Future<void> publishSlice(VideoSlice slice, VideoFile video) async {
    if (!_botConfig.isConnected) { _addLog('❌ 请先连接 Telegram Bot'); return; }
    if (slice.realPath == null || slice.realPath!.isEmpty) {
      _addLog('❌ 视频文件路径为空，请先处理视频'); return;
    }
    if (!await File(slice.realPath!).exists()) {
      _addLog('❌ 视频文件不存在: ${slice.realPath}'); return;
    }
    if (slice.status == VideoStatus.publishing || slice.status == VideoStatus.published) return;

    _syncSslSetting();
    slice.status = VideoStatus.publishing;
    notifyListeners();

    final task = PublishTask(
      id: _uuid.v4(), videoSliceId: slice.id,
      videoFileName: slice.fileName, status: TaskStatus.running,
      type: TaskType.publish, message: '准备上传...',
    );
    _tasks.insert(0, task);
    notifyListeners();

    try {
      _addLog('📤 发布: ${slice.fileName} → ${_botConfig.channelId}');
      if (slice.tags.isNotEmpty) _addLog('  🏷️ ${slice.tags.join(' ')}');

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

      _history.insert(0, PublishRecord(
        id: _uuid.v4(), channelId: _botConfig.channelId,
        channelName: _botConfig.channelName.isNotEmpty ? _botConfig.channelName : _botConfig.channelId,
        videoFileName: slice.fileName,
        title: slice.title ?? '', caption: caption,
        tags: List.from(slice.tags), messageId: msg.messageId,
        publishedAt: DateTime.now(),
      ));
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

  Future<void> publishSelectedSlices({
    String? sharedCoverPath,
    bool asMediaGroup = false,
  }) async {
    if (!_botConfig.isConnected) { _addLog('❌ 请先连接Bot'); return; }
    if (_selectedSliceIds.isEmpty) { _addLog('⚠️ 请先选择片段'); return; }

    final selectedSlices = <MapEntry<VideoSlice, VideoFile>>[];
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (_selectedSliceIds.contains(slice.id)) {
          selectedSlices.add(MapEntry(slice, video));
        }
      }
    }
    if (selectedSlices.isEmpty) return;

    _addLog('📤 多选发布 ${selectedSlices.length} 个...');

    if (asMediaGroup && selectedSlices.length <= 10) {
      await _publishAsMediaGroup(selectedSlices, sharedCoverPath);
    } else {
      for (final entry in selectedSlices) {
        if (sharedCoverPath != null) entry.key.coverPath = sharedCoverPath;
        await publishSlice(entry.key, entry.value);
        if (_botConfig.publishInterval > 0 && entry != selectedSlices.last) {
          _addLog('⏱️ 等待 ${_botConfig.publishInterval}s...');
          await Future.delayed(Duration(seconds: _botConfig.publishInterval));
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
      if (slice.realPath == null || !await File(slice.realPath!).exists()) continue;
      mediaItems.add(MediaItem(
        filePath: slice.realPath!,
        coverPath: i == 0 ? (sharedCoverPath ?? slice.coverPath) : null,
        type: MediaType.video,
      ));
    }
    if (mediaItems.isEmpty) { _addLog('❌ 没有有效视频'); return; }

    try {
      final caption = _buildCaption(slices.first.key);
      _addLog('📤 媒体组发送 (${mediaItems.length} 个)...');
      final msgs = await TelegramService.instance.sendMediaGroup(
        token: _botConfig.botToken, chatId: _botConfig.channelId,
        items: mediaItems, caption: caption,
      );

      for (int i = 0; i < slices.length && i < msgs.length; i++) {
        final slice = slices[i].key;
        slice.status = VideoStatus.published;
        slice.publishedAt = DateTime.now();
        _history.insert(0, PublishRecord(
          id: _uuid.v4(), channelId: _botConfig.channelId,
          channelName: _botConfig.channelName.isNotEmpty ? _botConfig.channelName : _botConfig.channelId,
          videoFileName: slice.fileName, title: slice.title ?? '',
          caption: caption, tags: List.from(slice.tags),
          messageId: msgs[i].messageId, publishedAt: DateTime.now(),
        ));
      }
      _saveHistory();
      _addLog('✅ 媒体组发布成功 ${msgs.length} 条');
    } catch (e) { _addLog('❌ 媒体组发布失败: $e'); }
    notifyListeners();
  }

  Future<void> publishAllReady() async {
    final allReady = <MapEntry<VideoSlice, VideoFile>>[];
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.status == VideoStatus.ready) allReady.add(MapEntry(slice, video));
      }
    }
    if (allReady.isEmpty) { _addLog('⚠️ 没有就绪片段'); return; }
    _addLog('🚀 发布所有就绪片段: ${allReady.length} 个');
    for (final entry in allReady) {
      await publishSlice(entry.key, entry.value);
      if (_botConfig.publishInterval > 0) {
        await Future.delayed(Duration(seconds: _botConfig.publishInterval));
      }
    }
  }

  // ==================== 文案/标签编辑 ====================
  void updateSliceTitle(String sliceId, String title)        => _forEachSlice(sliceId, (s) => s.title = title);
  void updateSliceCaption(String sliceId, String caption)    => _forEachSlice(sliceId, (s) => s.caption = caption);
  void updateSliceCover(String sliceId, String coverPath)    => _forEachSlice(sliceId, (s) => s.coverPath = coverPath);
  void updateSliceTags(String sliceId, List<String> tags)    => _forEachSlice(sliceId, (s) => s.tags = tags);
  void updateSliceCoverText(String sliceId, String text)     => _forEachSlice(sliceId, (s) => s.coverText = text);

  void _forEachSlice(String sliceId, void Function(VideoSlice) fn) {
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.id == sliceId) { fn(slice); notifyListeners(); return; }
      }
    }
  }

  Future<void> regenerateCaption(VideoSlice slice) async {
    _addLog('🤖 AI 重新生成文案...');
    try {
      final video = _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final result = await CaptionService.instance.generateCaption(
        fileName: video.fileName,
        mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey,
        model: _botConfig.defaultModel,
        baseUrl: _botConfig.effectiveBaseUrl,
        customPrompt: video.sliceConfig.captionPrompt.isNotEmpty
            ? video.sliceConfig.captionPrompt : null,
        enableEmoji: _botConfig.enableEmoji,
        enableTags: _botConfig.enableTags,
        maxCaptionLength: _botConfig.captionMaxLength,
      );
      slice.title = result.title;
      slice.caption = result.caption;
      if (result.tags.isNotEmpty) {
        slice.tags = result.tags;
        _addLog('🏷️ 标签: ${result.tags.join(' ')}');
      }
      _addLog('✅ 文案已更新');
    } catch (e) { _addLog('❌ 文案生成失败: $e'); }
    notifyListeners();
  }

  Future<void> regenerateTags(VideoSlice slice) async {
    _addLog('🏷️ 重新生成标签...');
    try {
      final video = _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final tags = await CaptionService.instance.generateTags(
        fileName: video.fileName,
        mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey,
        model: _botConfig.defaultModel,
        baseUrl: _botConfig.effectiveBaseUrl,
      );
      slice.tags = tags;
      _addLog('✅ 标签: ${tags.join(' ')}');
    } catch (e) { _addLog('❌ 标签生成失败: $e'); }
    notifyListeners();
  }

  Future<void> regenerateTitle(VideoSlice slice) async {
    _addLog('🤖 重新生成标题...');
    try {
      final video = _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final result = await CaptionService.instance.generateCaption(
        fileName: video.fileName, mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey, model: _botConfig.defaultModel,
        baseUrl: _botConfig.effectiveBaseUrl,
        enableEmoji: _botConfig.enableEmoji, enableTags: false,
      );
      slice.title = result.title;
      _addLog('✅ 标题: ${result.title}');
    } catch (e) { _addLog('❌ 标题生成失败: $e'); }
    notifyListeners();
  }

  Future<void> regenerateCoverText(VideoSlice slice) async {
    _addLog('📝 生成封面文字...');
    try {
      final video = _videos.firstWhere((v) => v.id == slice.originalVideoId);
      final text = await CaptionService.instance.generateCoverText(
        fileName: video.fileName, mode: video.sliceConfig.captionMode,
        apiKey: _botConfig.aiApiKey, model: _botConfig.defaultModel,
        baseUrl: _botConfig.effectiveBaseUrl,
        presetTexts: _botConfig.coverTextPreset,
      );
      slice.coverText = text;
      _addLog('✅ 封面文字: $text');
    } catch (e) { _addLog('❌ 封面文字失败: $e'); }
    notifyListeners();
  }

  Future<void> toggleCaptionMode(VideoSlice slice) async {
    final video = _videos.firstWhere(
      (v) => v.id == slice.originalVideoId, orElse: () => _videos.first);
    final newMode = video.sliceConfig.captionMode == CaptionMode.adult
        ? CaptionMode.normal : CaptionMode.adult;
    video.sliceConfig.captionMode = newMode;
    _addLog('🔄 切换为: ${newMode == CaptionMode.adult ? "成人模式🔞" : "普通模式"}');
    notifyListeners();
    await regenerateCaption(slice);
  }

  Future<void> changeCover(String sliceId) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
      if (result != null && result.files.isNotEmpty && result.files.first.path != null) {
        _forEachSlice(sliceId, (s) => s.coverPath = result.files.first.path!);
        _addLog('🖼️ 封面已更新');
      }
    } catch (e) { _addLog('❌ 选择封面失败: $e'); }
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
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _logOutput = '[$t] $message\n$_logOutput';
    if (_logOutput.length > 8000) _logOutput = _logOutput.substring(0, 8000);
    notifyListeners();
  }

  void clearLog() { _logOutput = ''; notifyListeners(); }
}
