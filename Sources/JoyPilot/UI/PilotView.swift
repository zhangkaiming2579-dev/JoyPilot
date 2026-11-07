// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import AppKit
import JoyPilotCore

enum PilotPalette {
    static let accent = Color(red: 0.38, green: 0.45, blue: 0.96)
    static let background = Color(red: 0.975, green: 0.972, blue: 0.979)
    static let secondary = Color(red: 0.46, green: 0.46, blue: 0.51)
    static let ink = Color(red: 0.15, green: 0.15, blue: 0.18)
}
struct PilotView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 0) {
            header
            scopeBar
            Divider()
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 3) {
                        HStack {
                            Text("按键映射").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Picker("编辑组合层", selection: $model.editingLayer) {
                                ForEach(MappingLayer.allCases) { layer in Text(layer.rawValue).tag(layer) }
                            }.pickerStyle(.segmented).frame(width: 180)
                        }.padding(.horizontal, 20).padding(.top, 18)
                        ControllerCanvas(model: model)
                        HStack(spacing: 8) {
                            Image(systemName: "command").foregroundStyle(PilotPalette.accent)
                            Text("R ＋ X 窗口总览 · R ＋ B 显示桌面 · R ＋ ＋ 退格").font(.system(size: 12))
                            Spacer()
                        }.padding(.horizontal, 24).padding(.bottom, 16)
                    }.frame(maxWidth: .infinity)
                }
                Divider()
                InspectorView(model: model).frame(width: 318)
            }
            Divider()
            footer
        }
        .foregroundStyle(PilotPalette.ink)
        .background(PilotPalette.background)
        .tint(PilotPalette.accent)
        .preferredColorScheme(.light)
        .onChange(of: model.selectedScope) { _, _ in model.select(model.selectedButton) }
        .onChange(of: model.editingLayer) { _, _ in model.select(model.selectedButton) }
    }
    private var header: some View {
        HStack(spacing: 11) {
            Image(systemName: "gamecontroller.fill").font(.system(size: 23)).foregroundStyle(PilotPalette.accent)
            Text("掌控").font(.system(size: 24, weight: .bold))
            Text("JoyPilot").font(.system(size: 19, weight: .medium)).foregroundStyle(PilotPalette.secondary)
            Spacer()
            HStack(spacing: 8) {
                Circle().fill(model.connected ? Color.green : Color.gray).frame(width: 7, height: 7)
                Text(model.connected ? "Joy-Con R · 已连接" : "Joy-Con R · 等待连接").font(.system(size: 13, weight: .medium))
                Text(model.battery).font(.system(size: 13, design: .monospaced)).foregroundStyle(PilotPalette.secondary)
                Image(systemName: model.battery == "100%" ? "battery.100percent" : "battery.50percent").foregroundStyle(model.connected ? Color.green : Color.gray)
            }.padding(.horizontal, 13).padding(.vertical, 9).background(.white.opacity(0.75), in: Capsule()).overlay(Capsule().stroke(.gray.opacity(0.2)))
            Divider().frame(height: 25).padding(.horizontal, 8)
            Toggle("暂停控制", isOn: Binding(get: { model.paused }, set: { _ in model.togglePause() })).toggleStyle(.switch).font(.system(size: 13))
        }.padding(.horizontal, 24).padding(.vertical, 16)
    }
    private var scopeBar: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.settings.profiles) { profile in
                        Button { model.selectedScope = profile.id } label: {
                            HStack(spacing: 7) {
                                if profile.id == "global" { Image(systemName: "globe") }
                                else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: profile.id) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().frame(width: 18, height: 18)
                                }
                                Text(profile.name)
                            }.font(.system(size: 13, weight: model.selectedScope == profile.id ? .semibold : .regular))
                                .padding(.horizontal, 13).padding(.vertical, 8)
                                .background(model.selectedScope == profile.id ? PilotPalette.accent.opacity(0.11) : Color.white.opacity(0.6), in: Capsule())
                                .overlay(Capsule().stroke(model.selectedScope == profile.id ? PilotPalette.accent.opacity(0.6) : Color.gray.opacity(0.2)))
                                .foregroundStyle(model.selectedScope == profile.id ? PilotPalette.accent : PilotPalette.ink)
                        }.buttonStyle(.plain)
                    }
                    Button(action: model.addApplication) { Label("应用", systemImage: "plus").font(.system(size: 13)).padding(.horizontal, 13).padding(.vertical, 8) }.buttonStyle(.plain)
                }
            }
            Spacer(minLength: 12)
            Label(model.saved ? "已自动保存" : "正在保存…", systemImage: model.saved ? "checkmark" : "clock").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
        }.padding(.horizontal, 24).padding(.vertical, 10)
    }
    private var footer: some View {
        HStack(spacing: 9) {
            Circle().fill(model.authorized ? (model.paused ? Color.orange : Color.green) : Color.orange).frame(width: 8, height: 8)
            if !model.authorized {
                Text("需要辅助功能权限").font(.system(size: 13))
                Button("打开设置", action: model.openPermissions).buttonStyle(.link).font(.system(size: 13))
            } else { Text(model.status).font(.system(size: 13)).lineLimit(1) }
            Spacer(minLength: 10)
            Text("当前：\(model.activeScopeName) · \(model.activeLayer.rawValue)").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
        }.padding(.horizontal, 24).padding(.vertical, 12)
    }
}

