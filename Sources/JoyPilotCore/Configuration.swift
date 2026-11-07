// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public enum PadButton: String, CaseIterable, Codable, Identifiable {
    case r, zr, plus, y, a, x, b, stick, home, sl, sr
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .r: return "R 肩键"
        case .zr: return "ZR 扳机"
        case .plus: return "＋ 加号键"
        case .stick: return "摇杆 / 按下"
        case .home: return "Home"
        default: return rawValue.uppercased()
        }
    }
    public var symbol: String { self == .plus ? "+" : self == .stick ? "◉" : rawValue.uppercased() }
}

public enum ActionGroup: String, CaseIterable, Identifiable { case mouse = "鼠标", keyboard = "键盘", system = "系统", voice = "语音", application = "应用"; public var id: String { rawValue } }
public enum PadAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case leftClick, rightClick, scrollUp, scrollDown, airMouse, precision
    case enter, commandEnter, shiftEnter, backspace, escape, tab, copy, paste, customShortcut, none
    case desktopLeft, desktopRight, missionControl, showDesktop, appSwitcher, previousTab, nextTab, pause
    case voice, focusInput, openApplication, volumeUp, volumeDown, mute, playPause
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .leftClick: return "鼠标左键"
        case .rightClick: return "鼠标右键"
        case .scrollUp: return "向上滚动"
        case .scrollDown: return "向下滚动"
        case .airMouse: return "空中鼠标"
        case .precision: return "慢速定位"
        case .enter: return "回车发送"
        case .commandEnter: return "⌘ 回车发送"
        case .shiftEnter: return "⇧ 回车换行"
        case .backspace: return "退格删除"
        case .escape: return "取消 Esc"
        case .tab: return "切换焦点 Tab"
        case .copy: return "复制"
        case .paste: return "粘贴"
        case .customShortcut: return "自定义快捷键"
        case .none: return "不执行操作"
        case .desktopLeft: return "上一个桌面"
        case .desktopRight: return "下一个桌面"
        case .missionControl: return "窗口总览"
        case .showDesktop: return "显示桌面"
        case .appSwitcher: return "切换应用"
        case .previousTab: return "上一个标签页"
        case .nextTab: return "下一个标签页"
        case .pause: return "暂停 / 恢复"
        case .voice: return "语音输入"
        case .focusInput: return "定位输入框"
        case .openApplication: return "打开应用"
        case .volumeUp: return "音量加"
        case .volumeDown: return "音量减"
        case .mute: return "静音"
        case .playPause: return "播放 / 暂停"
        }
    }
    public var group: ActionGroup {
        switch self {
        case .leftClick, .rightClick, .scrollUp, .scrollDown, .airMouse, .precision: return .mouse
        case .desktopLeft, .desktopRight, .missionControl, .showDesktop, .appSwitcher, .pause: return .system
        case .voice: return .voice
        case .focusInput, .openApplication: return .application
        case .volumeUp, .volumeDown, .mute, .playPause: return .system
        default: return .keyboard
        }
    }
    public var symbol: String {
        switch self {
        case .leftClick, .rightClick: return "computermouse"
        case .airMouse: return "cursorarrow.motionlines"
        case .precision: return "scope"
        case .scrollUp: return "arrow.up"
        case .scrollDown: return "arrow.down"
        case .voice: return "mic"
        case .focusInput: return "text.cursor"
        case .openApplication: return "app.badge"
        case .volumeUp, .volumeDown, .mute: return "speaker.wave.2"
        case .playPause: return "playpause"
        case .desktopLeft: return "arrow.left.square"
        case .desktopRight: return "arrow.right.square"
        case .enter, .commandEnter: return "return"
        case .missionControl: return "rectangle.3.group"
        case .showDesktop: return "macwindow"
        case .pause: return "pause.circle"
        case .backspace: return "delete.left"
        default: return "keyboard"
        }
    }
    public var isContinuous: Bool { [.leftClick, .scrollUp, .scrollDown, .airMouse, .precision, .voice].contains(self) }
    public var detail: String {
        switch self {
        case .leftClick: return "按下左键，松开释放；按住并移动可拖动。"
        case .airMouse: return "按住转动手腕，松开停止。与语音同时按住时优先语音。"
        case .voice: return "调用所选语音工具，触发方式由语音配置决定。"
        case .focusInput: return "先使用当前应用已学习的输入框，必要时进行辅助功能查找并校验焦点。"
        case .desktopLeft, .desktopRight: return "使用系统的 Control + 左右方向键；需要在系统键盘快捷键中启用。"
        case .precision: return "按住时降低鼠标速度，松开恢复。"
        case .enter: return "发送 Return。是否发送消息由目标应用决定。"
        case .scrollUp, .scrollDown: return "按住连续滚动，保留小数位移，低速也能工作。"
        default: return "按键功能立即保存；按应用配置会覆盖全局默认。"
        }
    }
}

