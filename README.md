# Channel Publisher - Windows 构建说明

## 快速开始（Windows 用户）

### 前提条件

1. **Flutter SDK** (3.x)
   - 下载: https://flutter.dev/docs/get-started/install/windows
   - 解压到 `C:\flutter`，添加 `C:\flutter\bin` 到 PATH

2. **Visual Studio 2022** with **Desktop development with C++**
   - 下载: https://visualstudio.microsoft.com/downloads/
   - 安装时勾选 "Desktop development with C++"

### 一键构建

双击运行 `build_windows.bat`

### 手动构建

```cmd
flutter config --enable-windows-desktop
flutter pub get
flutter build windows --release
```

输出文件位置：
```
build\windows\x64\runner\Release\channel_publisher.exe
```

---

## 功能说明

| 功能 | 描述 |
|------|------|
| 📁 添加视频 | 支持 mp4/mkv/avi/mov/wmv/flv/webm |
| 📂 文件夹扫描 | 自动扫描文件夹内所有视频文件 |
| ✂️ 视频切片 | 按指定时长自动切片 |
| 🖼️ 封面生成 | 自动提取视频帧作为封面 |
| 🤖 AI 文案 | 调用 OpenAI API 生成标题和描述 |
| 📤 Telegram 发布 | 通过 Bot API 自动发布到频道 |
| ⏱️ 定时发布 | 设置发布间隔，避免 Telegram 限流 |

## 配置说明

1. 打开应用 → 点击左侧 **设置**
2. 填入 **Bot Token**（从 @BotFather 获取）
3. 填入 **频道 ID**（格式：@channel_name 或 -100XXXXXXXXX）
4. 可选：填入 **OpenAI API Key** 以启用 AI 自动文案
5. 点击 **测试连接** 验证配置
6. 点击 **保存设置**