private struct InspectorView: View {
    @Bindable var model: AppModel
    @State private var showActions = false
    @State private var showTuning = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(model.selectedButton.title).font(.system(size: 23, weight: .bold))
                    Spacer()
                    Button { model.resetSelected() } label: { Image(systemName: "arrow.counterclockwise") }.buttonStyle(.plain).help("恢复这个按键的默认 / 继承配置").accessibilityLabel("恢复选中按键默认值")
                }
                HStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        Button { model.selectedGesture = index; model.selectedGroup = model.visibleAction.group; showActions = model.selectedCommand == nil } label: {
                            Text(index == 0 ? (model.binding.primary.action.isContinuous ? "按住" : "单击") : index == 1 ? "双击" : "长按")
                                .font(.system(size: 13, weight: model.selectedGesture == index ? .semibold : .regular))
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(model.selectedGesture == index ? PilotPalette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(model.selectedGesture == index ? .white : PilotPalette.ink)
                        }.buttonStyle(.plain).disabled(index > 0 && model.binding.primary.action.isContinuous)
                    }
                }.padding(3).background(Color.gray.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                if model.binding.primary.action.isContinuous {
                    Text("连续动作按下立即执行，松开释放。").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                }
                Button { showActions.toggle() } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: model.visibleAction.symbol).font(.system(size: 23)).frame(width: 30)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(model.visibleAction.title).font(.system(size: 16, weight: .semibold))
                            Text(model.visibleAction.detail).font(.system(size: 12)).foregroundStyle(PilotPalette.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: showActions ? "chevron.up" : "chevron.down").font(.system(size: 11)).padding(.top, 5)
                    }.padding(13).frame(maxWidth: .infinity, alignment: .leading)
                        .background(PilotPalette.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(PilotPalette.accent.opacity(0.4)))
                }.buttonStyle(.plain).accessibilityLabel("更改 \(model.selectedButton.title) 的动作")
                if model.editingLayer == .rHeld && model.selectedButton == .r {
                    Text("R 本身的功能请在基础层设置；此层编辑 R 与其他按键的组合。").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                    Button("切回基础层") { model.editingLayer = .base }.font(.system(size: 13))
                }
                if showActions { actionPicker.disabled(model.editingLayer == .rHeld && model.selectedButton == .r) }
                if model.binding.double != nil || model.binding.long != nil {
                    Text("配置双击或长按后，单击会等待判定；默认鼠标与语音连续动作保持即时。").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                }
                if model.selectedGesture == 0 && [.backspace, .tab, .volumeUp, .volumeDown, .customShortcut].contains(model.visibleAction) {
                    Toggle("按住连发（清除双击与长按）", isOn: Binding(get: { model.binding.repeats }, set: model.setRepeat)).font(.system(size: 12))
                }
                if model.visibleAction == .customShortcut {
                    HotkeyRecorder(label: "录制按键快捷键", value: model.selectedCommand?.shortcut, onRecorded: model.setCustomHotkey)
                }
                if model.visibleAction == .openApplication {
                    Button(model.selectedCommand?.applicationName ?? "选择要打开的应用", action: model.chooseApplicationAction).font(.system(size: 13))
                }
                if model.visibleAction == .airMouse || model.visibleAction == .precision { gyroPanel }
                if model.visibleAction == .voice { voicePanel }
                focusPanel
                DisclosureGroup("鼠标与滚动", isExpanded: $showTuning) { tuningPanel.padding(.top, 12) }
                    .font(.system(size: 13, weight: .semibold)).padding(13).background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                if model.visibleAction == .desktopLeft || model.visibleAction == .desktopRight {
                    Button("检查系统键盘快捷键", action: model.openKeyboard).font(.system(size: 13))
                }
                Text(model.selectedScope == "global" ? "编辑全局默认。应用方案可单独覆盖这些设置。" : "编辑 \(model.targetName)。未修改的按键继承全局配置。")
                    .font(.system(size: 12)).foregroundStyle(PilotPalette.secondary).fixedSize(horizontal: false, vertical: true)
            }.padding(20)
        }
        .background(Color.white.opacity(0.38))
        .onChange(of: model.selectedButton) { _, _ in showActions = false }
    }
    private var actionPicker: some View {
        VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(ActionGroup.allCases) { group in
                    Button { model.selectedGroup = group } label: {
                        Text(group.rawValue).font(.system(size: 12, weight: .medium)).padding(.horizontal, 7).padding(.vertical, 6)
                            .background(model.selectedGroup == group ? PilotPalette.accent : Color.gray.opacity(0.07), in: Capsule())
                            .foregroundStyle(model.selectedGroup == group ? .white : PilotPalette.ink)
                    }.buttonStyle(.plain)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                ForEach(PadAction.allCases.filter { $0.group == model.selectedGroup }) { action in
                    Button { model.chooseAction(action); showActions = false } label: {
                        VStack(spacing: 5) {
                            Image(systemName: action.symbol).font(.system(size: 18))
                            Text(action.title).font(.system(size: 12)).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity, minHeight: 57).padding(5)
                            .background(model.visibleAction == action ? PilotPalette.accent.opacity(0.12) : .white, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.15)))
                    }.buttonStyle(.plain)
                        .disabled(model.selectedGesture == 1 && action.isContinuous && action != .leftClick)
                }
            }
        }
    }
    private var gyroPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            slider("体感灵敏度", value: $model.settings.gyroSensitivity, range: 3...40, format: "%.0f")
            slider("平滑", value: $model.settings.gyroSmoothing, range: 0.005...0.15, format: "%.3f")
            HStack { Toggle("反转水平", isOn: $model.settings.invertGyroX); Toggle("反转垂直", isOn: $model.settings.invertGyroY) }.font(.system(size: 12))
            Button(action: model.calibrate) { Label(model.calibrating ? "校准中…请保持静止" : "静置校准", systemImage: "scope") }.font(.system(size: 13)).disabled(model.calibrating)
            if model.calibrating { ProgressView(value: model.calibrationProgress) }
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(PilotPalette.accent.opacity(0.045))
                Path { p in p.move(to: CGPoint(x: 30, y: 53)); p.addCurve(to: CGPoint(x: 230, y: 33), control1: CGPoint(x: 105, y: 68), control2: CGPoint(x: 130, y: 16)) }.stroke(PilotPalette.accent.opacity(0.3), lineWidth: 4)
                Image(systemName: "cursorarrow").font(.system(size: 25)).offset(x: model.motionTrace.x*80, y: model.motionTrace.y*25)
            }.frame(height: 84)
            Text(model.calibrated ? "本次启动已校准" : "首次使用建议放稳手柄进行校准").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
        }
        .onChange(of: model.settings.gyroSensitivity) { _, _ in model.changedSettings(cancel: false) }
        .onChange(of: model.settings.gyroSmoothing) { _, _ in model.changedSettings(cancel: false) }
        .onChange(of: model.settings.invertGyroX) { _, _ in model.changedSettings() }
        .onChange(of: model.settings.invertGyroY) { _, _ in model.changedSettings() }
    }
    private var voicePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("语音工具").font(.system(size: 14, weight: .semibold))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(VoiceProvider.allCases) { provider in
                    Button { model.chooseVoiceProvider(provider) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(provider.rawValue).font(.system(size: 12, weight: .medium))
                            Text(provider == .custom ? "自行录制快捷键" : model.installedVoiceProviders.contains(provider) ? "已检测到" : "未检测到").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(9)
                            .background(model.settings.voice.provider == provider ? PilotPalette.accent.opacity(0.11) : .white, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }
            }
            ForEach(VoiceGesture.allCases) { gesture in
                Button { model.settings.voice.gesture = gesture; model.changedSettings() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: model.settings.voice.gesture == gesture ? "largecircle.fill.circle" : "circle")
                        Text(gesture.rawValue).font(.system(size: 12))
                        Spacer()
                    }
                }.buttonStyle(.plain)
            }
            HotkeyRecorder(label: "录制语音触发快捷键", value: model.settings.voice.shortcut) { model.settings.voice.shortcut = $0; model.changedSettings() }
            Text("请在输入工具内设置相同快捷键。只有豆包右 Command 路线已有本机测试；其他工具需要试用确认。麦克风在系统或输入工具中选择。").font(.system(size: 12)).foregroundStyle(PilotPalette.secondary).fixedSize(horizontal: false, vertical: true)
            Button("声音输入设置", action: model.openSound).font(.system(size: 13))
        }
    }
    private var focusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Home 输入框定位", systemImage: "house").font(.system(size: 15, weight: .semibold))
            HStack { Text("目标应用").foregroundStyle(PilotPalette.secondary); Spacer(); Text(model.targetName).lineLimit(1) }.font(.system(size: 13))
            HStack(spacing: 7) {
                Button("学习输入框", action: model.learnInput).buttonStyle(.borderedProminent)
                Button("测试定位", action: model.focusInput).buttonStyle(.bordered).disabled(model.focusBusy)
            }.font(.system(size: 13))
            Text(model.focusStatus).font(.system(size: 12)).foregroundStyle(PilotPalette.secondary).fixedSize(horizontal: false, vertical: true)
            if model.hasLearnedTarget { Label("已记录目标控件", systemImage: "checkmark.circle").font(.system(size: 12)).foregroundStyle(.green) }
            HotkeyRecorder(label: "可选：录制聚焦输入框快捷键", value: model.targetProfile?.focusShortcut, onRecorded: model.setFocusHotkey)
            if model.targetProfile?.focusShortcut != nil { Button("清除聚焦快捷键") { model.setFocusHotkey(nil) }.buttonStyle(.link).font(.system(size: 12)) }
        }.padding(13).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.17)))
    }
    private var tuningPanel: some View {
        VStack(spacing: 13) {
            slider("鼠标速度", value: $model.settings.pointerSpeed, range: 100...1600, format: "%.0f")
            slider("滚动速度", value: $model.settings.scrollSpeed, range: 0.05...4, format: "%.2f")
            slider("摇杆死区", value: $model.settings.deadzone, range: 0.03...0.3, format: "%.2f")
            Toggle("反转上下滚动", isOn: $model.settings.invertScroll).font(.system(size: 13))
        }
        .onChange(of: model.settings.pointerSpeed) { _, _ in model.changedSettings(cancel: false) }
        .onChange(of: model.settings.scrollSpeed) { _, _ in model.changedSettings(cancel: false) }
        .onChange(of: model.settings.deadzone) { _, _ in model.changedSettings(cancel: false) }
        .onChange(of: model.settings.invertScroll) { _, _ in model.changedSettings() }
    }
    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(spacing: 5) {
            HStack { Text(title); Spacer(); Text(String(format: format, value.wrappedValue)).monospacedDigit().foregroundStyle(PilotPalette.secondary) }.font(.system(size: 12))
            Slider(value: value, in: range).accessibilityLabel(title)
        }
    }
}
