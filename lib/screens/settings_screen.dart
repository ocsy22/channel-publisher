import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
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
  late TextEditingController _aiSecondaryKeyCtrl;
  late TextEditingController _outputDirCtrl;
  late TextEditingController _aiBaseUrlCtrl;
  late TextEditingController _tgChannelLinkCtrl;
  late TextEditingController _coverTextPresetCtrl;

  bool _showToken = false;
  bool _showAiKey = false;
  bool _showSecondaryKey = false;
  int _publishInterval = 30;
  bool _autoPublish = false;
  String _aiModel = '';
  bool _ignoreSslErrors = true;

  // AI 多服务商
  String _aiProvider = 'openai';

  // 文案格式配置
  String _captionFormat = 'standard';
  bool _enableEmoji = true;
  bool _enableTags = true;
  bool _enableTgQuote = false;
  bool _enableBoldTitle = true;
  int _captionMaxLength = 200;

  // 封面文字配置
  bool _enableCoverText = false;
  bool _aiGenerateCoverText = true;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppProvider>(context, listen: false).botConfig;
    _tokenCtrl = TextEditingController(text: config.botToken);
    _channelIdCtrl = TextEditingController(text: config.channelId);
    _channelNameCtrl = TextEditingController(text: config.channelName);
    _aiKeyCtrl = TextEditingController(text: config.aiApiKey ?? '');
    _aiSecondaryKeyCtrl = TextEditingController(text: config.aiSecondaryKey ?? '');
    _outputDirCtrl = TextEditingController(text: config.outputDir);
    _aiBaseUrlCtrl = TextEditingController(text: config.aiBaseUrl ?? '');
    _tgChannelLinkCtrl = TextEditingController(text: config.tgChannelLink);
    _coverTextPresetCtrl = TextEditingController(text: config.coverTextPreset);

    _publishInterval = config.publishInterval;
    _autoPublish = config.autoPublish;
    _aiProvider = config.aiProvider.isNotEmpty ? config.aiProvider : 'openai';
    _aiModel = config.aiModel ?? '';
    _ignoreSslErrors = config.ignoreSslErrors;

    _captionFormat = config.captionFormat.isNotEmpty ? config.captionFormat : 'standard';
    _enableEmoji = config.enableEmoji;
    _enableTags = config.enableTags;
    _enableTgQuote = config.enableTgQuote;
    _enableBoldTitle = config.enableBoldTitle;
    _captionMaxLength = config.captionMaxLength;

    _enableCoverText = config.enableCoverText;
    _aiGenerateCoverText = config.aiGenerateCoverText;
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    _channelIdCtrl.dispose();
    _channelNameCtrl.dispose();
    _aiKeyCtrl.dispose();
    _aiSecondaryKeyCtrl.dispose();
    _outputDirCtrl.dispose();
    _aiBaseUrlCtrl.dispose();
    _tgChannelLinkCtrl.dispose();
    _coverTextPresetCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    // 如果 model 为空则使用默认
    final effectiveModel = _aiModel.isNotEmpty ? _aiModel : _defaultModelForProvider(_aiProvider);
    provider.updateBotConfig(BotConfig(
      botToken: _tokenCtrl.text.trim(),
      channelId: _channelIdCtrl.text.trim(),
      channelName: _channelNameCtrl.text.trim(),
      isConnected: provider.botConfig.isConnected,
      aiProvider: _aiProvider,
      aiApiKey: _aiKeyCtrl.text.trim(),
      aiSecondaryKey: _aiSecondaryKeyCtrl.text.trim(),
      aiModel: effectiveModel,
      aiBaseUrl: _aiBaseUrlCtrl.text.trim(),
      publishInterval: _publishInterval,
      autoPublish: _autoPublish,
      ignoreSslErrors: _ignoreSslErrors,
      outputDir: _outputDirCtrl.text.trim(),
      captionFormat: _captionFormat,
      enableEmoji: _enableEmoji,
      enableTags: _enableTags,
      enableTgQuote: _enableTgQuote,
      tgChannelLink: _tgChannelLinkCtrl.text.trim(),
      enableBoldTitle: _enableBoldTitle,
      captionMaxLength: _captionMaxLength,
      enableCoverText: _enableCoverText,
      aiGenerateCoverText: _aiGenerateCoverText,
      coverTextPreset: _coverTextPresetCtrl.text.trim(),
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 设置已保存'),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        width: 200,
        duration: Duration(seconds: 2),
      ),
    );
  }

  String _defaultModelForProvider(String provider) {
    switch (provider) {
      case 'deepseek': return 'deepseek-chat';
      case 'qianwen':  return 'qwen-turbo';
      case 'zhipu':    return 'glm-4-flash';
      case 'moonshot': return 'moonshot-v1-8k';
      case 'custom':   return 'gpt-3.5-turbo';
      default:         return 'gpt-3.5-turbo';
    }
  }

  List<String> _modelsForProvider(String provider) {
    switch (provider) {
      case 'openai':   return ['gpt-3.5-turbo', 'gpt-4', 'gpt-4-turbo', 'gpt-4o', 'gpt-4o-mini'];
      case 'deepseek': return ['deepseek-chat', 'deepseek-coder', 'deepseek-reasoner'];
      case 'qianwen':  return ['qwen-turbo', 'qwen-plus', 'qwen-max', 'qwen-long'];
      case 'zhipu':    return ['glm-4-flash', 'glm-4', 'glm-4-air', 'glm-4-airx'];
      case 'moonshot': return ['moonshot-v1-8k', 'moonshot-v1-32k', 'moonshot-v1-128k'];
      case 'custom':   return [];
      default:         return ['gpt-3.5-turbo'];
    }
  }

  Future<void> _pickOutputDir() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择视频切片输出目录',
      );
      if (result != null) {
        setState(() {
          _outputDirCtrl.text = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              const Text('设置',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('保存设置'),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ==================== Telegram Bot 配置 ====================
          _sectionTitle('Telegram Bot 配置', Icons.smart_toy_rounded, AppTheme.primary),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fieldRow('Bot Token', _tokenCtrl,
                  hint: '1234567890:ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghi',
                  obscure: !_showToken,
                  suffix: IconButton(
                      icon: Icon(
                          _showToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18, color: AppTheme.textHint),
                      onPressed: () => setState(() => _showToken = !_showToken))),
              const SizedBox(height: 12),
              _fieldRow('频道 ID', _channelIdCtrl,
                  hint: '@your_channel 或 -100123456789'),
              const SizedBox(height: 12),
              _fieldRow('频道名称', _channelNameCtrl,
                  hint: '例如：我的精彩频道（可选，仅用于显示）'),
              const SizedBox(height: 12),

              // SSL忽略开关
              _sslToggle(),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _save();
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) provider.testBotConnection();
                        });
                      },
                      icon: provider.isConnecting
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.link_rounded, size: 16),
                      label: Text(provider.isConnecting ? '连接中...' : '测试Bot连接'),
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
                          Text('连接成功',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.success,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
              if (provider.botConfig.isConnected) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await provider.sendTestMessage();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok
                              ? '✅ 测试消息发送成功！请查看你的频道'
                              : '❌ 测试消息发送失败，请查看日志'),
                          backgroundColor: ok ? AppTheme.success : Colors.red,
                        ));
                      }
                    },
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('发送测试消息到频道'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _helpBox(
                '如何获取 Bot Token',
                '1. 在 Telegram 中搜索 @BotFather\n'
                '2. 发送 /newbot 创建新机器人\n'
                '3. 按提示设置名称，获得 Token\n'
                '4. 将 Bot 添加为频道管理员（需开启"发布消息"权限）\n'
                '5. 频道ID格式：@channelname 或数字 -100xxxxxxxxx',
              ),
            ],
          )),
          const SizedBox(height: 20),

          // ==================== 视频输出目录 ====================
          _sectionTitle('视频输出目录', Icons.folder_rounded, const Color(0xFF4CAF50)),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _outputDirCtrl,
                      decoration: const InputDecoration(
                        hintText: '留空则使用系统默认目录（避免C盘）',
                        hintStyle: TextStyle(fontSize: 12, color: AppTheme.textHint),
                        prefixIcon: Icon(Icons.folder_outlined, size: 18, color: AppTheme.textHint),
                      ),
                      style: const TextStyle(fontSize: 13),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: _pickOutputDir,
                    icon: const Icon(Icons.drive_folder_upload_rounded, size: 16),
                    label: const Text('选择目录'),
                  ),
                  if (_outputDirCtrl.text.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _outputDirCtrl.text = ''),
                      icon: const Icon(Icons.clear_rounded, size: 16, color: AppTheme.textHint),
                      tooltip: '清除（恢复默认）',
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _tipBox(
                const Color(0xFF4CAF50),
                '切片文件、封面图片将保存到此目录。建议选择空间充足的非C盘目录（如 D:\\VideoSlices）。'
                '留空时程序会自动选择系统文档目录下的 ChannelPublisher 文件夹。',
              ),
            ],
          )),
          const SizedBox(height: 20),

          // ==================== AI 文案配置 ====================
          _sectionTitle('AI 文案配置', Icons.auto_awesome_rounded, const Color(0xFF9C27B0)),
          _card(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI 服务商选择
              _subTitle('选择 AI 服务商'),
              const SizedBox(height: 8),
              _aiProviderSelector(),
              const SizedBox(height: 16),

              // API Key
              _fieldRow(
                _aiProvider == 'custom' ? '自定义 API Key' : 'API Key',
                _aiKeyCtrl,
                hint: _getApiKeyHint(_aiProvider),
                obscure: !_showAiKey,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                          _showAiKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18, color: AppTheme.textHint),
                      onPressed: () => setState(() => _showAiKey = !_showAiKey)),
                    TextButton(
                      onPressed: _save,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('保存', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // 备用 Key（可选）
              _fieldRow('备用 API Key（可选）', _aiSecondaryKeyCtrl,
                  hint: '配置后主Key失效时自动切换',
                  obscure: !_showSecondaryKey,
                  suffix: IconButton(
                      icon: Icon(
                          _showSecondaryKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          size: 18, color: AppTheme.textHint),
                      onPressed: () => setState(() => _showSecondaryKey = !_showSecondaryKey))),
              const SizedBox(height: 12),

              // 自定义 API 地址（仅 custom 模式）
              if (_aiProvider == 'custom') ...[
                _fieldRow('API Base URL', _aiBaseUrlCtrl,
                    hint: 'https://your-api.com/v1'),
                const SizedBox(height: 12),
              ],

              // AI 模型选择
              _subTitle('AI 模型'),
              const SizedBox(height: 6),
              _modelSelector(),
              const SizedBox(height: 16),

              // AI 服务商说明
              _aiProviderHelpBox(),
            ],
          )),
          const SizedBox(height: 20),

          // ==================== 文案格式配置 ====================
          _sectionTitle('文案格式配置', Icons.text_fields_rounded, const Color(0xFF2196F3)),
          _card(Column(
            children: [
              // 表情开关
              _switchRowWithDesc(
                '发布内容加表情 🎭',
                '在标题和文案中添加 emoji 表情符号',
                _enableEmoji,
                (v) => setState(() => _enableEmoji = v),
                activeColor: Colors.amber,
              ),
              const Divider(),

              // 标签开关
              _switchRowWithDesc(
                '发布内容加标签 #Tag',
                '自动在内容末尾添加 hashtag 标签',
                _enableTags,
                (v) => setState(() => _enableTags = v),
              ),
              const Divider(),

              // 标题加粗
              _switchRowWithDesc(
                '标题加粗显示',
                '在 Telegram 中用 <b></b> 加粗标题',
                _enableBoldTitle,
                (v) => setState(() => _enableBoldTitle = v),
              ),
              const Divider(),

              // 频道链接引用
              _switchRowWithDesc(
                '添加频道链接',
                '在内容末尾附上你的频道 @链接',
                _enableTgQuote,
                (v) => setState(() => _enableTgQuote = v),
              ),
              if (_enableTgQuote) ...[
                const SizedBox(height: 8),
                _fieldRow('频道链接', _tgChannelLinkCtrl,
                    hint: '@your_channel'),
              ],
              const Divider(),

              // 文案字数限制
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('文案最大字数',
                              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          Text('描述文案的字数上限（不含标题和标签）',
                              style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: Slider(
                        value: _captionMaxLength.toDouble().clamp(50, 500),
                        min: 50,
                        max: 500,
                        divisions: 45,
                        label: '$_captionMaxLength 字',
                        onChanged: (v) => setState(() => _captionMaxLength = v.toInt()),
                        activeColor: const Color(0xFF2196F3),
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text('$_captionMaxLength 字',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
              ),
              const Divider(),

              // 文案格式
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('文案格式',
                              style: TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500)),
                          Text('控制生成文案的详细程度',
                              style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: _captionFormat,
                      underline: const SizedBox(),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                      items: const [
                        DropdownMenuItem(value: 'simple', child: Text('简洁（标题+标签）')),
                        DropdownMenuItem(value: 'standard', child: Text('标准（标题+描述+标签）')),
                        DropdownMenuItem(value: 'rich', child: Text('丰富（标题+描述+表情+标签）')),
                      ],
                      onChanged: (v) => setState(() { if (v != null) _captionFormat = v; }),
                    ),
                  ],
                ),
              ),
            ],
          )),
          const SizedBox(height: 20),

          // ==================== 封面文字配置 ====================
          _sectionTitle('封面文字配置', Icons.format_quote_rounded, const Color(0xFFFF5722)),
          _card(Column(
            children: [
              _switchRowWithDesc(
                '封面叠加吸引文字',
                'AI 生成或使用预设文字叠加到封面图片上',
                _enableCoverText,
                (v) => setState(() => _enableCoverText = v),
                activeColor: const Color(0xFFFF5722),
              ),
              if (_enableCoverText) ...[
                const Divider(),
                _switchRowWithDesc(
                  'AI 自动生成封面文字',
                  '关闭则使用下方预设文字（随机选取）',
                  _aiGenerateCoverText,
                  (v) => setState(() => _aiGenerateCoverText = v),
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('预设封面文字（逗号分隔多个备选）',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _coverTextPresetCtrl,
                      decoration: const InputDecoration(
                        hintText: '高清福利,今日精选,顶级资源,私藏珍品',
                        hintStyle: TextStyle(fontSize: 12),
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '💡 开启AI封面文字时：AI根据视频内容智能生成\n'
                      '💡 关闭AI封面文字时：从预设文字中随机选取\n'
                      '💡 文字会用大字幕叠加在封面图片下方',
                      style: TextStyle(fontSize: 11, color: AppTheme.textHint, height: 1.6),
                    ),
                  ],
                ),
              ],
            ],
          )),
          const SizedBox(height: 20),

          // ==================== 自动发布设置 ====================
          _sectionTitle('自动发布设置', Icons.schedule_send_rounded, AppTheme.warning),
          _card(Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('自动发布',
                            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500)),
                        Text('处理完成后自动发布到频道',
                            style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoPublish,
                    onChanged: (v) => setState(() => _autoPublish = v),
                    activeTrackColor: AppTheme.primaryLight,
                    thumbColor: WidgetStatePropertyAll(AppTheme.primary),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('发布间隔',
                            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w500)),
                        Text('每两条消息之间的等待时间',
                            style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: Slider(
                      value: _publishInterval.toDouble(),
                      min: 5,
                      max: 300,
                      divisions: 59,
                      label: '${_publishInterval}s',
                      onChanged: (v) => setState(() => _publishInterval = v.toInt()),
                    ),
                  ),
                  SizedBox(
                    width: 50,
                    child: Text('$_publishInterval 秒',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ],
          )),
          const SizedBox(height: 20),

          // ==================== 关于 ====================
          _sectionTitle('关于', Icons.info_outline_rounded, AppTheme.textHint),
          _card(Column(
            children: [
              _infoRow('版本', 'v2.2.0'),
              const Divider(),
              _infoRow('作者', 'Channel Publisher'),
              const Divider(),
              _infoRow('功能', '视频切片 · 多张封面 · AI文案+标签 · AI封面文字 · Telegram发布'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.primary.withValues(alpha: 0.08),
                    AppTheme.primaryLight.withValues(alpha: 0.04),
                  ]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.telegram, color: AppTheme.primary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '本工具帮助您自动化管理 Telegram 频道内容，包括视频切片处理、'
                        'AI智能文案和情景标签生成、AI封面文字叠加、定时自动发布。',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                      ),
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

  // ==================== AI 服务商选择器 ====================
  Widget _aiProviderSelector() {
    final providers = [
      {'id': 'openai',   'name': 'OpenAI', 'desc': 'ChatGPT · gpt-4o', 'color': const Color(0xFF10A37F)},
      {'id': 'deepseek', 'name': 'DeepSeek', 'desc': '国内可用 · 价格低', 'color': const Color(0xFF4A90E2)},
      {'id': 'qianwen',  'name': '通义千问', 'desc': '阿里云 · 中文强', 'color': const Color(0xFFF5A623)},
      {'id': 'zhipu',    'name': '智谱GLM', 'desc': '有免费额度 · GLM-4', 'color': const Color(0xFF7B5EA7)},
      {'id': 'moonshot', 'name': 'Kimi', 'desc': '月之暗面 · 长文档', 'color': const Color(0xFF0088CC)},
      {'id': 'custom',   'name': '自定义', 'desc': '兼容OpenAI格式', 'color': const Color(0xFF9E9E9E)},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: providers.map((p) {
        final isSelected = _aiProvider == p['id'];
        final color = p['color'] as Color;
        return GestureDetector(
          onTap: () => setState(() {
            _aiProvider = p['id'] as String;
            _aiModel = _defaultModelForProvider(_aiProvider);
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withValues(alpha: 0.12) : AppTheme.bgPage,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? color : AppTheme.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : AppTheme.textPrimary,
                    )),
                Text(p['desc'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? color.withValues(alpha: 0.8) : AppTheme.textHint,
                    )),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ==================== AI 模型选择器 ====================
  Widget _modelSelector() {
    final models = _modelsForProvider(_aiProvider);
    if (_aiProvider == 'custom') {
      // 自定义模式允许输入
      return TextField(
        controller: TextEditingController(text: _aiModel),
        decoration: const InputDecoration(
          hintText: '输入模型名称，如 gpt-4、claude-3-sonnet 等',
          hintStyle: TextStyle(fontSize: 12),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (v) => _aiModel = v,
      );
    }

    // 下拉选择
    final currentModel = models.contains(_aiModel) ? _aiModel : models.first;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<String>(
        value: currentModel,
        isExpanded: true,
        underline: const SizedBox(),
        style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
        items: models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
        onChanged: (v) => setState(() { if (v != null) _aiModel = v; }),
      ),
    );
  }

  // ==================== AI 服务商说明 ====================
  Widget _aiProviderHelpBox() {
    final hints = {
      'openai': 'OpenAI 官网：platform.openai.com\n推荐 gpt-4o-mini（便宜高效）',
      'deepseek': 'DeepSeek：platform.deepseek.com\n国内可用，价格极低，中文效果好',
      'qianwen': '通义千问：dashscope.aliyuncs.com\n阿里云出品，中文效果优秀，按量计费',
      'zhipu': '智谱 GLM：open.bigmodel.cn\nglm-4-flash 有免费额度，适合初次尝试',
      'moonshot': 'Kimi：platform.moonshot.cn\n国内可用，支持超长上下文，理解力强',
      'custom': '支持任何 OpenAI 兼容格式的 API\n如：LM Studio、本地 Ollama、第三方代理等',
    };
    return _helpBox('${_aiProvider == 'custom' ? '自定义 API' : _providerDisplayName(_aiProvider)} 说明', hints[_aiProvider] ?? '');
  }

  String _providerDisplayName(String id) {
    switch (id) {
      case 'openai':   return 'OpenAI';
      case 'deepseek': return 'DeepSeek';
      case 'qianwen':  return '通义千问';
      case 'zhipu':    return '智谱GLM';
      case 'moonshot': return 'Kimi';
      default:         return id;
    }
  }

  String _getApiKeyHint(String provider) {
    switch (provider) {
      case 'openai':   return 'sk-xxxx (platform.openai.com)';
      case 'deepseek': return 'sk-xxxx (platform.deepseek.com)';
      case 'qianwen':  return 'sk-xxxx (dashscope.aliyuncs.com)';
      case 'zhipu':    return 'xxxxxxxx.xxxxxxxx (open.bigmodel.cn)';
      case 'moonshot': return 'sk-xxxx (platform.moonshot.cn)';
      case 'custom':   return '输入你的 API Key';
      default:         return 'API Key';
    }
  }

  // ==================== 通用组件 ====================
  Widget _sslToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _ignoreSslErrors ? Colors.orange.withValues(alpha: 0.08) : AppTheme.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _ignoreSslErrors ? Colors.orange.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.security_rounded, size: 18,
              color: _ignoreSslErrors ? Colors.orange : AppTheme.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('忽略SSL证书验证',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ignoreSslErrors ? Colors.orange : AppTheme.textPrimary)),
                Text('解决"CERTIFICATE_VERIFY_FAILED"错误，VPN/代理环境推荐开启',
                    style: TextStyle(
                        fontSize: 11,
                        color: _ignoreSslErrors ? Colors.orange.withValues(alpha: 0.8) : AppTheme.textHint)),
              ],
            ),
          ),
          Switch(
            value: _ignoreSslErrors,
            onChanged: (v) => setState(() => _ignoreSslErrors = v),
            activeTrackColor: Colors.orange.withValues(alpha: 0.3),
            thumbColor: WidgetStatePropertyAll(_ignoreSslErrors ? Colors.orange : Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _switchRowWithDesc(String label, String desc, bool value,
      ValueChanged<bool> onChanged, {Color? activeColor}) {
    final color = activeColor ?? AppTheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w500)),
                Text(desc,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: color.withValues(alpha: 0.3),
            thumbColor: WidgetStatePropertyAll(value ? color : Colors.grey),
          ),
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
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _subTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary));
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

  Widget _fieldRow(String label, TextEditingController ctrl,
      {String? hint, bool obscure = false, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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

  Widget _helpBox(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(content,
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint, height: 1.6)),
        ],
      ),
    );
  }

  Widget _tipBox(Color color, String content) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(content,
                style: TextStyle(fontSize: 11, color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
              width: 60,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textHint))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
