# WindWhisper 风语者

<p align="center">
  <img src="WindWhisper/Resources/icon_widget@2x.png" width="128" height="128" alt="WindWhisper">
</p>

<p align="center">
  <b>macOS 离线语音输入助手</b><br>
  点击悬浮球，说话即输入，无需联网，隐私安全
</p>

<p align="center">
  <a href="#english">English</a> · <a href="#中文">中文</a>
</p>

---

<a id="中文"></a>

## 功能特性

- 🎤 **离线语音识别** — 基于 SenseVoice 模型，无需联网，数据不出本机
- 🌐 **多语种支持** — 中文、英文、日文、韩文、粤语自动检测
- 🔤 **自动标点** — 识别结果自带标点符号
- 📋 **自动粘贴** — 识别完成自动输入到当前光标位置（可关闭）
- 🎯 **悬浮球交互** — 屏幕常驻悬浮球，点击即录，可拖动
- ⏱️ **倒计时提示** — 最长 60 秒录音，倒计时 + 动画
- 📝 **结果管理** — 识别结果停留展示，支持复制、关闭
- 🎨 **风语者主题** — 天青色调 UI，波纹动画

## 系统要求

- macOS 13.0+
- Apple Silicon 或 Intel Mac
- 约 400MB 磁盘空间（含模型）

## 安装

