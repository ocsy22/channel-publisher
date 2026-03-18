import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../utils/app_theme.dart';
import '../models/app_models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _tokenCtrl;
  late TextEditingController _channelIdCtrl;
  late TextEditingController _channelNameCtrl;
  late TextEditingController _aiKeyCtrl;
  bool _showToken = false;
  bool _showAiKey = false;
  int _publishInterval = 30;
  bool _autoPublish = false;
  String _aiModel = 'gpt-3.5-turbo';

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppProvider>(context, listen: false).botConfig;
    _tokenCtrl = TextEditingController(text: config.botToken);
    _channelIdCtrl = TextEditingController(text: config.channelId);
    _channelNameCtrl = TextEditingController(text: config.channelName);
    _aiKeyCtrl = TextEditingController(text: config.aiApiKey ?? '');
    _publishInterval = config.publishInterval;
    _autoPublish = config.autoPublish;
    _aiModel = config.aiModel ?? 'gpt-3.5-turbo';
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _channelIdCtrl.dispose();
    _channelNameCtrl.dispose();
    _aiKeyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.updateBotConfig(BotConfig(
      botToken: _tokenCtrl.text.trim(),
      channelId: _channelIdCtrl.text.trim(),
      channelName: _channelNameCtrl.text.trim(),
      isConnected: provider.botConfig.isConnected,
      aiApiKey: _aiKeyCtrl.text.trim(),
      aiModel: _aiModel,
      publishInterval: _publishInterval,
      autoPublish: _autoPublish,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('设置已保存'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        width: 200,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
            children: [
              const Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('保存设置'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Telegram Bot 配置
          _sectionTitle('Telegram Bot 配置', Icons.smart_toy_rounded, AppTheme.primary),
          _card(Column(
            children: [
              _fieldRow('Bot Token', _tokenCtrl, hint: '1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi',
                  obscure: !_showToken,
                  suffix: IconButton(icon: Icon(_showToken ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppTheme.textHint), onPressed: () => setState(() => _showToken = !_showToken))),
              const SizedBox(height: 12),
              _fieldRow('频道 ID', _channelIdCtrl, hint: '@your_channel 或 -100123456789'),
              const SizedBox(height: 12),
              _fieldRow('频道名称', _channelNameCtrl, hint: '例如：我的精彩频道（可选，仅用于显示）'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => provider.testBotConnection(),
                      icon: provider.isConnecting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_rounded, size: 16),
                      label: Text(provider.isConnecting ? '连接中...' : '测试连接'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (provider.botConfig.isConnected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success),
                          SizedBox(width: 6),
                          Text('连接成功', style: TextStyle(fontSize: 13, color: AppTheme.success, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgPage,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('如何获取 Bot Token', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    const Text('1. 在 Telegram 中搜索 @BotFather\n2. 发送 /newbot 创建新机器人\n3. 按提示设置名称，获得 Token\n4. 将 Bot 添加为频道管理员（可发布消息）', style: TextStyle(fontSize: 12, color: AppTheme.textHint, height: 1.6)),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 20),

          // AI 配置
          _sectionTitle('AI 文案配置', Icons.auto_awesome_rounded, const Color(0xFF9C27B0)),
          _card(Column(
            children: [
              _fieldRow('OpenAI API Key', _aiKeyCtrl, hint: 'sk-...',
                  obscure: !_showAiKey,
                  suffix: IconButton(icon: Icon(_showAiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18, color: AppTheme.textHint), onPressed: () => setState(() => _showAiKey = !_showAiKey))),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('AI 模型', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _aiModel,
                    underline: const SizedBox(),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                    items: const [
                      DropdownMenuItem(value: 'gpt-3.5-turbo', child: Text('GPT-3.5 Turbo')),
                      DropdownMenuItem(value: 'gpt-4', child: Text('GPT-4')),
                      DropdownMenuItem(value: 'gpt-4-turbo', child: Text('GPT-4 Turbo')),
                      DropdownMenuItem(value: 'gpt-4o', child: Text('GPT-4o')),
                    ],
                    onChanged: (v) => setState(() { if (v != null) _aiModel = v; }),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppTheme.bgPage, borderRadius: BorderRadius.circular(8)),
                child: const Text('AI 密钥用于自动生成视频标题和文案描述。支持 OpenAI 兼容 API，无需配置也可手动编辑文案。', style: TextStyle(fontSize: 12, color: AppTheme.textHint, height: 1.5)),
              ),
            ],
          )),
          const SizedBox(height: 20),

          // 发布设置
          _sectionTitle('自动发布设置', Icons.schedule_send_rounded, AppTheme.warning),
          _card(Column(
            children: [
              Row(
                children: [
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('自动发布', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                      Text('处理完成后自动发布到频道', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ],
                  )),
                  Switch(value: _autoPublish, onChanged: (v) => setState(() => _autoPublish = v), activeTrackColor: AppTheme.primaryLight, thumbColor: WidgetStatePropertyAll(AppTheme.primary)),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('发布间隔', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
                      Text('每两条消息之间的等待时间', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                    ],
                  )),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      value: _publishInterval.toDouble(),
                      min: 5, max: 300, divisions: 59,
                      label: '${_publishInterval}s',
                      onChanged: (v) => setState(() => _publishInterval = v.toInt()),
                    ),
                  ),
                  SizedBox(width: 50, child: Text('$_publishInterval 秒', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                ],
              ),
            ],
          )),
          const SizedBox(height: 20),

          // 关于
          _sectionTitle('关于', Icons.info_outline_rounded, AppTheme.textHint),
          _card(Column(
            children: [
              _infoRow('版本', 'v1.0.0'),
              const Divider(),
              _infoRow('作者', 'Channel Publisher'),
              const Divider(),
              _infoRow('功能', '视频切片 · 封面生成 · AI文案 · Telegram发布'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppTheme.primary.withValues(alpha: 0.08), AppTheme.primaryLight.withValues(alpha: 0.04)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.telegram, color: AppTheme.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('本工具帮助您自动化管理 Telegram 频道内容，包括视频切片处理、AI智能文案生成和定时发布。',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
                    ),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _card(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }

  Widget _fieldRow(String label, TextEditingController ctrl, {String? hint, bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textHint))),
          Text(value, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
