import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 配置音频会话（只配置一次）
    configureAudioSession()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()

      // 设置为播放和录音模式，并默认使用扬声器
      try session.setCategory(
        AVAudioSession.Category.playAndRecord,
        mode: AVAudioSession.Mode.default,
        options: [
          AVAudioSession.CategoryOptions.allowBluetooth,
          AVAudioSession.CategoryOptions.allowBluetoothA2DP,
          AVAudioSession.CategoryOptions.defaultToSpeaker,
          AVAudioSession.CategoryOptions.mixWithOthers
        ]
      )

      // 激活音频会话
      try session.setActive(true)

      print("[AudioSession] 配置成功: playAndRecord + defaultToSpeaker + mixWithOthers")
    } catch {
      print("[AudioSession] 配置失败: \(error.localizedDescription)")
    }
  }
}
