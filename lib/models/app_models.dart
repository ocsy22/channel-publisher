import 'package:flutter/material.dart';
import '../services/caption_service.dart';

// ==================== 枚举 ====================
enum VideoStatus { pending, processing, ready, publishing, published, failed }
enum TaskType { slice, cover, caption, publish }
enum TaskStatus { waiting, running, done, error }
enum CoverStyle { firstFrame, bestFrame, middleFrame, custom }

// AI提供商枚举
enum AiProvider {
  openai,        // OpenAI (ChatGPT)
  deepseek,      // DeepSeek (国内可用，便宜)
  qianwen,       // 通义千问 (阿里云)
  zhipu,         // 智谱GLM (国内免费额度)
  moonshot,      // Moonshot (Kimi)
  custom,        // 自定义API
}

// 文案格式
enum CaptionFormat {
  simple,        // 简洁（只有标题+标签）
  standard,      // 标准（标题+描述+标签）
  rich,          // 丰富（标题+描述+表情+引用链接+标签）
  custom,        // 自定义
}

// ==================== BotConfig ====================
class BotConfig {
  String botToken;
  String channelId;
  String channelName;
  bool isConnected;

  // AI配置
  String aiProvider;        // ai提供商枚举名
  String? aiApiKey;
  String? aiModel;
  String? aiBaseUrl;        // 自定义API地址
  String? aiSecondaryKey;   // 第二备用Key

  // 发布配置
  int publishInterval;
  bool autoPublish;
  bool ignoreSslErrors;
  String outputDir;

  // 文案格式配置
  String captionFormat;     // CaptionFormat枚举名
  bool enableEmoji;         // 是否加表情
  bool enableTags;          // 是否加标签
  bool enableTgQuote;       // 是否加TG引用/频道链接
  String tgChannelLink;     // 频道链接，例如 @mychannel
  bool enableBoldTitle;     // 标题是否加粗
  int captionMaxLength;     // 文案最大字数(不含标题标签)
  String customCaptionTemplate; // 自定义文案模板

  // 封面文字配置
  bool enableCoverText;     // 封面是否叠加吸引文字
  bool aiGenerateCoverText; // 用AI生成封面文字
  String coverTextPreset;   // 预设封面文字(逗号分隔备选)

  BotConfig({
    this.botToken = '',
    this.channelId = '',
    this.channelName = '',
    this.isConnected = false,
    this.aiProvider = 'openai',
    this.aiApiKey,
    this.aiModel,
    this.aiBaseUrl,
    this.aiSecondaryKey,
    this.publishInterval = 10,
    this.autoPublish = false,
    this.ignoreSslErrors = true,
    this.outputDir = '',
    this.captionFormat = 'standard',
    this.enableEmoji = true,
    this.enableTags = true,
    this.enableTgQuote = false,
    this.tgChannelLink = '',
    this.enableBoldTitle = true,
    this.captionMaxLength = 200,
    this.customCaptionTemplate = '',
    this.enableCoverText = false,
    this.aiGenerateCoverText = true,
    this.coverTextPreset = '',
  });

  Map<String, dynamic> toJson() => {
    'botToken': botToken,
    'channelId': channelId,
    'channelName': channelName,
    'aiProvider': aiProvider,
    'aiApiKey': aiApiKey ?? '',
    'aiModel': aiModel ?? '',
    'aiBaseUrl': aiBaseUrl ?? '',
    'aiSecondaryKey': aiSecondaryKey ?? '',
    'publishInterval': publishInterval,
    'autoPublish': autoPublish,
    'ignoreSslErrors': ignoreSslErrors,
    'outputDir': outputDir,
    'captionFormat': captionFormat,
    'enableEmoji': enableEmoji,
    'enableTags': enableTags,
    'enableTgQuote': enableTgQuote,
    'tgChannelLink': tgChannelLink,
    'enableBoldTitle': enableBoldTitle,
    'captionMaxLength': captionMaxLength,
    'customCaptionTemplate': customCaptionTemplate,
    'enableCoverText': enableCoverText,
    'aiGenerateCoverText': aiGenerateCoverText,
    'coverTextPreset': coverTextPreset,
  };

