import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/app_models.dart';
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

  List<PublishTask> _tasks = [];
  List<PublishTask> get tasks => _tasks;

  List<PublishRecord> _history = [];
  List<PublishRecord> get history => _history;

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String _logOutput = '';
  String get logOutput => _logOutput;

  // 统计
  int get totalPublished => _history.length;
  int get totalProcessing => _videos.where((v) => v.status == VideoStatus.processing).length;
  int get totalPending => _videos.where((v) => v.status == VideoStatus.pending).length;
  int get totalReady => _videos.where((v) => v.status == VideoStatus.ready).length;

  AppProvider() {
    _loadSettings();
    _initDemoData();
  }

  // ==================== 导航 ====================
  void setNav(int index) {
    _selectedNav = index;
    notifyListeners();
  }

  // ==================== 设置 ====================
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('bot_config');
      if (configJson != null) {
        _botConfig = BotConfig.fromJson(jsonDecode(configJson));
      }
      _watchFolder = prefs.getString('watch_folder') ?? '';
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('Load settings error: $e');
    }
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

  void updateBotConfig(BotConfig config) {
    _botConfig = config;
    saveSettings();
    notifyListeners();
  }

  void setWatchFolder(String path) {
    _watchFolder = path;
    saveSettings();
    _addLog('📁 监控文件夹已设置: $path');
    notifyListeners();
  }

  // ==================== Bot 连接 ====================
  Future<bool> testBotConnection() async {
    if (_botConfig.botToken.isEmpty) return false;
    _isConnecting = true;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    // 模拟连接测试
    final success = _botConfig.botToken.contains(':') && _botConfig.botToken.length > 20;
    _botConfig.isConnected = success;
    _isConnecting = false;

    if (success) {
      _addLog('✅ Bot 连接成功！频道: ${_botConfig.channelName}');
    } else {
      _addLog('❌ Bot 连接失败，请检查 Token');
    }
    saveSettings();
    notifyListeners();
    return success;
  }

  // ==================== 视频管理 ====================
  void selectVideo(VideoFile? video) {
    _selectedVideo = video;
    notifyListeners();
  }

  /// 从 FilePicker 结果添加视频（兼容 Web + 桌面）
  void addVideosFromPicker(List<PlatformFile> files) {
    final random = Random();
    int added = 0;
    for (final file in files) {
      final fileName = file.name;
      // Web 上 path 为 null，用 name 做唯一标识；桌面用 path
      final key = file.path ?? 'web://$fileName';
      final exists = _videos.any((v) => v.path == key);
      if (!exists) {
        final video = VideoFile(
          id: _uuid.v4(),
          path: key,
          fileName: fileName,
          duration: 60 + random.nextDouble() * 300,
          fileSize: file.size > 0 ? file.size : (10 + random.nextInt(500)) * 1024 * 1024,
        );
        _videos.add(video);
        added++;
        _addLog('➕ 添加视频: $fileName');
      }
    }
    if (added > 0) {
      // 自动选中第一个刚加入的视频
      if (_selectedVideo == null) {
        _selectedVideo = _videos.first;
      }
    }
    notifyListeners();
  }

  /// 扫描文件夹（桌面：读真实文件；Web：模拟）
  Future<void> scanFolder(String folderPath) async {
    setWatchFolder(folderPath);
    final videoExts = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
    final random = Random();
    int added = 0;

    if (!kIsWeb) {
      // 桌面：真实扫描文件夹
      try {
        // 动态导入 dart:io 只在非 web
        await _scanRealFolder(folderPath, videoExts, random);
        return;
      } catch (e) {
        _addLog('⚠️ 扫描文件夹出错: $e');
      }
    }

    // Web 回退：演示模式
    final demoFiles = [
      'video_001.mp4', 'video_002.mp4', 'clip_003.mp4',
      'recording_004.mp4', 'export_005.mp4',
    ];
    for (final name in demoFiles) {
      final key = '$folderPath/$name';
      if (!_videos.any((v) => v.path == key)) {
        _videos.add(VideoFile(
          id: _uuid.v4(),
          path: key,
          fileName: name,
          duration: 60 + random.nextDouble() * 300,
          fileSize: (30 + random.nextInt(400)) * 1024 * 1024,
        ));
        added++;
      }
    }
    if (added > 0 && _selectedVideo == null) _selectedVideo = _videos.first;
    _addLog('📁 扫描完成（演示模式），添加了 $added 个视频');
    notifyListeners();
  }

  Future<void> _scanRealFolder(String folderPath, List<String> exts, Random random) async {
    int added = 0;
    await for (final entityPath in listDirectory(folderPath)) {
      final name = entityPath.split('/').last.split('\\').last;
      final ext = name.contains('.') ? '.${name.split('.').last.toLowerCase()}' : '';
      if (exts.contains(ext)) {
        if (!_videos.any((v) => v.path == entityPath)) {
          _videos.add(VideoFile(
            id: _uuid.v4(),
            path: entityPath,
            fileName: name,
            duration: 60 + random.nextDouble() * 300,
            fileSize: (30 + random.nextInt(400)) * 1024 * 1024,
          ));
          added++;
          _addLog('➕ 发现视频: $name');
        }
      }
    }
    if (added > 0 && _selectedVideo == null) _selectedVideo = _videos.first;
    _addLog('📁 文件夹扫描完成，共找到 $added 个视频文件');
    notifyListeners();
  }

  void addVideos(List<String> paths) {
    final random = Random();
    for (final path in paths) {
      final fileName = path.split('/').last.split('\\').last;
      final exists = _videos.any((v) => v.path == path);
      if (!exists) {
        final video = VideoFile(
          id: _uuid.v4(),
          path: path,
          fileName: fileName,
          duration: 60 + random.nextDouble() * 300,
          fileSize: (10 + random.nextInt(500)) * 1024 * 1024,
        );
        _videos.add(video);
        _addLog('➕ 添加视频: $fileName');
      }
    }
    if (_selectedVideo == null && _videos.isNotEmpty) {
      _selectedVideo = _videos.first;
    }
    notifyListeners();
  }

  void removeVideo(String id) {
    _videos.removeWhere((v) => v.id == id);
    if (_selectedVideo?.id == id) _selectedVideo = null;
    notifyListeners();
  }

  void selectAllVideos() {
    _selectedVideo = _videos.isNotEmpty ? _videos.first : null;
    notifyListeners();
  }

  // ==================== 视频处理 ====================
  Future<void> processVideo(VideoFile video) async {
    if (video.status == VideoStatus.processing) return;

    video.status = VideoStatus.processing;
    video.progress = 0;
    notifyListeners();

    _addLog('🎬 开始处理: ${video.fileName}');

    // 模拟切片
    if (video.sliceConfig.autoSlice) {
      await _simulateSlicing(video);
    }

    // 模拟封面生成
    if (video.sliceConfig.generateCover) {
      await _simulateCoverGeneration(video);
    }

    // 模拟文案生成
    if (video.sliceConfig.generateCaption) {
      await _simulateCaptionGeneration(video);
    }

    video.status = VideoStatus.ready;
    video.progress = 1.0;
    _addLog('✅ 处理完成: ${video.fileName}，共 ${video.slices.length} 个片段');
    notifyListeners();
  }

  Future<void> _simulateSlicing(VideoFile video) async {
    final sliceCount = (video.duration / video.sliceConfig.sliceDuration).ceil();
    video.slices.clear();

    for (int i = 0; i < sliceCount; i++) {
      final start = i * video.sliceConfig.sliceDuration;
      final end = min(start + video.sliceConfig.sliceDuration, video.duration);
      video.slices.add(VideoSlice(
        id: _uuid.v4(),
        originalVideoId: video.id,
        fileName: '${video.fileName.replaceAll(RegExp(r'\.[^.]+$'), '')}_part${i + 1}.mp4',
        startTime: start,
        endTime: end,
        duration: end - start,
        status: VideoStatus.processing,
        progress: 0,
      ));

      video.progress = (i + 1) / sliceCount * 0.4;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    _addLog('✂️ 切片完成: ${video.slices.length} 个片段');
  }

  Future<void> _simulateCoverGeneration(VideoFile video) async {
    final sampleTitles = [
      '精彩视频第{}集 | 不容错过的精彩瞬间',
      '独家内容 | 第{}部分完整版',
      '热门视频{}P | 高清资源分享',
      '视频合集第{}期 | 精选内容推荐',
    ];
    final random = Random();

    for (int i = 0; i < video.slices.length; i++) {
      video.slices[i].coverPath = 'assets/cover_placeholder.jpg';
      video.slices[i].title = sampleTitles[random.nextInt(sampleTitles.length)]
          .replaceAll('{}', '${i + 1}');

      video.progress = 0.4 + (i + 1) / video.slices.length * 0.3;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _addLog('🖼️ 封面生成完成');
  }

  Future<void> _simulateCaptionGeneration(VideoFile video) async {
    final sampleCaptions = [
      '🔥 精彩内容来袭！这是一段令人叹为观止的视频，包含了最新、最热、最精彩的内容。不要错过每一个精彩瞬间！\n\n📌 关注频道获取更多精彩内容\n#视频 #精彩 #推荐',
      '💎 独家高清内容分享！本期视频为您带来最优质的内容体验，欢迎转发分享给更多朋友！\n\n⭐ 喜欢请转发支持\n#独家 #高清 #分享',
      '🎯 今日精选内容！每天为您精心挑选最值得观看的视频内容，让您的碎片时间物有所值！\n\n👉 点击加入我们的频道\n#精选 #每日更新 #推荐',
    ];
    final random = Random();

    for (int i = 0; i < video.slices.length; i++) {
      video.slices[i].caption = sampleCaptions[random.nextInt(sampleCaptions.length)];
      video.slices[i].status = VideoStatus.ready;
      video.slices[i].progress = 1.0;

      video.progress = 0.7 + (i + 1) / video.slices.length * 0.3;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 250));
    }
    _addLog('📝 文案生成完成');
  }

  Future<void> processAllPending() async {
    final pending = _videos.where((v) => v.status == VideoStatus.pending).toList();
    for (final video in pending) {
      await processVideo(video);
    }
  }

  // ==================== 发布 ====================
  Future<void> publishSlice(VideoSlice slice, VideoFile video) async {
    if (!_botConfig.isConnected) {
      _addLog('❌ 未连接 Bot，请先配置并连接');
      return;
    }
    if (slice.status == VideoStatus.publishing || slice.status == VideoStatus.published) return;

    slice.status = VideoStatus.publishing;
    notifyListeners();

    final task = PublishTask(
      id: _uuid.v4(),
      videoSliceId: slice.id,
      videoFileName: slice.fileName,
      status: TaskStatus.running,
      type: TaskType.publish,
      message: '发送到 Telegram...',
    );
    _tasks.insert(0, task);
    notifyListeners();

    _addLog('📤 正在发布: ${slice.fileName}');

    // 模拟发布过程
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 300));
      task.progress = i / 10;
      task.message = i < 5 ? '上传视频中... ${(i * 10)}%' : '发送消息... ${((i - 5) * 20)}%';
      notifyListeners();
    }

    // 模拟成功
    slice.status = VideoStatus.published;
    slice.publishedAt = DateTime.now();
    task.status = TaskStatus.done;
    task.message = '发布成功 ✓';
    task.completedAt = DateTime.now();

    final record = PublishRecord(
      id: _uuid.v4(),
      channelId: _botConfig.channelId,
      channelName: _botConfig.channelName.isNotEmpty ? _botConfig.channelName : '我的频道',
      videoFileName: slice.fileName,
      title: slice.title ?? '无标题',
      caption: slice.caption ?? '',
      messageId: Random().nextInt(99999),
      publishedAt: DateTime.now(),
      views: Random().nextInt(1000),
    );
    _history.insert(0, record);

    _addLog('✅ 发布成功: ${slice.fileName} → ${record.channelName}');
    notifyListeners();
  }

  Future<void> publishAllReady() async {
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.status == VideoStatus.ready) {
          await publishSlice(slice, video);
          if (_botConfig.publishInterval > 0) {
            _addLog('⏱️ 等待 ${_botConfig.publishInterval} 秒后继续...');
            await Future.delayed(Duration(seconds: _botConfig.publishInterval ~/ 10));
          }
        }
      }
    }
  }

  void updateSliceTitle(String sliceId, String title) {
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.id == sliceId) {
          slice.title = title;
          notifyListeners();
          return;
        }
      }
    }
  }

  void updateSliceCaption(String sliceId, String caption) {
    for (final video in _videos) {
      for (final slice in video.slices) {
        if (slice.id == sliceId) {
          slice.caption = caption;
          notifyListeners();
          return;
        }
      }
    }
  }

  void updateSliceConfig(String videoId, SliceConfig config) {
    final video = _videos.firstWhere((v) => v.id == videoId, orElse: () => throw Exception());
    video.sliceConfig = config;
    notifyListeners();
  }

  // ==================== 日志 ====================
  void _addLog(String message) {
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    _logOutput = '[$timeStr] $message\n$_logOutput';
    if (_logOutput.length > 5000) {
      _logOutput = _logOutput.substring(0, 5000);
    }
    notifyListeners();
  }

  void clearLog() {
    _logOutput = '';
    notifyListeners();
  }

  // ==================== 演示数据 ====================
  void _initDemoData() {
    final random = Random();
    final sampleFiles = [
      '精彩合集_第01期.mp4',
      '独家内容_高清版.mp4',
      '热门视频_20240315.mp4',
      '频道精选_周末特辑.mp4',
    ];

    for (int i = 0; i < sampleFiles.length; i++) {
      final video = VideoFile(
        id: _uuid.v4(),
        path: '/videos/${sampleFiles[i]}',
        fileName: sampleFiles[i],
        duration: 120 + random.nextDouble() * 240,
        fileSize: (50 + random.nextInt(300)) * 1024 * 1024,
        status: i == 0 ? VideoStatus.ready : i == 1 ? VideoStatus.published : VideoStatus.pending,
      );

      if (video.status == VideoStatus.ready || video.status == VideoStatus.published) {
        final sliceCount = 2 + random.nextInt(3);
        for (int j = 0; j < sliceCount; j++) {
          final slice = VideoSlice(
            id: _uuid.v4(),
            originalVideoId: video.id,
            fileName: '${sampleFiles[i].replaceAll('.mp4', '')}_part${j + 1}.mp4',
            startTime: j * 60.0,
            endTime: (j + 1) * 60.0,
            duration: 60,
            title: '精彩视频第 ${j + 1} 集 | 不容错过',
            caption: '🔥 精彩内容来袭！关注获取更多\n#视频 #精彩 #推荐',
            status: video.status == VideoStatus.published
                ? VideoStatus.published
                : VideoStatus.ready,
            progress: 1.0,
          );
          if (slice.status == VideoStatus.published) {
            slice.publishedAt = DateTime.now().subtract(Duration(hours: random.nextInt(24)));
          }
          video.slices.add(slice);
        }
      }
      _videos.add(video);
    }

    // 演示历史
    final channels = ['@my_channel', '@tech_channel'];
    for (int i = 0; i < 8; i++) {
      _history.add(PublishRecord(
        id: _uuid.v4(),
        channelId: channels[i % 2],
        channelName: i % 2 == 0 ? '我的主频道' : '技术分享频道',
        videoFileName: '视频片段_${i + 1}.mp4',
        title: '精彩内容第 ${i + 1} 期',
        caption: '精彩内容，欢迎关注！',
        messageId: 10000 + i,
        publishedAt: DateTime.now().subtract(Duration(hours: i * 3 + random.nextInt(3))),
        views: random.nextInt(5000) + 100,
        forwards: random.nextInt(200),
      ));
    }

    _addLog('🚀 Channel Publisher 已启动');
    _addLog('💡 提示：请在设置页面配置 Telegram Bot Token 和频道 ID');
  }

  // ==================== AI 重新生成 ====================
  Future<void> regenerateCaption(VideoSlice slice) async {
    _addLog('🤖 AI 重新生成文案中...');
    await Future.delayed(const Duration(seconds: 2));

    final samples = [
      '🌟 超精彩内容！本视频带来了独特的视角和深度内容，每一帧都值得细细品味。立即观看，不要错过！\n\n📲 关注我们，每天更新优质内容\n#精彩 #推荐 #必看',
      '💥 爆款内容来袭！数万人已经观看，你还在等什么？点击立即观看，感受不一样的精彩！\n\n🔔 开启通知，不错过每次更新\n#热门 #爆款 #推荐',
      '✨ 品质保证！我们精心为您筛选最优质的内容，只为给您最好的观看体验。\n\n👍 觉得好看请转发支持\n#品质 #优选 #推荐',
    ];

    slice.caption = samples[Random().nextInt(samples.length)];
    _addLog('✅ 文案重新生成完成');
    notifyListeners();
  }

  Future<void> regenerateTitle(VideoSlice slice) async {
    _addLog('🤖 AI 重新生成标题中...');
    await Future.delayed(const Duration(seconds: 1));

    final titles = [
      '🔥 今日精选 | 超高质量内容不容错过',
      '💎 独家内容 | ${DateTime.now().month}月最热视频',
      '⭐ 精品推荐 | 数千人已转发的爆款内容',
      '🎯 必看内容 | 质量保证绝不让你失望',
    ];
    slice.title = titles[Random().nextInt(titles.length)];
    _addLog('✅ 标题重新生成完成');
    notifyListeners();
  }
}
