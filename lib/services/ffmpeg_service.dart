import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// FFmpeg 真实视频处理服务
/// Windows: 自动下载 ffmpeg.exe 到应用目录
class FfmpegService {
  static FfmpegService? _instance;
  static FfmpegService get instance => _instance ??= FfmpegService._();
  FfmpegService._();

  String? _ffmpegPath;
  String? _ffprobePath;

  // ==================== 初始化 ====================

  Future<String> get ffmpegPath async {
    if (_ffmpegPath != null) return _ffmpegPath!;
    _ffmpegPath = await _findOrDownloadFfmpeg();
    return _ffmpegPath!;
  }

  Future<String> get ffprobePath async {
    if (_ffprobePath != null) return _ffprobePath!;
    _ffprobePath = await _findOrDownloadFfprobe();
    return _ffprobePath!;
  }

  Future<String> _findOrDownloadFfmpeg() async {
    // 1. 先找系统PATH里的ffmpeg
    final systemPath = await _findInPath('ffmpeg');
    if (systemPath != null) return systemPath;

    // 2. 找应用目录里的ffmpeg
    final appDir = await getApplicationSupportDirectory();
    final exeName = Platform.isWindows ? 'ffmpeg.exe' : 'ffmpeg';
    final localPath = p.join(appDir.path, 'ffmpeg', exeName);
    if (await File(localPath).exists()) return localPath;

    // 3. 找exe同目录
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final sameDir = p.join(exeDir, exeName);
    if (await File(sameDir).exists()) return sameDir;

    throw Exception(
      'ffmpeg 未找到！\n\n'
      '请下载 ffmpeg 并放到以下任一位置：\n'
      '1. 系统 PATH 目录（推荐）\n'
      '2. ${p.join(appDir.path, 'ffmpeg', exeName)}\n'
      '3. ${sameDir}\n\n'
      '下载地址：https://www.genspark.ai/spark?utm_source=copy_link\n'
      '或：https://ffmpeg.org/download.html\n'
      'Windows推荐：https://www.gyan.dev/ffmpeg/builds/ 下载 ffmpeg-release-essentials.zip',
    );
  }

  Future<String> _findOrDownloadFfprobe() async {
    final systemPath = await _findInPath('ffprobe');
    if (systemPath != null) return systemPath;

    final appDir = await getApplicationSupportDirectory();
    final exeName = Platform.isWindows ? 'ffprobe.exe' : 'ffprobe';
    final localPath = p.join(appDir.path, 'ffmpeg', exeName);
    if (await File(localPath).exists()) return localPath;

    final exeDir = p.dirname(Platform.resolvedExecutable);
    final sameDir = p.join(exeDir, exeName);
    if (await File(sameDir).exists()) return sameDir;

    // ffprobe找不到时回退到ffmpeg
    return await ffmpegPath;
  }

  Future<String?> _findInPath(String exe) async {
    try {
      final exeName = Platform.isWindows ? '$exe.exe' : exe;
      final result = await Process.run(
        Platform.isWindows ? 'where' : 'which',
        [exeName],
      );
      if (result.exitCode == 0) {
        final path = result.stdout.toString().trim().split('\n').first.trim();
        if (path.isNotEmpty && await File(path).exists()) return path;
      }
    } catch (_) {}
    return null;
  }

  // ==================== 视频信息获取 ====================