  factory BotConfig.fromJson(Map<String, dynamic> json) => BotConfig(
    botToken: json['botToken'] ?? '',
    channelId: json['channelId'] ?? '',
    channelName: json['channelName'] ?? '',
    aiProvider: json['aiProvider'] ?? 'openai',
    aiApiKey: json['aiApiKey'] ?? '',
    aiModel: json['aiModel'] ?? '',
    aiBaseUrl: json['aiBaseUrl'] ?? '',
    aiSecondaryKey: json['aiSecondaryKey'] ?? '',
    publishInterval: json['publishInterval'] ?? 10,
    autoPublish: json['autoPublish'] ?? false,
    ignoreSslErrors: json['ignoreSslErrors'] ?? true,
    outputDir: json['outputDir'] ?? '',
    captionFormat: json['captionFormat'] ?? 'standard',
    enableEmoji: json['enableEmoji'] ?? true,
    enableTags: json['enableTags'] ?? true,
    enableTgQuote: json['enableTgQuote'] ?? false,
    tgChannelLink: json['tgChannelLink'] ?? '',
    enableBoldTitle: json['enableBoldTitle'] ?? true,
    captionMaxLength: json['captionMaxLength'] ?? 200,
    customCaptionTemplate: json['customCaptionTemplate'] ?? '',
    enableCoverText: json['enableCoverText'] ?? false,
    aiGenerateCoverText: json['aiGenerateCoverText'] ?? true,
    coverTextPreset: json['coverTextPreset'] ?? '',
  );

  // 获取该Provider的默认model
  String get defaultModel {
    switch (aiProvider) {
      case 'openai':   return aiModel?.isNotEmpty == true ? aiModel! : 'gpt-3.5-turbo';
      case 'deepseek': return aiModel?.isNotEmpty == true ? aiModel! : 'deepseek-chat';
      case 'qianwen':  return aiModel?.isNotEmpty == true ? aiModel! : 'qwen-turbo';
      case 'zhipu':    return aiModel?.isNotEmpty == true ? aiModel! : 'glm-4-flash';
      case 'moonshot': return aiModel?.isNotEmpty == true ? aiModel! : 'moonshot-v1-8k';
      case 'custom':   return aiModel?.isNotEmpty == true ? aiModel! : 'gpt-3.5-turbo';
      default:         return 'gpt-3.5-turbo';
    }
  }

  // 获取该Provider的API Base URL
  String get effectiveBaseUrl {
    if (aiProvider == 'custom' && aiBaseUrl?.isNotEmpty == true) {
      return aiBaseUrl!;
    }
    switch (aiProvider) {
      case 'openai':   return 'https://api.openai.com/v1';
      case 'deepseek': return 'https://api.deepseek.com/v1';
      case 'qianwen':  return 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      case 'zhipu':    return 'https://open.bigmodel.cn/api/paas/v4';
      case 'moonshot': return 'https://api.moonshot.cn/v1';
      case 'custom':   return aiBaseUrl ?? 'https://api.openai.com/v1';
      default:         return 'https://api.openai.com/v1';
    }
  }
}

// ==================== VideoSlice ====================
class VideoSlice {
  final String id;
  final String originalVideoId;
  final String fileName;
  String? realPath;
  final double startTime;
  final double endTime;
  double duration;
  String? coverPath;
  List<String> extraCoverPaths; // 额外自动截取的封面
  String? coverText;            // 封面叠加文字（AI生成）
  String? title;
  String? caption;
  List<String> tags;
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
    List<String>? extraCoverPaths,
    this.coverText,
    this.title,
    this.caption,
    List<String>? tags,
    this.status = VideoStatus.pending,
    this.progress = 0,
    this.errorMessage,
    this.publishedAt,
  })  : extraCoverPaths = extraCoverPaths ?? [],
        tags = tags ?? [];

  // 所有封面路径（主封面 + 额外封面）
  List<String> get allCoverPaths {
    final all = <String>[];
    if (coverPath != null && coverPath!.isNotEmpty) all.add(coverPath!);
    all.addAll(extraCoverPaths.where((p) => p.isNotEmpty));
    return all;
  }
}

// ==================== SliceConfig ====================
class SliceConfig {
  double sliceDuration;
  bool autoSlice;
  bool generateCover;
  int extraCoverCount;          // 额外截图张数（0-4）
  bool generateCaption;
  bool generateTags;
  bool addWatermark;
  String watermarkText;
  String captionPrompt;
  CoverStyle coverStyle;
  CaptionMode captionMode;