public struct Hotkey: Codable, Equatable, Hashable, Sendable {
    public var code: UInt16
    public var flags: UInt64
    public var label: String
    public init(code: UInt16, flags: UInt64 = 0, label: String) { self.code = code; self.flags = flags; self.label = label }
    public static let rightCommand = Hotkey(code: 54, flags: 0x100010, label: "右 Command")
    public static let fn = Hotkey(code: 63, flags: 0x800000, label: "Fn")
}
public struct Command: Codable, Equatable, Hashable, Sendable {
    public var action: PadAction
    public var shortcut: Hotkey?
    public var applicationID: String?
    public var applicationName: String?
    public init(_ action: PadAction, shortcut: Hotkey? = nil, applicationID: String? = nil, applicationName: String? = nil) {
        self.action = action; self.shortcut = shortcut; self.applicationID = applicationID; self.applicationName = applicationName
    }
}
public struct ButtonBinding: Codable, Equatable {
    public var primary: Command
    public var double: Command?
    public var long: Command?
    public var repeats = false
    public init(_ action: PadAction) { primary = Command(action) }
    enum CodingKeys: String, CodingKey { case primary, double, long, repeats }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        primary = try container.decode(Command.self, forKey: .primary)
        double = try container.decodeIfPresent(Command.self, forKey: .double)
        long = try container.decodeIfPresent(Command.self, forKey: .long)
        repeats = try container.decodeIfPresent(Bool.self, forKey: .repeats) ?? false
    }
}
public enum MappingLayer: String, CaseIterable, Identifiable { case base = "基础", rHeld = "按住 R"; public var id: String { rawValue } }
public enum VoiceProvider: String, Codable, CaseIterable, Identifiable {
    case doubao = "豆包输入法", weixin = "微信输入法", typeless = "Typeless", vokie = "Vokie", custom = "其他工具"
    public var id: String { rawValue }
}
public enum VoiceGesture: String, Codable, CaseIterable, Identifiable {
    case hold = "按住说话", toggle = "点按开始 / 结束", edges = "按住转两次点按"
    public var id: String { rawValue }
}
public struct VoiceSettings: Codable, Equatable {
    public var provider: VoiceProvider = .doubao
    public var gesture: VoiceGesture = .hold
    public var shortcut = Hotkey.rightCommand
    public init() {}
    public mutating func choose(_ provider: VoiceProvider) {
        self.provider = provider
        switch provider {
        case .doubao, .weixin: gesture = .hold; shortcut = .rightCommand
        case .typeless, .vokie: gesture = .toggle; shortcut = .fn
        case .custom: break
        }
    }
}
public struct FocusTarget: Codable, Equatable {
    public var role: String
    public var identifier: String
    public var placeholder: String
    public var ancestors: [String]
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public init(role: String, identifier: String, placeholder: String, ancestors: [String], x: Double, y: Double, width: Double, height: Double) {
        self.role = role; self.identifier = identifier; self.placeholder = placeholder; self.ancestors = ancestors
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}
public struct AppProfile: Codable, Equatable, Identifiable {
    public var id: String // bundle ID; "global" for defaults
    public var name: String
    public var base: [String: ButtonBinding] = [:]
    public var layer: [String: ButtonBinding] = [:]
    public var focusTarget: FocusTarget?
    public var focusShortcut: Hotkey?
    public init(id: String, name: String) { self.id = id; self.name = name }
}
public struct PilotSettings: Codable, Equatable {
    public var schema = 1
    public var profiles: [AppProfile] = [AppProfile(id: "global", name: "全局")]
    public var pointerSpeed = 700.0
    public var scrollSpeed = 0.7
    public var deadzone = 0.15
    public var invertScroll = false
    public var gyroSensitivity = 15.0
    public var gyroSmoothing = 0.045
    public var invertGyroX = false
    public var invertGyroY = false
    public var voice = VoiceSettings()
    public init() {}
    public static let defaultBase: [PadButton: PadAction] = [
        .y: .leftClick, .a: .rightClick, .x: .scrollUp, .b: .scrollDown,
        .r: .airMouse, .zr: .voice, .plus: .enter, .home: .focusInput,
        .sl: .desktopLeft, .sr: .desktopRight, .stick: .precision
    ]
    public static let defaultLayer: [PadButton: PadAction] = [
        .x: .missionControl, .b: .showDesktop, .plus: .backspace,
        .home: .appSwitcher, .sl: .previousTab, .sr: .nextTab
    ]
    public func binding(for button: PadButton, scope: String, layer: MappingLayer) -> ButtonBinding {
        let key = button.rawValue
        let app = profiles.first { $0.id == scope }
        let global = profiles.first { $0.id == "global" }
        if layer == .rHeld {
            if let b = app?.layer[key] ?? global?.layer[key] { return b }
            if let action = Self.defaultLayer[button] { return ButtonBinding(action) }
        }
        return app?.base[key] ?? global?.base[key] ?? ButtonBinding(Self.defaultBase[button] ?? .none)
    }
    public mutating func set(_ binding: ButtonBinding, button: PadButton, scope: String, layer: MappingLayer) {
        guard !(button == .r && layer == .rHeld), let index = profiles.firstIndex(where: { $0.id == scope }) else { return }
        if layer == .base { profiles[index].base[button.rawValue] = binding }
        else { profiles[index].layer[button.rawValue] = binding }
    }
}