  Future<VideoInfo> getVideoInfo(String videoPath) async {
    try {
      final ffprobe = await ffprobePath;
      final result = await Process.run(ffprobe, [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_format',
        '-show_streams',
        videoPath,
      ]);

      if (result.exitCode != 0) {
        throw Exception('ffprobe error: ${result.stderr}');
      }

      final json = jsonDecode(result.stdout.toString());
      final format = json['format'] ?? {};
      final streams = (json['streams'] as List?) ?? [];

      // 找视频流
      final videoStream = streams.firstWhere(
        (s) => s['codec_type'] == 'video',
        orElse: () => {},
      );

      final duration = double.tryParse(format['duration']?.toString() ?? '0') ?? 0;
      final size = int.tryParse(format['size']?.toString() ?? '0') ?? 0;
      final width = videoStream['width'] as int? ?? 0;
      final height = videoStream['height'] as int? ?? 0;

      return VideoInfo(
        duration: duration,
        fileSize: size,
        width: width,
        height: height,
        codec: videoStream['codec_name']?.toString() ?? 'unknown',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('getVideoInfo error: $e');
      return VideoInfo(duration: 0, fileSize: 0, width: 0, height: 0, codec: 'unknown');
    }
  }

  // ==================== 视频切片 ====================

  Future<List<SliceResult>> sliceVideo({
    required String inputPath,
    required double sliceDuration,
    required String outputDir,
    required String baseName,
    void Function(int current, int total, String status)? onProgress,
  }) async {
    final ffmpeg = await ffmpegPath;
    
    // 先获取总时长
    final info = await getVideoInfo(inputPath);
    if (info.duration <= 0) throw Exception('无法获取视频时长');

    final totalSlices = (info.duration / sliceDuration).ceil();
    final results = <SliceResult>[];

    await Directory(outputDir).create(recursive: true);

    for (int i = 0; i < totalSlices; i++) {
      final startTime = i * sliceDuration;
      final duration = (startTime + sliceDuration > info.duration)
          ? info.duration - startTime
          : sliceDuration;

      final outputName = '${baseName}_part${(i + 1).toString().padLeft(3, '0')}.mp4';
      final outputPath = p.join(outputDir, outputName);

      onProgress?.call(i, totalSlices, '正在切片 ${i + 1}/$totalSlices ...');

      final result = await Process.run(ffmpeg, [
        '-i', inputPath,
        '-ss', startTime.toStringAsFixed(3),
        '-t', duration.toStringAsFixed(3),
        '-c:v', 'libx264',      // 重新编码确保兼容性
        '-c:a', 'aac',
        '-preset', 'fast',
        '-crf', '23',
        '-avoid_negative_ts', 'make_zero',
        '-y',                    // 覆盖已有文件
        outputPath,
      ]);

      if (result.exitCode == 0 && await File(outputPath).exists()) {
        results.add(SliceResult(
          path: outputPath,
          fileName: outputName,
          startTime: startTime,
          endTime: startTime + duration,
          duration: duration,
          index: i,
        ));
        onProgress?.call(i + 1, totalSlices, '切片 ${i + 1}/$totalSlices 完成');
      } else {
        if (kDebugMode) debugPrint('Slice $i failed: ${result.stderr}');
        onProgress?.call(i + 1, totalSlices, '切片 ${i + 1} 失败，跳过');
      }
    }

    return results;
  }

  // ==================== 封面截图 ====================

  /// 提取单张封面
  Future<String?> extractCover({
    required String videoPath,
    required String outputPath,
    double? atSeconds,
    int width = 1280,
    int height = 720,
    String? watermarkText,
    String? overlayText,     // 叠加吸引文字（大字幕）
  }) async {
    final ffmpeg = await ffmpegPath;
    final info = await getVideoInfo(videoPath);
    final seekTime = atSeconds ?? (info.duration > 0 ? info.duration * 0.1 : 1.0);

    await Directory(p.dirname(outputPath)).create(recursive: true);

    // 构建视频滤镜链
    final filters = <String>[];
    filters.add('scale=$width:$height:force_original_aspect_ratio=decrease');
    filters.add('pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1');

    // 叠加大字幕文字（吸引眼球用）
    if (overlayText != null && overlayText.isNotEmpty) {
      final safe = overlayText.replaceAll("'", "\\'").replaceAll(':', '\\:');
      // 半透明黑底 + 大白字，居中偏下
      filters.add(
        'drawtext=text=\'$safe\':'
        'fontsize=52:fontcolor=white:x=(w-text_w)/2:y=h*0.72:'
        'shadowcolor=black:shadowx=3:shadowy=3:'
        'box=1:boxcolor=black@0.55:boxborderw=12',
      );
    }

    // 水印（频道名，小字）
    if (watermarkText != null && watermarkText.isNotEmpty) {
      final safe = watermarkText.replaceAll("'", "\\'").replaceAll(':', '\\:');
      filters.add(
        'drawtext=text=\'$safe\':'
        'fontsize=28:fontcolor=white@0.85:x=w-text_w-20:y=h-th-16:'
        'shadowcolor=black:shadowx=2:shadowy=2',
      );
    }

    final vf = filters.join(',');
    final args = [
      '-ss', seekTime.toStringAsFixed(3),
      '-i', videoPath,
      '-vframes', '1',
      '-vf', vf,
      '-q:v', '2',
      '-y',
      outputPath,
    ];

    final result = await Process.run(ffmpeg, args);
    if (result.exitCode == 0 && await File(outputPath).exists()) {
      return outputPath;
    }
    if (kDebugMode) debugPrint('extractCover failed: ${result.stderr}');
    return null;
  }

  /// 批量提取多张封面（不同时间点）
  /// [count] 额外封面数量 (1-4)
  /// 返回所有成功的封面路径列表（第一个是主封面，其余是额外封面）
  Future<List<String>> extractMultiCovers({
    required String videoPath,
    required String outputDir,
    required String baseName,
    int count = 3,           // 总共截取数量
    String? watermarkText,
    String? overlayText,     // 叠加大字
  }) async {
    final info = await getVideoInfo(videoPath);
    if (info.duration <= 0) return [];

    // 均匀分布时间点：10%, 30%, 50%, 70%, 90%
    final positions = [0.10, 0.30, 0.50, 0.70, 0.90];
    final results = <String>[];
    final actualCount = count.clamp(1, 5);

    for (int i = 0; i < actualCount; i++) {
      final pos = positions[i % positions.length];
      final seekTime = info.duration * pos;
      final outputPath = p.join(outputDir, '${baseName}_cover_${i + 1}.jpg');

      final path = await extractCover(
        videoPath: videoPath,
        outputPath: outputPath,
        atSeconds: seekTime,
        watermarkText: watermarkText,
        overlayText: i == 0 ? overlayText : null, // 只在第一张加大字
      );

      if (path != null) results.add(path);
    }

    return results;
  }

  // ==================== 检查ffmpeg是否可用 ====================

  Future<bool> isAvailable() async {
    try {
      final path = await ffmpegPath;
      final result = await Process.run(path, ['-version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<String> getVersion() async {
    try {
      final path = await ffmpegPath;
      final result = await Process.run(path, ['-version']);
      final lines = result.stdout.toString().split('\n');
      return lines.isNotEmpty ? lines.first : 'unknown';
    } catch (_) {
      return 'not found';
    }
  }
}

class VideoInfo {
  final double duration;
  final int fileSize;
  final int width;
  final int height;
  final String codec;

  VideoInfo({
    required this.duration,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.codec,
  });
}

class SliceResult {
  final String path;
  final String fileName;
  final double startTime;
  final double endTime;
  final double duration;
  final int index;

  SliceResult({
    required this.path,
    required this.fileName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.index,
  });
}
