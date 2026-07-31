import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

// メニューバー常駐のマウス自動移動ツール。
// 設定 (オンオフ・間隔・移動距離) は UserDefaults で永続化し、
// GUI (@AppStorage) と Jiggler の両方が同じキーを読む。
enum Settings {
    static let enabledKey = "jiggleEnabled"
    static let intervalKey = "intervalSeconds"
    static let distanceKey = "jiggleDistance"

    static let defaultInterval: Double = 60
    static let defaultDistance: Double = 20
    static let intervalRange: ClosedRange<Double> = 5...300
    static let distanceRange: ClosedRange<Double> = 5...200
}

final class Jiggler {
    static let shared = Jiggler()

    // 1秒ごとの heartbeat で「設定間隔が経過したか」を判定する。
    // 間隔変更のたびにタイマーを張り直さなくて済む
    private let heartbeatSeconds: TimeInterval = 1
    private let glideStepCount = 12
    private let glideStepDelaySeconds: TimeInterval = 0.008

    private let timer: DispatchSourceTimer
    private var lastJiggle = Date.distantPast

    private init() {
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "mouser.jiggler"))
        timer.schedule(deadline: .now() + heartbeatSeconds, repeating: heartbeatSeconds)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
    }

    private func tick() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Settings.enabledKey) else { return }

        let stored = defaults.double(forKey: Settings.intervalKey)
        let interval = stored > 0 ? stored : Settings.defaultInterval
        guard Date().timeIntervalSince(lastJiggle) >= interval else { return }
        lastJiggle = Date()

        let storedDistance = defaults.double(forKey: Settings.distanceKey)
        jiggle(distance: storedDistance > 0 ? storedDistance : Settings.defaultDistance)
    }

    // ランダムな方向へ distance だけ滑らかに動かし、元の位置へ戻す
    private func jiggle(distance: Double) {
        guard let origin = CGEvent(source: nil)?.location else { return }
        let angle = Double.random(in: 0..<(2 * .pi))
        let target = CGPoint(
            x: origin.x + CGFloat(cos(angle) * distance),
            y: origin.y + CGFloat(sin(angle) * distance)
        )
        glide(from: origin, to: target)
        glide(from: target, to: origin)
    }

    private func glide(from: CGPoint, to: CGPoint) {
        for step in 1...glideStepCount {
            let t = CGFloat(step) / CGFloat(glideStepCount)
            moveMouse(to: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
            Thread.sleep(forTimeInterval: glideStepDelaySeconds)
        }
    }

    private func moveMouse(to point: CGPoint) {
        // 実イベント発行はアクセシビリティ権限が必要 (権限があればアイドルタイマーもリセットされる)。
        // 権限がなくても直後の CGWarpMouseCursorPosition でカーソル自体は必ず動く。
        if let event = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: point,
            mouseButton: .left
        ) {
            event.post(tap: .cghidEventTap)
        }
        CGWarpMouseCursorPosition(point)
    }
}

@main
struct MouserApp: App {
    @AppStorage(Settings.enabledKey) private var isEnabled = false
    private let jiggler = Jiggler.shared

    var body: some Scene {
        MenuBarExtra("Mouser", systemImage: isEnabled ? "cursorarrow.motionlines" : "cursorarrow") {
            SettingsView()
        }
        .menuBarExtraStyle(.window)
    }
}

struct SettingsView: View {
    @AppStorage(Settings.enabledKey) private var isEnabled = false
    @AppStorage(Settings.intervalKey) private var intervalSeconds = Settings.defaultInterval
    @AppStorage(Settings.distanceKey) private var distance = Settings.defaultDistance

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("自動でマウスを動かす", isOn: $isEnabled)
                .toggleStyle(.switch)
                .onChange(of: isEnabled) { enabled in
                    if enabled { promptAccessibilityIfNeeded() }
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("間隔: \(Int(intervalSeconds)) 秒")
                Slider(value: $intervalSeconds, in: Settings.intervalRange, step: 5)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("移動距離: \(Int(distance)) px")
                Slider(value: $distance, in: Settings.distanceRange, step: 5)
            }

            Divider()

            HStack {
                Text("v\(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("終了") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    // 未許可ならアクセシビリティ権限の許可ダイアログを出す
    // (権限なしでもカーソルは動くが、スリープ抑止には権限が必要)
    private func promptAccessibilityIfNeeded() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
