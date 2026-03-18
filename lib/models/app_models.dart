import 'package:flutter/material.dart';

// ==================== 枚举 ====================

enum VideoStatus {
  pending,    // 待处理
  processing, // 处理中
  ready,      // 已就绪
  publishing, // 发布中
  published,  // 已发布
  failed,     // 失败
}

enum TaskType {
  slice,      // 切片
  cover,      // 封面
  caption,    // 文案
  publish,    // 发布
}

enum TaskStatus {
  waiting,
  running,
  done,
  error,
}

// ==================== 模型 ====================

class BotConfig {
  String botToken;
  String channelId;
  String channelName;
  bool isConnected;
  String? aiApiKey;
  String? aiModel;
  int publishInterval; // 发布间隔（分钟）
  bool autoPublish;

  BotConfig({
    this.botToken = '',
    this.channelId = '',
    this.channelName = '',
    this.isConnected = false,
    this.aiApiKey,
    this.aiModel = 'gpt-3.5-turbo',
    this.publishInterval = 30,
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
    publishInterval: json['publishInterval'] ?? 30,
    autoPublish: json['autoPublish'] ?? false,
  );
}

class VideoSlice {
  final String id;
  final String originalVideoId;
  final String fileName;
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

class VideoFile {
  final String id;
  final String path;
  final String fileName;
  final double duration;
  final int fileSize;
  VideoStatus status;
  double progress;
  String? errorMessage;
  List<VideoSlice> slices;
  SliceConfig sliceConfig;
  DateTime addedAt;
  String? thumbnailPath;

  VideoFile({
    required this.id,
    required this.path,
    required this.fileName,
    required this.duration,
    required this.fileSize,
    this.status = VideoStatus.pending,
    this.progress = 0,
    this.errorMessage,
    List<VideoSlice>? slices,
    SliceConfig? sliceConfig,
    DateTime? addedAt,
    this.thumbnailPath,
  })  : slices = slices ?? [],
        sliceConfig = sliceConfig ?? SliceConfig(),
        addedAt = addedAt ?? DateTime.now();

  String get formattedDuration {
    final mins = duration ~/ 60;
    final secs = (duration % 60).toInt();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class SliceConfig {
  double sliceDuration;   // 每片时长（秒）
  bool autoSlice;         // 自动切片
  bool generateCover;     // 生成封面
  bool generateCaption;   // 生成文案
  bool addWatermark;      // 添加水印
  String watermarkText;   // 水印文字
  String captionPrompt;   // 文案提示词
  CoverStyle coverStyle;

  SliceConfig({
    this.sliceDuration = 60,
    this.autoSlice = true,
    this.generateCover = true,
    this.generateCaption = true,
    this.addWatermark = false,
    this.watermarkText = '',
    this.captionPrompt = '请根据视频内容生成吸引人的标题和描述',
    this.coverStyle = CoverStyle.firstFrame,
  });
}

enum CoverStyle {
  firstFrame,   // 第一帧
  bestFrame,    // 最佳帧
  middleFrame,  // 中间帧
  custom,       // 自定义
}

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
  String? errorMessage;

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
    this.errorMessage,
  }) : createdAt = createdAt ?? DateTime.now();
}

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
}

// ==================== 状态颜色 ====================

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
