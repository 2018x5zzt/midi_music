# 🎵 MIDI 伴奏 App

一款 iOS 风格的 Flutter MIDI 伴奏应用，支持高品质 SoundFont 音色播放和根据演奏者速度实时调整的智能变速跟随模式。

## ✨ 核心功能

- **MIDI 文件播放** — 解析标准 MIDI 文件（Format 0/1），支持多轨道共享同一 MIDI 通道的复杂文件（如贝多芬月光奏鸣曲），播放/暂停/停止/进度控制
- **SoundFont 音色引擎** — 基于 FluidSynth (Android) / AVFoundation (iOS)，加载 SF2/SF3 音色库
- **轨道控制** — 按轨道（而非通道）独立控制音量、静音，即使多轨道共享同一 MIDI 通道也互不干扰
- **变速跟随模式** — 通过麦克风检测演奏者弹奏节奏（onset detection），实时调整伴奏播放速度
- **iOS 风格 UI** — 全 Cupertino 组件，简约流畅

## 🏗️ 技术栈

| 技术 | 用途 |
|------|------|
| Flutter 3.41+ | 跨平台框架 |
| Cupertino Widgets | iOS 风格 UI |
| flutter_midi_pro | MIDI 引擎（FluidSynth/AVFoundation） |
| dart_midi_pro | MIDI 文件解析 |
| flutter_pitch_detection | 麦克风音频输入（onset detection） |
| permission_handler | 权限管理 |
| Provider | 状态管理 |

## 📁 项目结构

```
lib/
├── main.dart                          # 入口
├── app.dart                           # CupertinoApp 配置
├── core/
│   ├── midi/
│   │   ├── midi_engine.dart           # SoundFont 引擎封装
│   │   ├── midi_parser.dart           # MIDI 文件解析
│   │   ├── midi_player.dart           # 播放控制器
│   │   └── tempo_map.dart             # 速度映射
│   └── follow/
│       ├── microphone_input.dart      # 麦克风音频输入
│       ├── onset_detector.dart        # 音符起始检测
│       └── follow_mode_controller.dart # 变速跟随状态机
├── models/
│   └── midi_track.dart                # MIDI 轨道模型
└── ui/
    └── pages/
        ├── home_page.dart             # 首页（文件选择）
        └── player_page.dart           # 播放器页面
test/
└── midi_parse_test.dart               # MIDI 解析验证脚本
assets/
└── midi/
    └── Beethoven-Moonlight-Sonata.mid # 测试用 MIDI 文件
```

## 🚀 快速开始

### 环境要求

- Flutter 3.41+
- Dart 3.11+
- Android SDK 21+ / iOS 12+

### 安装与运行

```bash
# 克隆项目
git clone https://github.com/2018x5zzt/midi_music.git
cd midi_music

# 安装依赖
flutter pub get

# 运行（需连接设备或模拟器）
flutter run
```

### 准备资源文件

App 需要 SoundFont 音色文件才能播放 MIDI：

1. 下载一个 GM SoundFont 文件（推荐 [TimGM6mb.sf2](https://sourceforge.net/projects/mscore/files/soundfont/TimGM6mb/) ~6MB）
2. 放入 `assets/soundfonts/` 目录
3. 将 MIDI 测试文件放入 `assets/midi/` 目录（可选，App 也支持从设备文件系统选择）

### 打包 APK

```bash
flutter build apk --release
```

生成的 APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 🎯 变速跟随模式

变速跟随是本 App 的核心特色功能，让伴奏跟着演奏者的节奏走。

### 工作原理

```
麦克风输入 → Onset Detection（音符起始检测）→ 状态机 → 实时调整播放速度
```

1. **MicrophoneInput** — 采集麦克风音频流
2. **OnsetDetector** — 纯 Dart 实现，检测音符起始时刻，输出 `Stream<OnsetEvent>`
3. **FollowModeController** — 状态机（WaitingForOnset / Following），使用 EMA（指数移动平均，α=0.3）平滑速度因子

### 使用方式

1. 在播放器页面的轨道列表中，点击「主旋律」选择要跟随的轨道
2. 打开「跟随模式」开关（首次使用需授权麦克风权限）
3. 开始演奏，伴奏会自动跟随你的节奏
4. 关闭开关或点击停止按钮退出跟随模式

## 🔧 技术架构细节

### 多轨道共享 MIDI 通道

许多古典音乐 MIDI 文件（如贝多芬月光奏鸣曲）会将多个轨道（右手、左手）分配到同一个 MIDI 通道（channel 0）。本 App 通过 `trackIndex` 机制解决了这一问题：

- **TimelineEvent** 携带 `trackIndex` 字段标识事件所属轨道
- **解析器** 在解析每个轨道时自动填入 `trackIndex`
- **播放器** 按 `trackIndex`（而非 channel）进行静音/音量控制，实现 O(1) 查找

这确保了即使多轨道共享同一通道，用户也能独立控制每个轨道。

### 播放引擎

- 5ms 精度 Timer 驱动事件调度
- TempoMap 支持多 tempo 变化（如月光奏鸣曲含 61 个 tempo 变化点）
- 二分查找实现高效 seek 定位

## 📄 License

MIT
