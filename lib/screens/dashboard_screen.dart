import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/status_badge.dart';
import '../widgets/stat_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(provider),
              const SizedBox(height: 20),
              _buildStatsRow(provider),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: _buildBotStatus(context, provider)),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: _buildQuickActions(context, provider)),
                ],
              ),
              const SizedBox(height: 20),
              _buildRecentActivity(provider),
              const SizedBox(height: 20),
              _buildLogPanel(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AppProvider provider) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('仪表盘', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            Text(
              provider.watchFolder.isNotEmpty ? '监控: ${provider.watchFolder}' : '未设置监控文件夹',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
        const Spacer(),
        if (provider.botConfig.isConnected)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('Bot 已连接', style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('未连接', style: TextStyle(fontSize: 13, color: AppTheme.error, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow(AppProvider provider) {
    return Row(
      children: [
        Expanded(child: StatCard(label: '已发布', value: '${provider.totalPublished}', icon: Icons.send_rounded, color: AppTheme.primary)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: '处理中', value: '${provider.totalProcessing}', icon: Icons.sync_rounded, color: AppTheme.warning)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: '待处理', value: '${provider.totalPending}', icon: Icons.schedule_rounded, color: AppTheme.textHint)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: '已就绪', value: '${provider.totalReady}', icon: Icons.check_circle_outline_rounded, color: AppTheme.success)),
      ],
    );
  }

  Widget _buildBotStatus(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Telegram Bot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              StatusBadge(connected: provider.botConfig.isConnected),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          if (provider.botConfig.botToken.isNotEmpty) ...[
            _infoRow('Token', '${provider.botConfig.botToken.substring(0, min(12, provider.botConfig.botToken.length))}••••'),
            const SizedBox(height: 8),
            _infoRow('频道 ID', provider.botConfig.channelId.isNotEmpty ? provider.botConfig.channelId : '未设置'),
            const SizedBox(height: 8),
            _infoRow('频道名称', provider.botConfig.channelName.isNotEmpty ? provider.botConfig.channelName : '未设置'),
            const SizedBox(height: 8),
            _infoRow('发布间隔', '${provider.botConfig.publishInterval} 秒'),
            const SizedBox(height: 8),
            _infoRow('AI 模型', provider.botConfig.aiModel ?? 'GPT-3.5'),
          ] else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Icon(Icons.settings_suggest_rounded, size: 40, color: AppTheme.textHint.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                    const Text('请先配置 Bot Token', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: provider.isConnecting ? null : () => provider.testBotConnection(),
              icon: provider.isConnecting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link_rounded, size: 18),
              label: Text(provider.isConnecting ? '连接中...' : '测试连接'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('快捷操作', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          _actionBtn(
            icon: Icons.play_arrow_rounded,
            label: '处理所有待处理视频',
            color: AppTheme.primary,
            onTap: () => provider.processAllPending(),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            icon: Icons.send_rounded,
            label: '发布所有已就绪视频',
            color: AppTheme.success,
            onTap: () => provider.publishAllReady(),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            icon: Icons.folder_open_rounded,
            label: '打开视频库',
            color: AppTheme.info,
            onTap: () => provider.setNav(1),
          ),
          const SizedBox(height: 8),
          _actionBtn(
            icon: Icons.settings_rounded,
            label: '配置设置',
            color: AppTheme.textSecondary,
            onTap: () => provider.setNav(4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(AppProvider provider) {
    final recent = provider.history.take(5).toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('最近发布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('暂无发布记录', style: TextStyle(color: AppTheme.textHint)),
            ))
          else
            ...recent.map((r) => _activityItem(r)),
        ],
      ),
    );
  }

  Widget _activityItem(PublishRecord r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.video_file_rounded, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${r.channelName} · ${_formatTime(r.publishedAt)}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.textHint),
              const SizedBox(width: 3),
              Text('${r.views}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel(AppProvider provider) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2533),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              const Text('系统日志', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const Spacer(),
              InkWell(
                onTap: provider.clearLog,
                child: const Text('清空', style: TextStyle(color: Colors.white38, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                provider.logOutput.isEmpty ? '系统已就绪...' : provider.logOutput,
                style: const TextStyle(color: Color(0xFF7EC8E3), fontSize: 11, fontFamily: 'Consolas'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      ],
    );
  }

  Widget _actionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5), size: 18),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  int min(int a, int b) => a < b ? a : b;
}
