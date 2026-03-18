import 'package:flutter/material.dart';
import '../services/caption_service.dart';

// ==================== 枚举 ====================
enum VideoStatus { pending, processing, ready, publishing, published, failed }
enum TaskType { slice, cover, caption, publish }
enum TaskStatus { waiting, running, done, error }
enum CoverStyle { firstFrame, bestFrame, middleFrame, custom }

// ==================== BotConfig ====================
class BotConfig {
  String botToken;
  String channelId;
  String channelName;
  bool isConnected;
  String? aiApiKey;
  String? aiModel;
  int publishInterval;
  bool autoPublish;

  BotConfig({
    this.botToken = '',
    this.channelId = '',
    this.channelName = '',
    this.isConnected = false,
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.publishInterval = 10,
    this.autoPublish = false,
  });

  Map<String, dynamic> toJson() => {
    'botToken': botToken,
    'channelId': channelId,
    'channelName': channelName,
    'aiApiKey': aiApiKey ?? '',
    'aiModel': aiModel ?? 'gpt-3.5-turbo',
    'publishInterval': publishInterval,
    'autoPublish': autoPublish,
  };

  factory BotConfig.fromJson(Map<String, dynamic> json) => BotConfig(
    botToken: json['botToken'] ?? '',
    channelId: json['channelId'] ?? '',
    channelName: json['channelName'] ?? '',
    aiApiKey: json['aiApiKey'] ?? '',
    aiModel: json['aiModel'] ?? 'gpt-3.5-turbo',
    publishInterval: json['publishInterval'] ?? 10,
    autoPublish: json['autoPublish'] ?? false,
  );
}

// ==================== VideoSlice ====================
class VideoSlice {
  final String id;
  final String originalVideoId;
  final String fileName;
  String? realPath;        // 切片后的真实文件路径
  final double startTime;
  final double endTime;
  double duration;
  String? coverPath;
  String? title;
  String? caption;
  VideoStatus status;
  double progress;
  String? errorMessage;
  DateTime? publishedAt;

  VideoSlice({
    required this.id,
    required this.originalVideoId,
    required this.fileName,
    this.realPath,
    required this.startTime,
    required this.endTime,
    this.duration = 0,
    this.coverPath,
    this.title,
    this.caption,
    this.status = VideoStatus.pending,
    this.progress = 0,
    this.errorMessage,
    this.publishedAt,
  });
}

// ==================== SliceConfig ====================
class SliceConfig {
  double sliceDuration;
  bool autoSlice;
  bool generateCover;
  bool generateCaption;
  bool addWatermark;
  String watermarkText;
  String captionPrompt;
  CoverStyle coverStyle;
  CaptionMode captionMode;   // 普通 or 成人

  SliceConfig({
    this.sliceDuration = 60,
    this.autoSlice = true,
    this.generateCover = true,
    this.generateCaption = true,
    this.addWatermark = false,
    this.watermarkText = '',
    this.captionPrompt = '',
    this.coverStyle = CoverStyle.firstFrame,
    this.captionMode = CaptionMode.normal,
  });
}

// ==================== VideoFile ====================
class VideoFile {
  final String id;
  final String path;
  final String fileName;
  double duration;
  int fileSize;
  VideoStatus status;
  double progress;
  String? errorMessage;
  List<VideoSlice> slices;
  SliceConfig sliceConfig;
  DateTime addedAt;

  VideoFile({
    required this.id,
    required this.path,
    required this.fileName,
    this.duration = 0,
    this.fileSize = 0,
    this.status = VideoStatus.pending,
    this.progress = 0,
    this.errorMessage,
    List<VideoSlice>? slices,
    SliceConfig? sliceConfig,
    DateTime? addedAt,
  })  : slices = slices ?? [],
        sliceConfig = sliceConfig ?? SliceConfig(),
        addedAt = addedAt ?? DateTime.now();

  String get formattedDuration {
    if (duration <= 0) return '--:--';
    final m = duration ~/ 60;
    final s = (duration % 60).toInt();
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  String get formattedSize {
    if (fileSize <= 0) return '--';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ==================== PublishTask ====================
class PublishTask {
  final String id;
  final String videoSliceId;
  final String videoFileName;
  TaskStatus status;
  TaskType type;
  double progress;
  String message;
  DateTime createdAt;
  DateTime? completedAt;

  PublishTask({
    required this.id,
    required this.videoSliceId,
    required this.videoFileName,
    this.status = TaskStatus.waiting,
    this.type = TaskType.publish,
    this.progress = 0,
    this.message = '等待中...',
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

// ==================== PublishRecord ====================
class PublishRecord {
  final String id;
  final String channelId;
  final String channelName;
  final String videoFileName;
  final String title;
  final String caption;
  final int messageId;
  DateTime publishedAt;
  int views;
  int forwards;

  PublishRecord({
    required this.id,
    required this.channelId,
    required this.channelName,
    required this.videoFileName,
    required this.title,
    required this.caption,
    required this.messageId,
    required this.publishedAt,
    this.views = 0,
    this.forwards = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'channelName': channelName,
    'videoFileName': videoFileName,
    'title': title,
    'caption': caption,
    'messageId': messageId,
    'publishedAt': publishedAt.toIso8601String(),
    'views': views,
    'forwards': forwards,
  };

  factory PublishRecord.fromJson(Map<String, dynamic> json) => PublishRecord(
    id: json['id'] ?? '',
    channelId: json['channelId'] ?? '',
    channelName: json['channelName'] ?? '',
    videoFileName: json['videoFileName'] ?? '',
    title: json['title'] ?? '',
    caption: json['caption'] ?? '',
    messageId: json['messageId'] ?? 0,
    publishedAt: DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
    views: json['views'] ?? 0,
    forwards: json['forwards'] ?? 0,
  );
}

// ==================== 扩展 ====================
extension VideoStatusExtension on VideoStatus {
  Color get color {
    switch (this) {
      case VideoStatus.pending: return const Color(0xFF9E9E9E);
      case VideoStatus.processing: return const Color(0xFF2196F3);
      case VideoStatus.ready: return const Color(0xFF4CAF50);
      case VideoStatus.publishing: return const Color(0xFFFF9800);
      case VideoStatus.published: return const Color(0xFF0088CC);
      case VideoStatus.failed: return const Color(0xFFF44336);
    }
  }
  String get label {
    switch (this) {
      case VideoStatus.pending: return '待处理';
      case VideoStatus.processing: return '处理中';
      case VideoStatus.ready: return '已就绪';
      case VideoStatus.publishing: return '发布中';
      case VideoStatus.published: return '已发布';
      case VideoStatus.failed: return '失败';
    }
  }
}

extension TaskStatusExtension on TaskStatus {
  Color get color {
    switch (this) {
      case TaskStatus.waiting: return const Color(0xFF9E9E9E);
      case TaskStatus.running: return const Color(0xFF2196F3);
      case TaskStatus.done: return const Color(0xFF4CAF50);
      case TaskStatus.error: return const Color(0xFFF44336);
    }
  }
  String get label {
    switch (this) {
      case TaskStatus.waiting: return '等待中';
      case TaskStatus.running: return '进行中';
      case TaskStatus.done: return '已完成';
      case TaskStatus.error: return '错误';
    }
  }
}
