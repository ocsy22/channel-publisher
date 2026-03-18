import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/app_models.dart';
import '../utils/app_theme.dart';

class VideoPreviewWidget extends StatefulWidget {
  final VideoFile video;

  const VideoPreviewWidget({super.key, required this.video});

  @override
  State<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<VideoPreviewWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _disposeController();
      _initPlayer();
    }
  }

  Future<void> _initPlayer() async {
    // Web平台不支持本地文件预览
    if (kIsWeb) return;

    final path = widget.video.path;
    if (path.isEmpty || path.startsWith('web://')) return;

    // 检查文件是否存在
    try {
      if (!await File(path).exists()) return;
    } catch (_) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final controller = VideoPlayerController.file(File(path));
      await controller.initialize();
      // 跳到10%处显示封面帧
      final totalMs = controller.value.duration.inMilliseconds;
      if (totalMs > 0) {
        await controller.seekTo(
            Duration(milliseconds: (totalMs * 0.1).toInt()));
      }
      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '预览加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isLoading = false;
    _error = null;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _buildWebInfo();
    }

    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 8),
              Text('加载预览...', style: TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_outlined, color: Colors.white38, size: 36),
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _initPlayer,
                child: const Text('重试', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isInitialized && _controller != null) {
      return Stack(
        children: [
          Container(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          // 控制栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Row(
                children: [
                  // 播放/暂停
                  InkWell(
                    onTap: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                    child: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 时间显示
                  ValueListenableBuilder(
                    valueListenable: _controller!,
                    builder: (context, value, _) {
                      return Text(
                        '${_fmtDuration(value.position)} / ${_fmtDuration(value.duration)}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  // 进度条
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: _controller!,
                      builder: (context, value, _) {
                        final total = value.duration.inMilliseconds;
                        final pos = value.position.inMilliseconds;
                        return SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            trackHeight: 3,
                            overlayShape: SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: total > 0
                                ? pos.toDouble().clamp(0, total.toDouble())
                                : 0,
                            min: 0,
                            max: total > 0 ? total.toDouble() : 1,
                            onChanged: (v) {
                              _controller!.seekTo(
                                  Duration(milliseconds: v.toInt()));
                            },
                            activeColor: AppTheme.primary,
                            inactiveColor: Colors.white24,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 文件名
          Positioned(
            top: 8,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.video.fileName,
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
            ),
          ),
        ],
      );
    }

    // 没有视频可预览时显示信息
    return _buildVideoInfo();
  }

  Widget _buildWebInfo() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.movie_rounded,
                color: AppTheme.primary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.video.fileName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(
                    '时长：${widget.video.formattedDuration} · 大小：${widget.video.formattedSize}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                const Text('Web 模式预览不可用（Windows 版本支持视频预览）',
                    style:
                        TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoInfo() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 8),
            Text(widget.video.fileName,
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(
                '${widget.video.formattedDuration} · ${widget.video.formattedSize}',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
