// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Carbon
import JoyPilotCore

/// Audio remains in the external input tool. No recording, ASR service, or API key.
final class VoiceBridge {
    private let emitter: EventEmitter
    private var session: VoiceSettings?
    private(set) var latched = false
    private var held = false
    init(emitter: EventEmitter) { self.emitter = emitter }
    func press(_ settings: VoiceSettings) -> String {
        if latched {
            if let session { emitter.shortcut(session.shortcut) }
            latched = false; session = nil
            return "已发送结束语音快捷键，请检查输入工具状态"
        }
        session = settings
        switch settings.gesture {
        case .hold: emitter.hold(settings.shortcut); held = true
        case .toggle: emitter.shortcut(settings.shortcut); latched = true
        case .edges: emitter.shortcut(settings.shortcut); held = true
        }
        return settings.gesture == .toggle ? "已触发语音，再按一次语音键结束" : "语音键已按下，松开结束"
    }
    func release() -> String? {
        guard held, let session else { return nil }
        held = false
        if session.gesture == .hold { emitter.release(session.shortcut) }
        else { emitter.shortcut(session.shortcut) }
        self.session = nil
        return "已释放语音快捷键，请检查文字结果"
    }
    func cancel() {
        if latched, let session { emitter.shortcut(session.shortcut) }
        _ = release(); latched = false; session = nil
    }
    static func installedProviders() -> Set<VoiceProvider> {
        var providers: Set<VoiceProvider> = []
        let sources = TISCreateInputSourceList(nil, false).takeRetainedValue() as NSArray
        for source in sources {
            let item = source as! TISInputSource
            guard let pointer = TISGetInputSourceProperty(item, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
            if id.contains("doubaoime") { providers.insert(.doubao) }
            if id.contains("wetype") { providers.insert(.weixin) }
        }
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: "now.typeless.desktop") != nil { providers.insert(.typeless) }
        if NSWorkspace.shared.urlForApplication(toOpen: URL(string: "vokie://launch")!) != nil { providers.insert(.vokie) }
        return providers
    }
}
