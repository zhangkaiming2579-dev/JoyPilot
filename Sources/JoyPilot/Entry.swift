// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import SwiftUI

@MainActor final class PilotAppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1240, height: 850), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "掌控 JoyPilot"
        window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 1180, height: 790)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PilotView(model: model))
        window.center()
        showWindow()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "掌控 JoyPilot")
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开掌控", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "暂停 / 恢复控制", action: #selector(pause), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "学习当前输入框（三秒后）", action: #selector(learn), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "静置校准体感", action: #selector(calibrate), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出掌控", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        model.start()
    }
    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(), app = NSMenu()
        app.addItem(NSMenuItem(title: "关于掌控 JoyPilot", action: #selector(about), keyEquivalent: ""))
        app.addItem(NSMenuItem(title: "打开设置", action: #selector(showWindow), keyEquivalent: ","))
        app.addItem(NSMenuItem(title: "暂停 / 恢复控制", action: #selector(pause), keyEquivalent: "p"))
        app.addItem(.separator())
        app.addItem(NSMenuItem(title: "退出掌控", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = app; main.addItem(appItem)
        let editItem = NSMenuItem(), edit = NSMenu(title: "编辑")
        edit.addItem(NSMenuItem(title: "撤销", action: Selector(("undo:")), keyEquivalent: "z"))
        edit.addItem(NSMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        edit.addItem(NSMenuItem(title: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        edit.addItem(NSMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        edit.addItem(NSMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = edit; main.addItem(editItem)
        NSApp.mainMenu = main
    }
    @objc private func showWindow() { window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func pause() { model.togglePause() }
    @objc private func learn() { model.learnInput() }
    @objc private func calibrate() { model.calibrate() }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "掌控 JoyPilot 0.1.0"
        alert.informativeText = "右手柄、摇杆鼠标、体感指向与语音工具桥接。\n\n交互和适配思路参考无线麦 SayAll（HD838A/remote-mic-app，GPL-3.0-only）。\n硬件通信使用 JoyConSwift（magicien，MIT），沿用 Berrry Joyful 的校准与对齐修复版本。\n\n本应用不采集录音；语音由你选择的输入工具处理。"
        alert.addButton(withTitle: "好"); alert.runModal()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { showWindow(); return true }
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
}
@main struct JoyPilotEntry {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = PilotAppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
