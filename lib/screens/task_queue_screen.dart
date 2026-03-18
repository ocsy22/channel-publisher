import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';

class TaskQueueScreen extends StatelessWidget {
  const TaskQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            // 顶部栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppTheme.bgCard,
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Row(
                children: [
                  const Text('任务队列', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${provider.tasks.length}', style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  Text('进行中: ${provider.tasks.where((t) => t.status == TaskStatus.running).length}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(width: 16),
                  Text('完成: ${provider.tasks.where((t) => t.status == TaskStatus.done).length}', style: const TextStyle(fontSize: 13, color: AppTheme.success)),
                ],
              ),
            ),
            // 任务列表
            Expanded(
              child: provider.tasks.isEmpty
                  ? _emptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: provider.tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _TaskCard(task: provider.tasks[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.task_alt_rounded, size: 60, color: AppTheme.textHint.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          const Text('暂无任务', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('开始处理视频后，任务将显示在这里', style: TextStyle(color: AppTheme.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final PublishTask task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task.videoFileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(task.message, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              _StatusBadge(status: task.status),
            ],
          ),
          if (task.status == TaskStatus.running) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: AppTheme.bgPage,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 4),
            Text('${(task.progress * 100).toInt()}%', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppTheme.textHint),
              const SizedBox(width: 4),
              Text(_formatTime(task.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              if (task.completedAt != null) ...[
                const SizedBox(width: 12),
                const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Text(_formatTime(task.completedAt!), style: const TextStyle(fontSize: 11, color: AppTheme.success)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeIcon() {
    final icons = {
      TaskType.slice: Icons.content_cut_rounded,
      TaskType.cover: Icons.image_rounded,
      TaskType.caption: Icons.text_fields_rounded,
      TaskType.publish: Icons.send_rounded,
    };
    final colors = {
      TaskType.slice: AppTheme.info,
      TaskType.cover: AppTheme.warning,
      TaskType.caption: const Color(0xFF9C27B0),
      TaskType.publish: AppTheme.primary,
    };
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: (colors[task.type] ?? AppTheme.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icons[task.type] ?? Icons.task_rounded, color: colors[task.type] ?? AppTheme.primary, size: 18),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

class _StatusBadge extends StatelessWidget {
  final TaskStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TaskStatus.running)
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: status.color),
            )
          else
            Container(width: 6, height: 6, decoration: BoxDecoration(color: status.color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(status.label, style: TextStyle(fontSize: 11, color: status.color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
