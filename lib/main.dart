import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'models/app_models.dart';
import 'utils/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/video_library_screen.dart';
import 'screens/task_queue_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const ChannelPublisherApp(),
    ),
  );
}

class ChannelPublisherApp extends StatelessWidget {
  const ChannelPublisherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Channel Publisher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          body: Row(
            children: [
              // 左侧导航栏
              _SideNav(selectedIndex: provider.selectedNav, onNavTap: provider.setNav),
              // 分割线
              Container(width: 1, color: AppTheme.border),
              // 主内容区
              Expanded(
                child: Column(
                  children: [
                    // 顶部栏
                    _TopBar(),
                    // 页面内容
                    Expanded(
                      child: _pageContent(provider.selectedNav),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pageContent(int index) {
    switch (index) {
      case 0: return const DashboardScreen();
      case 1: return const VideoLibraryScreen();
      case 2: return const TaskQueueScreen();
      case 3: return const HistoryScreen();
      case 4: return const SettingsScreen();
      default: return const DashboardScreen();
    }
  }
}

// ==================== 左侧导航 ====================
class _SideNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onNavTap;

  const _SideNav({required this.selectedIndex, required this.onNavTap});

  static const _items = [
    (icon: Icons.dashboard_rounded, label: '仪表盘'),
    (icon: Icons.video_library_rounded, label: '视频库'),
    (icon: Icons.queue_play_next_rounded, label: '任务队列'),
    (icon: Icons.history_rounded, label: '发布历史'),
    (icon: Icons.settings_rounded, label: '设置'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: AppTheme.bgSidebar,
      child: Column(
        children: [
          // Logo 区域
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primary, AppTheme.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Channel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.1)),
                    Text('Publisher', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600, height: 1.1)),
                  ],
                ),
              ],
            ),
          ),
          // 导航项
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Column(
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final isSelected = selectedIndex == i;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: _NavItem(
                      icon: item.icon,
                      label: item.label,
                      isSelected: isSelected,
                      onTap: () => onNavTap(i),
                      badgeCount: i == 2
                          ? Provider.of<AppProvider>(context).tasks.where((t) => t.status == TaskStatus.running).length
                          : 0,
                    ),
                  );
                }),
              ),
            ),
          ),
          // 底部版本号
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.border)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.telegram, size: 12, color: AppTheme.textHint),
                SizedBox(width: 4),
                Text('v1.0.0', style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? AppTheme.primary.withValues(alpha: 0.1)
                : _hovered
                    ? AppTheme.bgHover
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: widget.isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                ),
              ),
              if (widget.badgeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${widget.badgeCount}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              if (widget.isSelected)
                Container(
                  width: 3, height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== 顶部栏 ====================
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final titles = ['仪表盘', '视频库', '任务队列', '发布历史', '设置'];
    final subtitles = [
      '查看整体概览和快捷操作',
      '管理视频文件，切片处理和文案编辑',
      '查看当前处理和发布任务进度',
      '已发布内容的历史记录',
      '配置 Telegram Bot 和 AI 文案',
    ];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titles[provider.selectedNav], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              Text(subtitles[provider.selectedNav], style: const TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ],
          ),
          const Spacer(),
          // 快捷操作
          if (provider.selectedNav == 1)
            ElevatedButton.icon(
              onPressed: () => provider.processAllPending(),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
              label: const Text('处理全部', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
            ),
          if (provider.selectedNav == 1) const SizedBox(width: 8),
          if (provider.selectedNav == 1)
            ElevatedButton.icon(
              onPressed: provider.botConfig.isConnected ? () => provider.publishAllReady() : null,
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('发布全部', style: TextStyle(fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          const SizedBox(width: 16),
          // Bot 状态指示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: provider.botConfig.isConnected
                  ? AppTheme.success.withValues(alpha: 0.08)
                  : AppTheme.bgPage,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: provider.botConfig.isConnected
                    ? AppTheme.success.withValues(alpha: 0.3)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 7, height: 7,
                  decoration: BoxDecoration(
                    color: provider.botConfig.isConnected ? AppTheme.success : AppTheme.textHint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  provider.botConfig.isConnected ? 'Bot 已连接' : 'Bot 未连接',
                  style: TextStyle(
                    fontSize: 12,
                    color: provider.botConfig.isConnected ? AppTheme.success : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
