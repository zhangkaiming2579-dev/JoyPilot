// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Observation
import JoyPilotCore

@MainActor @Observable
final class AppModel {
    var settings: PilotSettings
    var selectedButton: PadButton = .r
    var selectedScope = "global"
    var editingLayer: MappingLayer = .base
    var selectedGesture = 0
    var selectedGroup: ActionGroup = .mouse
    var connected = false
    var battery = "—"
    var authorized = false
    var paused = false
    var activeButtons = Set<PadButton>()
    var status = "等待右手柄连接"
    var focusStatus = "选择应用并学习输入框，Home 将使用对应配置"
    var lastExternalName = "目标应用"
    var lastExternalBundle = ""
    var calibrationProgress = 0.0
    var calibrating = false
    var calibrated = false
    var displayStick = CGPoint.zero
    var motionTrace = CGPoint.zero
    var saved = true
    var voiceOpen = false
    var focusBusy = false
    let installedVoiceProviders: Set<VoiceProvider>

    @ObservationIgnored private let emitter = EventEmitter()
    @ObservationIgnored private lazy var voice = VoiceBridge(emitter: emitter)
    @ObservationIgnored private let focus = FocusService()
    @ObservationIgnored private var manager: JoyConManager?
    @ObservationIgnored private var controller: Controller?
    @ObservationIgnored private var router = InputRouter()
    @ObservationIgnored private var gyro = GyroProcessor()
    @ObservationIgnored private var stick = CGPoint.zero
    @ObservationIgnored private var clock: Timer?
    @ObservationIgnored private var lastTick = ProcessInfo.processInfo.systemUptime
    @ObservationIgnored private var lastUI = 0.0
    @ObservationIgnored private var lastTraceUI = 0.0
    @ObservationIgnored private var focusRequest = UUID()
    @ObservationIgnored private var calibrationStarted = 0.0
    @ObservationIgnored private var lastExternalPID: pid_t?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var settingsTimer: Timer?
    @ObservationIgnored private var defaults: UserDefaults
    @ObservationIgnored private var started = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "settings.v1"), let saved = try? JSONDecoder().decode(PilotSettings.self, from: data) { settings = saved }
        else { settings = PilotSettings() }
        installedVoiceProviders = VoiceBridge.installedProviders()
        for (bundle, name) in [("com.tencent.xinWeChat", "微信"), ("com.electron.lark", "飞书"), ("com.bytedance.lark", "飞书"), ("com.google.Chrome", "Chrome"), ("com.apple.Safari", "Safari")] {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) != nil && !settings.profiles.contains(where: { $0.id == bundle }) { settings.profiles.append(AppProfile(id: bundle, name: name)) }
        }
        authorized = emitter.authorized
        if let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier { remember(app) }
    }
    var binding: ButtonBinding { settings.binding(for: selectedButton, scope: selectedScope, layer: editingLayer) }
    var selectedCommand: Command? { selectedGesture == 0 ? binding.primary : selectedGesture == 1 ? binding.double : binding.long }
    var visibleAction: PadAction { selectedCommand?.action ?? .none }
    var targetName: String { selectedScope == "global" ? lastExternalName : settings.profiles.first { $0.id == selectedScope }?.name ?? lastExternalName }
    var targetBundle: String { selectedScope == "global" ? lastExternalBundle : selectedScope }
    var targetProfile: AppProfile? { settings.profiles.first { $0.id == targetBundle } }
    var hasLearnedTarget: Bool { targetProfile?.focusTarget != nil }
    var activeLayer: MappingLayer { router.held.contains(.r) ? .rHeld : .base }
    var activeScopeName: String { settings.profiles.first { $0.id == lastExternalBundle }?.name ?? "全局" }

    func start() {
        guard !started else { return }; started = true
        let manager = JoyConManager(); self.manager = manager
        manager.connectHandler = { [weak self] controller in DispatchQueue.main.async { self?.attach(controller) } }
        manager.disconnectHandler = { [weak self] controller in DispatchQueue.main.async { self?.detach(controller) } }
        _ = manager.runAsync()
        lastTick = ProcessInfo.processInfo.systemUptime
        clock = Timer(timeInterval: 1.0/120, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        RunLoop.main.add(clock!, forMode: .common)
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self, let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated {
                let speechTool = app.bundleIdentifier == "now.typeless.desktop" || (app.bundleIdentifier ?? "").contains("doubaoime") || (app.bundleIdentifier ?? "").contains("wetype")
                if speechTool && (self.router.voiceHeld || self.voice.latched) { return }
                self.cancelInputs()
                if app.bundleIdentifier != Bundle.main.bundleIdentifier { self.remember(app) }
            }
        })
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.cancelInputs(); self?.focus.cancel() } })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.cancelInputs() } })
    }
    func shutdown() { cancelInputs(); focus.cancel(); clock?.invalidate(); manager?.stop(); manager = nil; settingsTimer?.invalidate(); persist(); observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }; observers.removeAll() }
    private func remember(_ app: NSRunningApplication) { lastExternalPID = app.processIdentifier; lastExternalBundle = app.bundleIdentifier ?? ""; lastExternalName = app.localizedName ?? "应用" }
    func select(_ button: PadButton) { selectedButton = button; selectedGesture = 0; selectedGroup = binding.primary.action.group }
    func changedSettings(cancel: Bool = true) {
        if cancel { cancelInputs() }
        saved = false; settingsTimer?.invalidate()
        settingsTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in MainActor.assumeIsolated { self?.persist() } }
    }
    private func persist() {
        do { let data = try JSONEncoder().encode(settings); defaults.set(data, forKey: "settings.v1"); saved = true }
        catch { saved = false; status = "设置未保存，请重试" }
    }
    func chooseAction(_ action: PadAction) {
        guard selectedButton != .r || editingLayer != .rHeld else { return }
        var new = binding
        let command: Command? = action == .none && selectedGesture != 0 ? nil : Command(action)
        if selectedGesture == 0 { new.primary = command!; new.repeats = false; if action.isContinuous { new.double = nil; new.long = nil; new.repeats = false } }
        else if selectedGesture == 1 { new.double = command; new.repeats = false }
        else { new.long = command; new.repeats = false }
        settings.set(new, button: selectedButton, scope: selectedScope, layer: editingLayer)
        changedSettings(); status = "\(selectedButton.title) 已设为 \(action.title)"
    }
    func setCustomHotkey(_ hotkey: Hotkey) {
        guard selectedButton != .r || editingLayer != .rHeld else { return }
        var new = binding
        let command = Command(.customShortcut, shortcut: hotkey)
        if selectedGesture == 0 { new.primary = command }
        else if selectedGesture == 1 { new.double = command } else { new.long = command }
        settings.set(new, button: selectedButton, scope: selectedScope, layer: editingLayer); changedSettings()
    }
    func chooseApplicationAction() {
        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]; panel.canChooseDirectories = false; panel.prompt = "选择应用"
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return }
        var new = binding
        let command = Command(.openApplication, applicationID: id, applicationName: url.deletingPathExtension().lastPathComponent)
        if selectedGesture == 0 { new.primary = command }
        else if selectedGesture == 1 { new.double = command } else { new.long = command }
        settings.set(new, button: selectedButton, scope: selectedScope, layer: editingLayer); changedSettings()
    }
    private func openApplication(_ command: Command) {
        guard let id = command.applicationID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { status = "请先选择要打开的应用"; return }
        let options = NSWorkspace.OpenConfiguration(); options.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: options) { [weak self] app, error in
            DispatchQueue.main.async { self?.status = error == nil && app != nil ? "已打开：\(command.applicationName ?? "应用")" : "打开应用失败" }
        }
    }
    func setRepeat(_ enabled: Bool) {
        var new = binding; new.repeats = enabled
        if enabled { new.double = nil; new.long = nil; selectedGesture = 0 }
        settings.set(new, button: selectedButton, scope: selectedScope, layer: editingLayer); changedSettings()
    }
    func resetSelected() {
        guard let index = settings.profiles.firstIndex(where: { $0.id == selectedScope }) else { return }
        if editingLayer == .base { settings.profiles[index].base.removeValue(forKey: selectedButton.rawValue) }
        else { settings.profiles[index].layer.removeValue(forKey: selectedButton.rawValue) }
        changedSettings(); selectedGroup = binding.primary.action.group
    }
    func addApplication() {
        let panel = NSOpenPanel(); panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.prompt = "添加应用"
        if panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url), let id = bundle.bundleIdentifier {
            if !settings.profiles.contains(where: { $0.id == id }) { settings.profiles.append(AppProfile(id: id, name: url.deletingPathExtension().lastPathComponent)) }
            selectedScope = id; changedSettings()
        }
    }
    func togglePause() { paused.toggle(); cancelInputs(); status = paused ? "已暂停手柄控制" : "已恢复手柄控制" }
    func openPermissions() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
    func openSound() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!) }
    func openKeyboard() { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")!) }
    func chooseVoiceProvider(_ provider: VoiceProvider) { settings.voice.choose(provider); changedSettings() }
    func calibrate() {
        guard connected else { status = "先连接并唤醒右手柄，再静置校准"; return }
        cancelInputs(); gyro.startCalibration(); calibrationStarted = ProcessInfo.processInfo.systemUptime
        calibrating = true; calibrationProgress = 0; status = "请将手柄放稳，保持静止约两秒"
    }
    private func attach(_ pad: Controller) {
        guard pad.type == .JoyConR else { return }
        if let old = controller, old === pad { return }
        cancelInputs(); controller = pad; connected = true; status = "右手柄已连接"
        pad.enableIMU(enable: true); pad.setInputMode(mode: .standardFull)
        pad.buttonPressHandler = { [weak self, weak pad] value in DispatchQueue.main.async { guard let self, let pad, self.controller === pad else { return }; self.button(value, down: true) } }
        pad.buttonReleaseHandler = { [weak self, weak pad] value in DispatchQueue.main.async { guard let self, let pad, self.controller === pad else { return }; self.button(value, down: false) } }
        pad.rightStickPosHandler = { [weak self, weak pad] point in DispatchQueue.main.async { guard let self, let pad, self.controller === pad else { return }; self.stick = point } }
        pad.sensorHandler = { [weak self, weak pad] in
            guard let pad else { return }
            let vector = MotionVector(Double(pad.gyro.x), Double(pad.gyro.y), Double(pad.gyro.z))
            DispatchQueue.main.async { guard let self, self.controller === pad else { return }; self.sensor(vector) }
        }
        updateBattery()
    }
    private func detach(_ pad: Controller) {
        guard controller === pad else { return }
        cancelInputs(); controller = nil; connected = false; battery = "—"; status = "右手柄已断开，所有按键已释放"
    }
    private func updateBattery() {
        switch controller?.battery {
        case .full: battery = "100%"
        case .medium: battery = "50%"
        case .low: battery = "25%"
        case .critical: battery = "10%"
        case .empty: battery = "0%"
        default: battery = "—"
        }
    }
    private func button(_ value: JoyCon.Button, down: Bool) {
        let button: PadButton
        switch value {
        case .Y: button = .y
        case .A: button = .a
        case .X: button = .x
        case .B: button = .b
        case .R: button = .r
        case .ZR: button = .zr
        case .Plus: button = .plus
        case .Home: button = .home
        case .RStick: button = .stick
        case .RightSL: button = .sl
        case .RightSR: button = .sr
        default: return
        }
        if down { activeButtons.insert(button) } else { activeButtons.remove(button) }
        if !down { apply(router.release(button, now: ProcessInfo.processInfo.systemUptime)); return }
        let layer: MappingLayer = router.held.contains(.r) && button != .r ? .rHeld : .base
        let binding = settings.binding(for: button, scope: lastExternalBundle, layer: layer)
        guard !paused || binding.primary.action == .pause else { return }
        guard emitter.authorized else { status = "需要辅助功能授权才能控制电脑"; return }
        if voice.latched {
            if binding.primary.action == .voice { status = voice.press(settings.voice); voiceOpen = voice.latched }
            return
        }
        apply(router.press(button, binding: binding, now: ProcessInfo.processInfo.systemUptime))
    }
    private func apply(_ effects: [InputEffect]) {
        for effect in effects {
            switch effect {
            case .begin(let command):
                switch command.action {
                case .leftClick: emitter.mouseDown()
                case .voice: status = voice.press(settings.voice); voiceOpen = true; gyro.resetFilter(); stick = .zero; emitter.resetScroll()
                case .airMouse: gyro.resetFilter(); status = "空中鼠标 · 松开 R 停止"
                default: break
                }
            case .end(let command):
                switch command.action {
                case .leftClick: emitter.mouseUp()
                case .voice: if let message = voice.release() { status = message }; voiceOpen = voice.latched
                case .airMouse: gyro.resetFilter(); status = "摇杆鼠标模式"
                case .scrollUp, .scrollDown: emitter.resetScroll()
                default: break
                }
            case .tap(let command):
                guard !paused || command.action == .pause else { continue }
                switch command.action {
                case .focusInput: focusInput()
                case .openApplication: openApplication(command)
                case .customShortcut where command.shortcut == nil: status = "请先为这个按键录制快捷键"
                case .pause: togglePause()
                default: emitter.perform(command); if command.action != .none { status = "已发送：\(command.action.title)" }
                }
            }
        }
    }
    func cancelInputs() {
        apply(router.cancel()); voice.cancel(); voiceOpen = false
        emitter.releaseAll(); stick = .zero; gyro.resetFilter(); activeButtons = []
    }
    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastTick; lastTick = now
        if elapsed > 0.2 { cancelInputs() }
        let dt = min(max(0, elapsed), 0.05)
        apply(router.tick(now: now))
        if !paused && !router.voiceHeld && !voice.latched && !gyro.calibrating && emitter.authorized {
            if !router.airMouseHeld {
                let magnitude = min(1, hypot(stick.x, stick.y))
                if magnitude > settings.deadzone {
                    let amount = pow((magnitude-settings.deadzone)/(1-settings.deadzone), 1.6)
                    let gain = settings.pointerSpeed * dt * amount * (router.precisionHeld ? 0.25 : 1)
                    emitter.move(x: stick.x/magnitude*gain, y: -stick.y/magnitude*gain)
                }
            }
            let direction = router.scrollDirection * (settings.invertScroll ? -1 : 1)
            emitter.scroll(y: direction * settings.scrollSpeed * 220 * dt)
        } else { emitter.resetScroll() }
        if now - lastUI > 0.1 {
            lastUI = now
            let trusted = emitter.authorized
            if authorized && !trusted { cancelInputs(); status = "权限已失效，控制已停止" }
            authorized = trusted; updateBattery(); displayStick = stick
            calibrationProgress = gyro.calibrationProgress; calibrating = gyro.calibrating; calibrated = gyro.calibrated
            if calibrating && now - calibrationStarted > 15 { gyro = GyroProcessor(); calibrating = false; status = "未取得稳定传感器样本，请放稳手柄后重试" }
        }
    }
    private func sensor(_ vector: MotionVector) {
        let wasCalibrating = gyro.calibrating
        let motion = gyro.process(vector, dt: 0.005, sensitivity: settings.gyroSensitivity, smoothing: settings.gyroSmoothing)
        if wasCalibrating && !gyro.calibrating { status = "体感静置校准完成" }
        guard router.airMouseHeld, !paused, !router.voiceHeld, !voice.latched, !gyro.calibrating else { return }
        let precision = router.precisionHeld ? 0.25 : 1.0
        let x = motion.x * (settings.invertGyroX ? -1 : 1) * precision
        let y = motion.y * (settings.invertGyroY ? -1 : 1) * precision
        emitter.move(x: x, y: y)
        // A bounded display trace, independent of actual screen coordinates.
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTraceUI > 0.033 {
            lastTraceUI = now
            motionTrace = CGPoint(x: min(1, max(-1, motionTrace.x*0.94+x/35)), y: min(1, max(-1, motionTrace.y*0.94+y/35)))
        }
    }
    private func targetApplication() -> NSRunningApplication? {
        if selectedScope != "global" { return NSRunningApplication.runningApplications(withBundleIdentifier: selectedScope).first }
        guard let pid = lastExternalPID else { return nil }; return NSRunningApplication(processIdentifier: pid)
    }
    func learnInput() {
        guard authorized else { status = "请先开启辅助功能权限"; return }
        guard let app = targetApplication(), let bundle = app.bundleIdentifier else { focusStatus = "请先打开目标应用，并切换到要学习的页面"; return }
        cancelInputs()
        if !settings.profiles.contains(where: { $0.id == bundle }) { settings.profiles.append(AppProfile(id: bundle, name: app.localizedName ?? "应用")) }
        focusStatus = "请在三秒内点击 \(app.localizedName ?? "目标应用") 的输入框"
        app.activate(options: [])
        focus.learn(pid: app.processIdentifier) { [weak self] target, message in
            guard let self else { return }
            if let target, let index = self.settings.profiles.firstIndex(where: { $0.id == bundle }) {
                self.settings.profiles[index].focusTarget = target; self.changedSettings(cancel: false)
            }
            self.focusStatus = message; self.status = message
        }
    }
    func focusInput() {
        guard authorized else { focusStatus = "需要辅助功能权限"; return }
        let app: NSRunningApplication?
        if let front = NSWorkspace.shared.frontmostApplication, front.bundleIdentifier != Bundle.main.bundleIdentifier { app = front }
        else { app = targetApplication(); app?.activate(options: []) }
        guard let app, let bundle = app.bundleIdentifier else { focusStatus = "请先打开目标应用"; return }
        cancelInputs(); focusBusy = true; focusStatus = "正在定位并校验焦点…"
        let profile = settings.profiles.first { $0.id == bundle }
        let completion: (String, Bool) -> Void = { [weak self] message, success in
            self?.focusBusy = false; self?.focusStatus = message; self?.status = message
        }
        focus.cancel()
        let request = UUID(); focusRequest = request
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.focusRequest == request else { return }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier else {
                completion("目标窗口尚未就绪或已切换，请再试一次", false); return
            }
            if let hotkey = profile?.focusShortcut {
                self.emitter.shortcut(hotkey); self.focus.verify(pid: app.processIdentifier, completion: completion)
            } else { self.focus.focus(pid: app.processIdentifier, target: profile?.focusTarget, completion: completion) }
        }
    }
    func setFocusHotkey(_ hotkey: Hotkey?) {
        let bundle = targetBundle
        guard !bundle.isEmpty else { return }
        if !settings.profiles.contains(where: { $0.id == bundle }) { settings.profiles.append(AppProfile(id: bundle, name: targetName)) }
        if let index = settings.profiles.firstIndex(where: { $0.id == bundle }) { settings.profiles[index].focusShortcut = hotkey; changedSettings() }
    }
}
