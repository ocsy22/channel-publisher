import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/video_detail_panel.dart';
import '../widgets/video_preview_widget.dart';

class VideoLibraryScreen extends StatefulWidget {
  const VideoLibraryScreen({super.key});

  @override
  State<VideoLibraryScreen> createState() => _VideoLibraryScreenState();
}

class _VideoLibraryScreenState extends State<VideoLibraryScreen> {
  bool _showPreview = false; // 是否显示视频预览面板

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Row(
          children: [
            // 左侧文件列表
            Container(
              width: 300,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AppTheme.border)),
              ),
              child: _VideoListPanel(
                provider: provider,
                showPreview: _showPreview,
                onTogglePreview: () =>
                    setState(() => _showPreview = !_showPreview),
              ),
            ),
            // 右侧：视频预览 + 详情
            Expanded(
              child: provider.selectedVideo != null
                  ? Column(
                      children: [
                        // 视频预览区（可展开/收起）
                        if (_showPreview)
                          Container(
                            height: 220,
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: AppTheme.border)),
                            ),
                            child: VideoPreviewWidget(
                              video: provider.selectedVideo!,
                            ),
                          ),
                        // 详情面板
                        Expanded(
                          child:
                              VideoDetailPanel(video: provider.selectedVideo!),
                        ),
                      ],
                    )
                  : _EmptyDetailPanel(
                      onAddVideo: () async {
                        final result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.video,
                          allowMultiple: true,
                          withData: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          provider.addVideosFromPicker(result.files);
                        }
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _VideoListPanel extends StatelessWidget {
  final AppProvider provider;
  final bool showPreview;
  final VoidCallback onTogglePreview;

  const _VideoListPanel({
    required this.provider,
    required this.showPreview,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 工具栏
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.video,
                          allowMultiple: true,
                          withData: false,
                          withReadStream: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          provider.addVideosFromPicker(result.files);
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('添加视频'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result =
                          await FilePicker.platform.getDirectoryPath();
                      if (result != null) {
                        await provider.scanFolder(result);
                      }
                    },
                    icon: const Icon(Icons.folder_open_rounded, size: 16),
                    label: const Text('文件夹'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (provider.videos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('${provider.videos.length} 个视频',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary)),
                    const Spacer(),
                    // 预览切换按钮
                    IconButton(
                      onPressed: onTogglePreview,
                      icon: Icon(
                        showPreview
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 16,
                        color: showPreview
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                      ),
                      tooltip: showPreview ? '隐藏预览' : '显示预览',
                      style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(4)),
                    ),
                    TextButton(
                      onPressed: () => provider.processAllPending(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('全部处理',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // 视频列表
        Expanded(
          child: provider.videos.isEmpty
              ? _emptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: provider.videos.length,
                  itemBuilder: (context, i) {
                    final video = provider.videos[i];
                    return _VideoListItem(
                      video: video,
                      isSelected:
                          provider.selectedVideo?.id == video.id,
                      onTap: () => provider.selectVideo(video),
                      onProcess: () => provider.processVideo(video),
                      onDelete: () => provider.removeVideo(video.id),
                    );
                  },
                ),
        ),
        // 底部ffmpeg状态
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Icon(
                provider.ffmpegAvailable
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                size: 12,
                color: provider.ffmpegAvailable
                    ? AppTheme.success
                    : AppTheme.warning,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  provider.ffmpegAvailable
                      ? 'ffmpeg 已就绪'
                      : '⚠️ 请安装 ffmpeg（下载后放到exe同目录）',
                  style: TextStyle(
                    fontSize: 10,
                    color: provider.ffmpegAvailable
                        ? AppTheme.success
                        : AppTheme.warning,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 56,
              color: AppTheme.textHint.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          const Text('暂无视频文件',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('点击"添加视频"或选择文件夹',
              style:
                  TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _VideoListItem extends StatelessWidget {
  final VideoFile video;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onProcess;
  final VoidCallback onDelete;

  const _VideoListItem({
    required this.video,
    required this.isSelected,
    required this.onTap,
    required this.onProcess,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.bgSelected : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.video_file_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.fileName,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${video.formattedDuration} · ${video.formattedSize}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: video.status),
              ],
            ),
            if (video.status == VideoStatus.processing) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: video.progress,
                backgroundColor: AppTheme.bgPage,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primary),
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 2),
              Text(
                '处理中 ${(video.progress * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
            if (video.errorMessage != null &&
                video.errorMessage!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                video.errorMessage!,
                style: const TextStyle(
                    fontSize: 10, color: Colors.red),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (video.slices.isNotEmpty) ...[
                  const Icon(Icons.content_cut_rounded,
                      size: 11, color: AppTheme.textHint),
                  const SizedBox(width: 4),
                  Text('${video.slices.length} 个片段',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint)),
                ],
                const Spacer(),
                if (video.status == VideoStatus.pending ||
                    video.status == VideoStatus.failed)
                  InkWell(
                    onTap: onProcess,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Text('处理',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onDelete,
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded,
                        size: 14, color: AppTheme.textHint),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final VideoStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.label,
        style: TextStyle(
            fontSize: 10,
            color: status.color,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EmptyDetailPanel extends StatelessWidget {
  final VoidCallback onAddVideo;

  const _EmptyDetailPanel({required this.onAddVideo});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 60,
              color: AppTheme.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('添加视频开始使用',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('支持 MP4 MKV AVI MOV 等常见格式',
              style:
                  TextStyle(color: AppTheme.textHint, fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddVideo,
            icon: const Icon(Icons.add_rounded),
            label: const Text('添加视频文件'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
