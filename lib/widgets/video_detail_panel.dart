import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';

class VideoDetailPanel extends StatefulWidget {
  final VideoFile video;
  const VideoDetailPanel({super.key, required this.video});

  @override
  State<VideoDetailPanel> createState() => _VideoDetailPanelState();
}

class _VideoDetailPanelState extends State<VideoDetailPanel> with SingleTickerProviderStateMixin {
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
      _selectedSlice = widget.video.slices.isNotEmpty ? widget.video.slices.first : null;
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
                width: 40, height: 40,
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
                    Text(video.fileName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    Text('${video.formattedDuration} · ${video.formattedSize} · ${video.slices.length} 个片段',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 操作按钮
              if (video.status == VideoStatus.pending || video.status == VideoStatus.failed)
                ElevatedButton.icon(
                  onPressed: () => provider.processVideo(video),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: const Text('开始处理'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              if (video.status == VideoStatus.ready) ...[
                ElevatedButton.icon(
                  onPressed: () => provider.publishAllReady(),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('发布全部'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
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
              Tab(text: '发布设置'),
            ],
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              _SlicesTab(video: video, selectedSlice: _selectedSlice, onSliceSelected: (s) => setState(() => _selectedSlice = s)),
              _SliceConfigTab(video: video),
              _PublishSettingsTab(video: video),
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

  const _SlicesTab({required this.video, this.selectedSlice, required this.onSliceSelected});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    if (video.slices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.content_cut_rounded, size: 50, color: AppTheme.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            const Text('尚未切片', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => provider.processVideo(video),
              child: const Text('开始处理'),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // 片段列表
        SizedBox(
          width: 280,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
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
                    color: isSelected ? AppTheme.bgSelected : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected ? Border.all(color: AppTheme.primary.withValues(alpha: 0.3)) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50, height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text('P${i + 1}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slice.title ?? '片段 ${i + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${_formatTime(slice.startTime)} → ${_formatTime(slice.endTime)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: slice.status.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(slice.status.label, style: TextStyle(fontSize: 9, color: slice.status.color, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // 垂直分割线
        Container(width: 1, color: AppTheme.border),
        // 片段详情编辑
        Expanded(
          child: selectedSlice != null
              ? _SliceEditPanel(slice: selectedSlice!, video: video)
              : const Center(child: Text('选择左侧片段编辑', style: TextStyle(color: AppTheme.textHint))),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面预览
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120, height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, color: AppTheme.primary, size: 28),
                    SizedBox(height: 4),
                    Text('封面', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('文件名', slice.fileName),
                    _infoRow('时长', '${(slice.duration).toStringAsFixed(0)} 秒'),
                    _infoRow('时间段', '${_fmt(slice.startTime)} → ${_fmt(slice.endTime)}'),
                    _infoRow('状态', slice.status.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 标题
          Row(
            children: [
              const Text('标题', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await provider.regenerateTitle(slice);
                  _titleCtrl.text = slice.title ?? '';
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('AI 生成', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          // 文案
          Row(
            children: [
              const Text('文案描述', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await provider.regenerateCaption(slice);
                  _captionCtrl.text = slice.caption ?? '';
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                label: const Text('AI 重新生成', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            maxLines: 5,
            decoration: const InputDecoration(hintText: '输入频道文案...', alignLabelWithHint: true),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 20),
          // 发布按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (slice.status == VideoStatus.ready || slice.status == VideoStatus.failed)
                  ? () => provider.publishSlice(slice, widget.video)
                  : null,
              icon: slice.status == VideoStatus.publishing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(slice.status == VideoStatus.published ? '已发布' : slice.status == VideoStatus.publishing ? '发布中...' : '发布到 Telegram'),
              style: ElevatedButton.styleFrom(
                backgroundColor: slice.status == VideoStatus.published ? AppTheme.success : AppTheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (slice.publishedAt != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '已于 ${_fmtDate(slice.publishedAt!)} 发布',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textHint))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w500))),
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
          _sectionTitle('切片设置'),
          _card(Column(
            children: [
              _switchRow('自动切片', _config.autoSlice, (v) => setState(() { _config.autoSlice = v; _save(provider); })),
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('每片时长（秒）', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
                    SizedBox(
                      width: 120,
                      child: Slider(
                        value: _config.sliceDuration.clamp(10, 300),
                        min: 10, max: 300, divisions: 29,
                        label: '${_config.sliceDuration.toInt()}s',
                        onChanged: (v) => setState(() { _config.sliceDuration = v; _save(provider); }),
                      ),
                    ),
                    SizedBox(width: 48, child: Text('${_config.sliceDuration.toInt()} 秒', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 16),
          _sectionTitle('封面设置'),
          _card(Column(
            children: [
              _switchRow('自动生成封面', _config.generateCover, (v) => setState(() { _config.generateCover = v; _save(provider); })),
              const Divider(),
              Row(
                children: [
                  const Text('封面样式', style: TextStyle(fontSize: 13)),
                  const Spacer(),
                  DropdownButton<CoverStyle>(
                    value: _config.coverStyle,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(value: CoverStyle.firstFrame, child: Text('第一帧')),
                      DropdownMenuItem(value: CoverStyle.bestFrame, child: Text('最佳帧')),
                      DropdownMenuItem(value: CoverStyle.middleFrame, child: Text('中间帧')),
                    ],
                    onChanged: (v) => setState(() { if (v != null) { _config.coverStyle = v; _save(provider); } }),
                  ),
                ],
              ),
              const Divider(),
              _switchRow('添加水印', _config.addWatermark, (v) => setState(() { _config.addWatermark = v; _save(provider); })),
              if (_config.addWatermark) ...[
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(labelText: '水印文字', hintText: '例如：@my_channel'),
                  onChanged: (v) => setState(() { _config.watermarkText = v; _save(provider); }),
                  controller: TextEditingController(text: _config.watermarkText),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ],
          )),
          const SizedBox(height: 16),
          _sectionTitle('AI 文案设置'),
          _card(Column(
            children: [
              _switchRow('自动生成文案', _config.generateCaption, (v) => setState(() { _config.generateCaption = v; _save(provider); })),
              const Divider(),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(labelText: '文案生成提示词', hintText: '描述你想要的文案风格...'),
                maxLines: 3,
                onChanged: (v) => setState(() { _config.captionPrompt = v; _save(provider); }),
                controller: TextEditingController(text: _config.captionPrompt),
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
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
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
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary))),
        Switch(value: value, onChanged: onChanged, activeTrackColor: AppTheme.primaryLight, thumbColor: WidgetStatePropertyAll(AppTheme.primary)),
      ],
    );
  }

  void _save(AppProvider provider) {
    provider.updateSliceConfig(widget.video.id, _config);
  }
}

// ==================== 发布设置 Tab ====================
class _PublishSettingsTab extends StatelessWidget {
  final VideoFile video;
  const _PublishSettingsTab({required this.video});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final config = provider.botConfig;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: config.isConnected
                  ? AppTheme.success.withValues(alpha: 0.05)
                  : AppTheme.warning.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: config.isConnected
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  config.isConnected ? Icons.check_circle_rounded : Icons.warning_rounded,
                  color: config.isConnected ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.isConnected
                        ? '已连接到 ${config.channelName.isNotEmpty ? config.channelName : config.channelId}'
                        : '请先在设置页面配置并连接 Telegram Bot',
                    style: TextStyle(
                      fontSize: 13,
                      color: config.isConnected ? AppTheme.success : AppTheme.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (!config.isConnected)
                  TextButton(
                    onPressed: () => provider.setNav(4),
                    child: const Text('前往设置'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('发布统计', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                _statItem('总片段', '${video.slices.length}', AppTheme.primary),
                _divider(),
                _statItem('已就绪', '${video.slices.where((s) => s.status == VideoStatus.ready).length}', AppTheme.success),
                _divider(),
                _statItem('已发布', '${video.slices.where((s) => s.status == VideoStatus.published).length}', AppTheme.info),
                _divider(),
                _statItem('待处理', '${video.slices.where((s) => s.status == VideoStatus.pending).length}', AppTheme.textHint),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: config.isConnected ? () => provider.publishAllReady() : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('发布所有已就绪片段'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 40, color: AppTheme.border);
  }
}