从 [Releases](https://github.com/Fengur/WindWhisper/releases) 下载最新版本，解压后将 `WindWhisper.app` 拖入应用程序文件夹。

首次启动需要授权：
1. **麦克风权限** — 系统会自动弹出提示
2. **辅助功能权限** — 用于自动粘贴到输入框（可选）

## 使用方法

1. 启动后屏幕边缘出现悬浮球
2. **点击悬浮球** 开始录音（球展开，显示倒计时）
3. **再次点击** 停止录音，等待识别
4. 识别结果显示在面板中，自动粘贴到当前输入框
5. 点击 **复制按钮** 手动复制，或点击 **×** 关闭面板

状态栏图标也可以左键点击开始/停止录音，右键打开菜单。

## 设置

**打开设置**：状态栏图标右键 → **设置…**（快捷键 `⌘,`）。

| 选项 | 说明 |
|------|------|
| **识别语言** | `中文` / `English` / `自动检测`。自动检测支持中英日韩粤,偶有误判时可固定语种。 |
| **自动粘贴到输入框** | 识别完成后自动 `Cmd+V` 到当前焦点输入框。关闭后仅复制到剪贴板,需手动粘贴。 |
| **显示悬浮按钮** | 关闭后只保留状态栏入口,屏幕上不再有常驻悬浮球。 |
| **重置位置** | 把悬浮球弹回屏幕右侧默认位置。多屏切换 / 悬浮球被拖出可见区后用这个。 |

### 状态栏右键菜单

- **状态**:实时显示 `就绪` / `录音中` / `识别中`
- **上次**:最近一次识别的文本预览
- **开始 / 停止录音**:键盘党可以只用状态栏,不碰悬浮球
- **显示悬浮球 (重置位置)**:悬浮球消失时的兜底入口 —— 强制重置到默认位置并显示
- **设置…** / **退出 WindWhisper**(`⌘Q`)

### 权限

| 权限 | 用途 | 必须? |
|------|------|------|
| 麦克风 | 录音 | 必须 |
| 辅助功能 | 自动粘贴(模拟 `Cmd+V`) | 仅在开启"自动粘贴"时需要 |

辅助功能授权后,**需要重启 App 一次**才能生效。

### 配置持久化

所有设置存在 `~/Library/Preferences/com.windwhisper.app.plist`(由 `UserDefaults` 管理),卸载重装会保留。悬浮球的最后位置也存在这里。

## 技术实现

### 架构

```
麦克风 (AVAudioEngine 16kHz) → PCM 录音 → SenseVoice 离线识别 → 文本注入
```

### 核心技术栈

| 组件 | 技术 |
|------|------|
| 语音识别 | [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) + [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) |
| 音频采集 | AVAudioEngine（16kHz mono Float32） |
| 麦克风增益 | [micvol](https://github.com/Fengur/micvol)（硬件级输入音量控制） |
| UI 框架 | AppKit + [SnapKit](https://github.com/SnapKit/SnapKit) |
| 动画 | Core Animation |
| 文本注入 | NSPasteboard + CGEvent / AppleScript |
| 后备识别 | [whisper.cpp](https://github.com/ggerganov/whisper.cpp)（英文） |

### 识别模型

- **SenseVoice int8**（228MB）— 主力中文识别，支持中英日韩粤
- **Whisper small**（466MB）— 后备英文识别

### 文本后处理

- 幻觉过滤（whisper 常见的字幕水印等）
- 繁体→简体转换（约 130 个常用字映射）

## 从源码构建

### 前置条件

- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- CMake（用于编译 sherpa-onnx）

### 步骤

```bash
# 1. 克隆仓库
git clone https://github.com/Fengur/WindWhisper.git
cd WindWhisper

# 2. 编译 sherpa-onnx
git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx vendor/sherpa-onnx
cd vendor/sherpa-onnx && bash build-swift-macos.sh && cd ../..
cp -r vendor/sherpa-onnx/build-swift-macos/sherpa-onnx.xcframework Libraries/
cp vendor/sherpa-onnx/build-swift-macos/install/lib/libonnxruntime.a Libraries/

# 3. 下载模型
mkdir -p WindWhisper/Resources/sensevoice
curl -L -o WindWhisper/Resources/sensevoice/model.int8.onnx \
  https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx
curl -L -o WindWhisper/Resources/sensevoice/tokens.txt \
  https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt

# 4. (可选) 下载 whisper 模型
curl -L -o WindWhisper/Resources/ggml-small.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin

# 5. 生成 Xcode 项目并构建
xcodegen generate
xcodebuild -project WindWhisper.xcodeproj -scheme WindWhisper -configuration Release build
```

## 路线图

### v1.0（当前）
- ✅ SenseVoice 离线中文识别
- ✅ 悬浮球交互 + 自动粘贴
- ✅ 多语种支持

### v2.0（计划中）
- 🔲 更好的流式识别方案
- 🔲 VAD 自动停止
- 🔲 快捷键支持
- 🔲 浮窗视觉升级（风语者主题动效）
- 🔲 设备热插拔监听

## 反馈

- 🐛 **Bug / 功能建议**:提 [Issue](https://github.com/Fengur/WindWhisper/issues)
- 📮 **邮件**:fengur@qq.com

欢迎附上 macOS 版本 / 机型 / 复现步骤,日志位于 `~/Library/Logs/WindWhisper/`。

## 致谢

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) — 离线语音识别框架
- [SenseVoice](https://github.com/FunAudioLLM/SenseVoice) — 阿里多语种语音识别模型
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — OpenAI Whisper 的 C/C++ 移植
- [micvol](https://github.com/Fengur/micvol) — macOS 麦克风音量控制

## License

MIT

---

<a id="english"></a>

## English

### WindWhisper — Offline Voice Input for macOS

WindWhisper is a macOS offline voice input assistant. Click the floating bubble, speak, and your words appear at the cursor. No internet required, no data leaves your machine.

### Features

- 🎤 **Offline recognition** — Powered by SenseVoice, runs entirely on-device
- 🌐 **Multi-language** — Chinese, English, Japanese, Korean, Cantonese with auto-detection
- 🔤 **Auto-punctuation** — Recognition results include punctuation
- 📋 **Auto-paste** — Recognized text is automatically pasted at cursor position
- 🎯 **Floating bubble** — Always-on-screen bubble, click to record, draggable
- ⏱️ **Countdown timer** — 60-second max recording with animated countdown

### Requirements

- macOS 13.0+
- Apple Silicon or Intel Mac
- ~400MB disk space (including models)

### Installation

Download the latest release from [Releases](https://github.com/Fengur/WindWhisper/releases), unzip, and drag `WindWhisper.app` to Applications.

### Usage

1. Launch — floating bubble appears on screen edge
2. **Click bubble** to start recording
3. **Click again** to stop and recognize
4. Text appears in panel and auto-pastes to focused input field
5. Click **copy** or **×** to dismiss

### Settings

Open via status bar icon → right-click → **Settings…** (`⌘,`):

| Option | Description |
|--------|-------------|
| **Recognition Language** | `中文` / `English` / `Auto`. Auto covers zh/en/ja/ko/yue; pin to a language if detection misfires. |
| **Auto-paste** | Paste result via simulated `Cmd+V` to focused input. When off, text only goes to clipboard. |
| **Show Floating Bubble** | Hide the always-on bubble; status bar icon still works. |
| **Reset Position** | Snap bubble back to the default right-edge spot. Use after multi-monitor changes. |

Status bar right-click menu also provides state readout, last result preview, start/stop, **Show Bubble (reset position)** as a fallback if the bubble goes missing, and quit.

### Permissions

- **Microphone** — required
- **Accessibility** — required only if you enable auto-paste (to simulate `Cmd+V`). Restart the app once after granting.

### Feedback

- Bugs / feature requests: [Issues](https://github.com/Fengur/WindWhisper/issues)
- Email: fengur@qq.com

Logs live at `~/Library/Logs/WindWhisper/`.

### Tech Stack

| Component | Technology |
|-----------|-----------|
| Speech Recognition | sherpa-onnx + SenseVoice (offline) |
| Audio Capture | AVAudioEngine (16kHz mono) |
| Mic Volume | micvol (hardware-level gain) |
| UI | AppKit + SnapKit + Core Animation |
| Text Injection | NSPasteboard + CGEvent |
| Fallback ASR | whisper.cpp (English) |

### Building from Source

```bash
git clone https://github.com/Fengur/WindWhisper.git
cd WindWhisper

# Build sherpa-onnx
git clone --depth 1 https://github.com/k2-fsa/sherpa-onnx vendor/sherpa-onnx
cd vendor/sherpa-onnx && bash build-swift-macos.sh && cd ../..
cp -r vendor/sherpa-onnx/build-swift-macos/sherpa-onnx.xcframework Libraries/
cp vendor/sherpa-onnx/build-swift-macos/install/lib/libonnxruntime.a Libraries/

# Download SenseVoice model
mkdir -p WindWhisper/Resources/sensevoice
curl -L -o WindWhisper/Resources/sensevoice/model.int8.onnx \
  https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx
curl -L -o WindWhisper/Resources/sensevoice/tokens.txt \
  https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/tokens.txt

# Build
xcodegen generate
xcodebuild -project WindWhisper.xcodeproj -scheme WindWhisper -configuration Release build
```

### License

MIT
