import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';
import '../services/caption_service.dart';

class VideoDetailPanel extends StatefulWidget {
  final VideoFile video;
  const VideoDetailPanel({super.key, required this.video});

  @override
  State<VideoDetailPanel> createState() => _VideoDetailPanelState();
}

class _VideoDetailPanelState extends State<VideoDetailPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  VideoSlice? _selectedSlice;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.video.slices.isNotEmpty) {
      _selectedSlice = widget.video.slices.first;
    }
  }

  @override
  void didUpdateWidget(VideoDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _selectedSlice =
          widget.video.slices.isNotEmpty ? widget.video.slices.first : null;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final video = widget.video;

    return Column(
      children: [
        // 顶部信息栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.movie_rounded, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(video.fileName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    Text(
                      '${video.formattedDuration} · ${video.formattedSize} · ${video.slices.length} 个片段',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (video.status == VideoStatus.pending ||
                  video.status == VideoStatus.failed)
                ElevatedButton.icon(
                  onPressed: () => provider.processVideo(video),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('开始处理'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              if (video.status == VideoStatus.processing)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary)),
                      const SizedBox(width: 8),
                      Text('${(video.progress * 100).toInt()}%',
                          style: const TextStyle(
                              fontSize: 13, color: AppTheme.primary)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Tab 栏
        Container(
          color: AppTheme.bgCard,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '片段列表'),
              Tab(text: '切片配置'),
              Tab(text: '多选发布'),
            ],
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
          ),
        ),
        // Tab 内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SlicesTab(
                  video: video,
                  selectedSlice: _selectedSlice,
                  onSliceSelected: (s) => setState(() => _selectedSlice = s)),
              _SliceConfigTab(video: video),
              _MultiPublishTab(video: video),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================== 片段列表 Tab ====================
class _SlicesTab extends StatelessWidget {
  final VideoFile video;
  final VideoSlice? selectedSlice;
  final ValueChanged<VideoSlice> onSliceSelected;

