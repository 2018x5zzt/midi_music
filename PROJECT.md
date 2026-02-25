# MIDI 伴奏 App

## 项目目标
打造一款 iOS 风格的 Flutter MIDI 伴奏应用，核心功能：
1. 高品质 MIDI 音乐播放（SoundFont 引擎）
2. 变速跟随模式 — 根据演奏者弹奏速度实时调整伴奏播放速度（特别是休止符后的声音启动）

## 技术栈
- **Flutter** + Cupertino (iOS 风格 UI)
- **flutter_midi_pro** — MIDI 引擎（FluidSynth/AVFoundation）
- **dart_midi** — MIDI 文件解析
- SF2/SF3 SoundFont 音色库

## 设计原则
- iOS 风格，简约设计
- 本地优先，后续可迁移云端

## 完成标准 (DoD)
- [ ] App 能加载并播放 MIDI 文件，使用 SoundFont 音色
- [ ] 播放器支持基本控制（播放/暂停/停止/进度）
- [ ] 支持变速跟随模式
- [ ] iOS 风格 UI，流畅交互
- [ ] Android + iOS 双平台可运行