  SliceConfig({
    this.sliceDuration = 60,
    this.autoSlice = true,
    this.generateCover = true,
    this.extraCoverCount = 2,
    this.generateCaption = true,
    this.generateTags = true,
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
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize <= 0) return '--';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
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
  final List<String> tags;
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
    List<String>? tags,
    required this.messageId,
    required this.publishedAt,
    this.views = 0,
    this.forwards = 0,
  }) : tags = tags ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'channelName': channelName,
    'videoFileName': videoFileName,
    'title': title,
    'caption': caption,
    'tags': tags,
    'messageId': messageId,
    'publishedAt': publishedAt.toIso8601String(),
    'views': views,
    'forwards': forwards,
  };

  factory PublishRecord.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    List<String> tags = [];
    if (rawTags is List) {
      tags = rawTags.map((e) => e.toString()).toList();
    }
    return PublishRecord(
      id: json['id'] ?? '',
      channelId: json['channelId'] ?? '',
      channelName: json['channelName'] ?? '',
      videoFileName: json['videoFileName'] ?? '',
      title: json['title'] ?? '',
      caption: json['caption'] ?? '',
      tags: tags,
      messageId: json['messageId'] ?? 0,
      publishedAt:
          DateTime.tryParse(json['publishedAt'] ?? '') ?? DateTime.now(),
      views: json['views'] ?? 0,
      forwards: json['forwards'] ?? 0,
    );
  }
}

// ==================== 扩展 ====================
extension VideoStatusExtension on VideoStatus {
  Color get color {
    switch (this) {
      case VideoStatus.pending:    return const Color(0xFF9E9E9E);
      case VideoStatus.processing: return const Color(0xFF2196F3);
      case VideoStatus.ready:      return const Color(0xFF4CAF50);
      case VideoStatus.publishing: return const Color(0xFFFF9800);
      case VideoStatus.published:  return const Color(0xFF0088CC);
      case VideoStatus.failed:     return const Color(0xFFF44336);
    }
  }

  String get label {
    switch (this) {
      case VideoStatus.pending:    return '待处理';
      case VideoStatus.processing: return '处理中';
      case VideoStatus.ready:      return '已就绪';
      case VideoStatus.publishing: return '发布中';
      case VideoStatus.published:  return '已发布';
      case VideoStatus.failed:     return '失败';
    }
  }
}

extension TaskStatusExtension on TaskStatus {
  Color get color {
    switch (this) {
      case TaskStatus.waiting: return const Color(0xFF9E9E9E);
      case TaskStatus.running: return const Color(0xFF2196F3);
      case TaskStatus.done:    return const Color(0xFF4CAF50);
      case TaskStatus.error:   return const Color(0xFFF44336);
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.waiting: return '等待中';
      case TaskStatus.running: return '进行中';
      case TaskStatus.done:    return '已完成';
      case TaskStatus.error:   return '错误';
    }
  }
}

extension AiProviderExtension on AiProvider {
  String get name {
    switch (this) {
      case AiProvider.openai:   return 'openai';
      case AiProvider.deepseek: return 'deepseek';
      case AiProvider.qianwen:  return 'qianwen';
      case AiProvider.zhipu:    return 'zhipu';
      case AiProvider.moonshot: return 'moonshot';
      case AiProvider.custom:   return 'custom';
    }
  }

  String get displayName {
    switch (this) {
      case AiProvider.openai:   return 'OpenAI (ChatGPT)';
      case AiProvider.deepseek: return 'DeepSeek (国内可用)';
      case AiProvider.qianwen:  return '通义千问 (阿里云)';
      case AiProvider.zhipu:    return '智谱GLM (有免费额度)';
      case AiProvider.moonshot: return 'Kimi (月之暗面)';
      case AiProvider.custom:   return '自定义API';
    }
  }

  String get defaultModel {
    switch (this) {
      case AiProvider.openai:   return 'gpt-3.5-turbo';
      case AiProvider.deepseek: return 'deepseek-chat';
      case AiProvider.qianwen:  return 'qwen-turbo';
      case AiProvider.zhipu:    return 'glm-4-flash';
      case AiProvider.moonshot: return 'moonshot-v1-8k';
      case AiProvider.custom:   return 'gpt-3.5-turbo';
    }
  }

  String get apiKeyHint {
    switch (this) {
      case AiProvider.openai:   return 'sk-xxxxxxxxxxxx';
      case AiProvider.deepseek: return 'sk-xxxxxxxxxxxx (platform.deepseek.com)';
      case AiProvider.qianwen:  return 'sk-xxxxxxxxxxxx (dashscope.aliyuncs.com)';
      case AiProvider.zhipu:    return 'xxxxxxxx.xxxxxxxx (open.bigmodel.cn)';
      case AiProvider.moonshot: return 'sk-xxxxxxxxxxxx (platform.moonshot.cn)';
      case AiProvider.custom:   return '输入你的API Key';
    }
  }
}