  const _SlicesTab(
      {required this.video,
      this.selectedSlice,
      required this.onSliceSelected});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    if (video.slices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut_rounded,
                size: 50,
                color: AppTheme.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('尚未切片',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            const Text('点击"开始处理"按钮切片视频',
                style: TextStyle(color: AppTheme.textHint, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => provider.processVideo(video),
              icon: const Icon(Icons.content_cut_rounded, size: 16),
              label: const Text('开始切片'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // 片段列表（左侧）
        SizedBox(
          width: 260,
          child: Column(
            children: [
              // 列表标题
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.border)),
                ),
                child: Row(
                  children: [
                    Text('${video.slices.length} 个片段',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(6),
                  itemCount: video.slices.length,
                  itemBuilder: (context, i) {
                    final slice = video.slices[i];
                    final isSelected = selectedSlice?.id == slice.id;
                    return InkWell(
                      onTap: () => onSliceSelected(slice),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.bgSelected
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(
                                  color:
                                      AppTheme.primary.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            // 封面缩略图
                            _CoverThumbnail(
                                coverPath: slice.coverPath, index: i),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slice.title ?? '片段 ${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${_formatTime(slice.startTime)} → ${_formatTime(slice.endTime)}',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    slice.status.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(slice.status.label,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: slice.status.color,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        // 片段详情编辑（右侧）
        Expanded(
          child: selectedSlice != null
              ? _SliceEditPanel(slice: selectedSlice!, video: video)
              : const Center(
                  child: Text('选择左侧片段编辑',
                      style: TextStyle(color: AppTheme.textHint))),
        ),
      ],
    );
  }

  String _formatTime(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// 封面缩略图组件
class _CoverThumbnail extends StatelessWidget {
  final String? coverPath;
  final int index;

  const _CoverThumbnail({this.coverPath, required this.index});

  @override
  Widget build(BuildContext context) {
    if (coverPath != null && coverPath!.isNotEmpty) {
      try {
        final file = File(coverPath!);
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(
            file,
            width: 50,
            height: 38,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          ),
        );
      } catch (_) {}
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 50,
      height: 38,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Text('P${index + 1}',
            style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }
}

// ==================== 片段编辑面板 ====================
class _SliceEditPanel extends StatefulWidget {
  final VideoSlice slice;
  final VideoFile video;
  const _SliceEditPanel({required this.slice, required this.video});

  @override
  State<_SliceEditPanel> createState() => _SliceEditPanelState();
}

class _SliceEditPanelState extends State<_SliceEditPanel> {
  late TextEditingController _titleCtrl;
  late TextEditingController _captionCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.slice.title ?? '');
    _captionCtrl = TextEditingController(text: widget.slice.caption ?? '');
  }

  @override
  void didUpdateWidget(_SliceEditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slice.id != widget.slice.id) {
      _titleCtrl.text = widget.slice.title ?? '';
      _captionCtrl.text = widget.slice.caption ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final slice = widget.slice;
    final isAdultMode =
        widget.video.sliceConfig.captionMode == CaptionMode.adult;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === 封面区域 ===
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 封面预览（可点击更换）
              GestureDetector(
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    allowMultiple: false,
                  );
                  if (result != null &&
                      result.files.isNotEmpty &&
                      result.files.first.path != null) {
                    provider.updateSliceCover(
                        slice.id, result.files.first.path!);
                    setState(() {});
                  }
                },
                child: Container(
                  width: 140,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: slice.coverPath != null && slice.coverPath!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.file(
                            File(slice.coverPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _coverPlaceholder(),
                          ),
                        )
                      : _coverPlaceholder(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('文件名', slice.fileName),
                    _infoRow('时长', '${slice.duration.toStringAsFixed(0)} 秒'),
                    _infoRow(
                        '时间', '${_fmt(slice.startTime)} → ${_fmt(slice.endTime)}'),
                    _infoRow('路径', slice.realPath ?? '等待处理'),
                    const SizedBox(height: 8),
                    // 成人模式切换按钮
                    InkWell(
                      onTap: () async {
                        await provider.toggleCaptionMode(slice);
                        setState(() {});
                        _titleCtrl.text = slice.title ?? '';
                        _captionCtrl.text = slice.caption ?? '';
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isAdultMode
                              ? Colors.red.withValues(alpha: 0.1)
                              : AppTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isAdultMode
                                ? Colors.red.withValues(alpha: 0.4)
                                : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isAdultMode ? '🔞 成人模式' : '😊 普通模式',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isAdultMode ? Colors.red : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.swap_horiz_rounded,
                                size: 14,
                                color: isAdultMode
                                    ? Colors.red
                                    : AppTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // === 标题 ===
          Row(
            children: [
              const Text('标题',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await provider.regenerateTitle(slice);
                  setState(() {
                    _titleCtrl.text = slice.title ?? '';
                  });
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('AI 生成', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _titleCtrl,
            onChanged: (v) => provider.updateSliceTitle(slice.id, v),
            decoration: const InputDecoration(hintText: '输入标题...'),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),

          // === 文案描述 ===
          Row(
            children: [
              const Text('文案描述',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              if (isAdultMode)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('🔞',
                      style: TextStyle(fontSize: 11)),
                ),
              TextButton.icon(
                onPressed: () async {
                  await provider.regenerateCaption(slice);
                  setState(() {
                    _captionCtrl.text = slice.caption ?? '';
                  });
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('AI 重新生成',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _captionCtrl,
            onChanged: (v) => provider.updateSliceCaption(slice.id, v),
            maxLines: 6,
            decoration: const InputDecoration(
                hintText: '输入频道文案...', alignLabelWithHint: true),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),

          // === 发布按钮 ===
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (slice.status == VideoStatus.ready ||
                      slice.status == VideoStatus.failed)
                  ? () {
                      if (!provider.botConfig.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('⚠️ 请先在设置页面连接 Telegram Bot'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      if (slice.realPath == null || slice.realPath!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('❌ 视频文件路径为空，请先切片处理'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      provider.publishSlice(slice, widget.video);
                    }
                  : null,
              icon: slice.status == VideoStatus.publishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(slice.status == VideoStatus.published
                  ? '✅ 已发布'
                  : slice.status == VideoStatus.publishing
                      ? '发布中...'
                      : slice.status == VideoStatus.failed
                          ? '重新发布'
                          : '发布到 Telegram'),
              style: ElevatedButton.styleFrom(
                backgroundColor: slice.status == VideoStatus.published
                    ? AppTheme.success
                    : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          if (slice.errorMessage != null && slice.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border:
                    Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 14, color: Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(slice.errorMessage!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.red))),
                ],
              ),
            ),
          ],

          if (slice.publishedAt != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '已于 ${_fmtDate(slice.publishedAt!)} 发布',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined,
            color: AppTheme.primary, size: 28),
        SizedBox(height: 4),
        Text('点击更换封面',
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 44,
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textHint))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2)),
        ],
      ),
    );
  }

  String _fmt(double s) {
    final m = s ~/ 60;
    final sec = (s % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== 切片配置 Tab ====================
class _SliceConfigTab extends StatefulWidget {
  final VideoFile video;
  const _SliceConfigTab({required this.video});

  @override
  State<_SliceConfigTab> createState() => _SliceConfigTabState();
}

class _SliceConfigTabState extends State<_SliceConfigTab> {
  late SliceConfig _config;

  @override
  void initState() {
    super.initState();
    _config = widget.video.sliceConfig;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 文案模式快速切换
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _config.captionMode == CaptionMode.adult
                  ? Colors.red.withValues(alpha: 0.05)
                  : AppTheme.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _config.captionMode == CaptionMode.adult
                    ? Colors.red.withValues(alpha: 0.3)
                    : AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _config.captionMode == CaptionMode.adult
                      ? Icons.eighteen_up_rating_rounded
                      : Icons.sentiment_satisfied_rounded,
                  color: _config.captionMode == CaptionMode.adult
                      ? Colors.red
                      : AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _config.captionMode == CaptionMode.adult
                            ? '🔞 成人内容模式'
                            : '😊 普通内容模式',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _config.captionMode == CaptionMode.adult
                              ? Colors.red
                              : AppTheme.primary,
                        ),
                      ),
                      Text(
                        _config.captionMode == CaptionMode.adult
                            ? 'AI 将生成18+暗示性标题和文案'
                            : 'AI 将生成普通吸引性标题和文案',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _config.captionMode == CaptionMode.adult,
                  onChanged: (v) => setState(() {
                    _config.captionMode =
                        v ? CaptionMode.adult : CaptionMode.normal;
                    _save(provider);
                  }),
                  activeThumbColor: Colors.red,
                  inactiveThumbColor: AppTheme.primary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionTitle('切片设置'),
          _card(Column(
            children: [
              _switchRow(
                  '自动切片',
                  _config.autoSlice,
                  (v) => setState(() {
                        _config.autoSlice = v;
                        _save(provider);
                      })),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Expanded(
                        child: Text('每片时长（秒）',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textPrimary))),
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: _config.sliceDuration.clamp(10, 300),
                        min: 10,
                        max: 300,
                        divisions: 29,
                        label: '${_config.sliceDuration.toInt()}s',
                        onChanged: (v) => setState(() {
                          _config.sliceDuration = v;
                          _save(provider);
                        }),
                      ),
                    ),
                    SizedBox(
                        width: 48,
                        child: Text('${_config.sliceDuration.toInt()} 秒',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),
          _sectionTitle('封面设置'),
          _card(Column(
            children: [
              _switchRow(
                  '自动生成封面',
                  _config.generateCover,
                  (v) => setState(() {
                        _config.generateCover = v;
                        _save(provider);
                      })),
              const Divider(),
              Row(
                children: [
                  const Text('封面样式',
                      style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  DropdownButton<CoverStyle>(
                    value: _config.coverStyle,
                    underline: const SizedBox(),
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(
                          value: CoverStyle.firstFrame,
                          child: Text('第一帧 (10%处)')),
                      DropdownMenuItem(
                          value: CoverStyle.bestFrame,
                          child: Text('最佳帧 (30%处)')),
                      DropdownMenuItem(
                          value: CoverStyle.middleFrame,
                          child: Text('中间帧 (50%处)')),
                    ],
                    onChanged: (v) => setState(() {
                      if (v != null) {
                        _config.coverStyle = v;
                        _save(provider);
                      }
                    }),
                  ),
                ],
              ),
              const Divider(),
              _switchRow(
                  '添加水印',
                  _config.addWatermark,
                  (v) => setState(() {
                        _config.addWatermark = v;
                        _save(provider);
                      })),
              if (_config.addWatermark) ...[
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                      labelText: '水印文字',
                      hintText: '例如：@my_channel'),
                  onChanged: (v) => setState(() {
                    _config.watermarkText = v;
                    _save(provider);
                  }),
                  controller:
                      TextEditingController(text: _config.watermarkText),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          )),
          const SizedBox(height: 16),
          _sectionTitle('AI 文案设置'),
          _card(Column(
            children: [
              _switchRow(
                  '自动生成文案',
                  _config.generateCaption,
                  (v) => setState(() {
                        _config.generateCaption = v;
                        _save(provider);
                      })),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                    labelText: '自定义提示词',
                    hintText: '留空使用默认模板，或输入自定义描述...'),
                maxLines: 3,
                onChanged: (v) => setState(() {
                  _config.captionPrompt = v;
                  _save(provider);
                }),
                controller:
                    TextEditingController(text: _config.captionPrompt),
                style: const TextStyle(fontSize: 13),
              ),
            ],
          )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.textPrimary))),
        Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.primaryLight,
            thumbColor: const WidgetStatePropertyAll(AppTheme.primary)),
      ],
    );
  }

  void _save(AppProvider provider) {
    provider.updateSliceConfig(widget.video.id, _config);
  }
}

// ==================== 多选发布 Tab ====================
class _MultiPublishTab extends StatefulWidget {
  final VideoFile video;
  const _MultiPublishTab({required this.video});

  @override
  State<_MultiPublishTab> createState() => _MultiPublishTabState();
}

class _MultiPublishTabState extends State<_MultiPublishTab> {
  String? _sharedCoverPath;
  bool _useMediaGroup = false;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final video = widget.video;
    final allSlices = video.slices;
    final selectedCount = allSlices
        .where((s) => provider.isSliceSelected(s.id))
        .length;

    return Column(
      children: [
        // 顶部控制栏
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text('已选 $selectedCount / ${allSlices.length} 个片段',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => provider.selectAllSlices(video),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4)),
                    child: const Text('全选', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => provider.clearSliceSelection(),
                    style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4)),
                    child: const Text('清空',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 共用封面选择
              Row(
                children: [
                  const Icon(Icons.image_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  const Text('共用封面',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary)),
                  const Spacer(),
                  if (_sharedCoverPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.file(
                        File(_sharedCoverPath!),
                        width: 40,
                        height: 30,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.image,
                        allowMultiple: false,
                      );
                      if (result != null &&
                          result.files.isNotEmpty &&
                          result.files.first.path != null) {
                        setState(
                            () => _sharedCoverPath = result.files.first.path!);
                      }
                    },
                    icon: const Icon(Icons.add_photo_alternate_rounded,
                        size: 14),
                    label: Text(_sharedCoverPath != null ? '更换封面' : '选择封面',
                        style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                  if (_sharedCoverPath != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sharedCoverPath = null),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      style: IconButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.all(4)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 媒体组发布选项
              Row(
                children: [
                  Checkbox(
                    value: _useMediaGroup,
                    onChanged: (v) =>
                        setState(() => _useMediaGroup = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('媒体组发布（≤10个）',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textPrimary)),
                        Text('一次发送多个视频为一组',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 片段列表（可多选）
        Expanded(
          child: allSlices.isEmpty
              ? const Center(
                  child: Text('暂无片段，请先切片处理',
                      style: TextStyle(color: AppTheme.textHint)))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: allSlices.length,
                  itemBuilder: (context, i) {
                    final slice = allSlices[i];
                    final isSelected = provider.isSliceSelected(slice.id);
                    return InkWell(
                      onTap: () => provider.toggleSliceSelection(slice.id),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.4)
                                : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) =>
                                  provider.toggleSliceSelection(slice.id),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              activeColor: AppTheme.primary,
                            ),
                            const SizedBox(width: 6),
                            _CoverThumbnail(
                                coverPath: slice.coverPath, index: i),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(slice.title ?? '片段 ${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  Text(
                                    slice.realPath ?? '等待处理',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: slice.status.color
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(slice.status.label,
                                  style: TextStyle(
                                      fontSize: 9,
                                      color: slice.status.color,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        // 底部发布按钮
        Container(
          padding: const EdgeInsets.all(14),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              if (!provider.botConfig.isConnected)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded,
                          size: 14, color: Colors.orange),
                      const SizedBox(width: 6),
                      const Expanded(
                          child: Text('请先在设置页面连接 Telegram Bot',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.orange))),
                      TextButton(
                        onPressed: () => provider.setNav(4),
                        style: TextButton.styleFrom(
                            minimumSize: Size.zero,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2)),
                        child: const Text('前往设置',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (selectedCount > 0 &&
                          provider.botConfig.isConnected)
                      ? () {
                          provider.publishSelectedSlices(
                            sharedCoverPath: _sharedCoverPath,
                            asMediaGroup: _useMediaGroup,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '📤 开始发布 $selectedCount 个片段...'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    selectedCount > 0
                        ? '发布选中的 $selectedCount 个片段'
                        : '请先选择要发布的片段',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
