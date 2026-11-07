// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import Carbon.HIToolbox
import JoyPilotCore

final class EventEmitter {
    private let source = CGEventSource(stateID: .privateState)
    private(set) var dragging = false
    private var lastClick = 0.0
    private var lastClickPoint = CGPoint.zero
    private var clickCount: Int64 = 1
    private var scrollX = FractionalAxis()
    private var scrollY = FractionalAxis()
    private var heldKeys: [Hotkey: UInt64] = [:]
    static let marker: Int64 = 0x4A4F5950494C4F54
    var authorized: Bool { AXIsProcessTrusted() }

    private func post(_ event: CGEvent?) {
        guard authorized, let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cghidEventTap)
    }
    func mouseDown() {
        guard authorized, !dragging, let point = CGEvent(source: source)?.location else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastClick < NSEvent.doubleClickInterval && hypot(point.x-lastClickPoint.x, point.y-lastClickPoint.y) < 5 { clickCount = clickCount == 2 ? 1 : 2 }
        else { clickCount = 1 }
        lastClick = now; lastClickPoint = point
        let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        post(event); dragging = true
    }
    func mouseUp() {
        guard dragging else { return }
        dragging = false
        guard let point = CGEvent(source: source)?.location else { return }
        let event = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventClickState, value: clickCount)
        post(event)
    }
    func clickRight() {
        guard let point = CGEvent(source: source)?.location else { return }
        post(CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right))
        post(CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right))
    }
    func move(x: Double, y: Double) {
        guard authorized, x.isFinite, y.isFinite, abs(x)+abs(y) > 0, let current = CGEvent(source: source)?.location else { return }
        let proposed = CGPoint(x: current.x + x, y: current.y + y)
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(32, &ids, &count) == .success else { return }
        let bounds = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
        var point = proposed
        if !bounds.contains(where: { $0.contains(proposed) }) {
            let candidates = bounds.map { CGRect in CGPoint(x: min(max(proposed.x, CGRect.minX), CGRect.maxX - 1), y: min(max(proposed.y, CGRect.minY), CGRect.maxY - 1)) }
            if let nearest = candidates.min(by: { hypot($0.x-proposed.x, $0.y-proposed.y) < hypot($1.x-proposed.x, $1.y-proposed.y) }) { point = nearest }
        }
        let event = CGEvent(mouseEventSource: source, mouseType: dragging ? .leftMouseDragged : .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.setIntegerValueField(.mouseEventDeltaX, value: Int64(x.rounded()))
        event?.setIntegerValueField(.mouseEventDeltaY, value: Int64(y.rounded()))
        post(event)
    }
    func scroll(x: Double = 0, y: Double) {
        let dx = scrollX.consume(x), dy = scrollY.consume(y)
        guard dx != 0 || dy != 0 else { return }
        post(CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0))
    }
    func resetScroll() { scrollX.reset(); scrollY.reset() }
    private func keyEvent(_ hotkey: Hotkey, down: Bool) -> CGEvent? {
        let event = CGEvent(keyboardEventSource: source, virtualKey: hotkey.code, keyDown: down)
        if [54,55,56,60,58,61,59,62,63].contains(Int(hotkey.code)) { event?.type = .flagsChanged }
        event?.flags = down ? CGEventFlags(rawValue: hotkey.flags) : []
        return event
    }
    func hold(_ hotkey: Hotkey) {
        guard authorized, heldKeys[hotkey] == nil else { return }
        let physical = CGEventSource.flagsState(.hidSystemState).rawValue
        heldKeys[hotkey] = physical
        let event = keyEvent(hotkey, down: true)
        event?.flags = CGEventFlags(rawValue: physical | hotkey.flags)
        post(event)
    }
    func release(_ hotkey: Hotkey) {
        guard let physical = heldKeys.removeValue(forKey: hotkey) else { return }
        let event = keyEvent(hotkey, down: false)
        event?.flags = CGEventFlags(rawValue: physical)
        post(event)
    }
    func shortcut(_ hotkey: Hotkey) {
        let physical = CGEventSource.flagsState(.hidSystemState).rawValue
        for planned in ShortcutPlan.tap(hotkey, physicalFlags: physical) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: planned.code, keyDown: planned.down)
            if planned.modifier { event?.type = .flagsChanged }
            event?.flags = CGEventFlags(rawValue: planned.flags)
            post(event)
        }
    }
    func key(_ code: UInt16, flags: CGEventFlags = []) { shortcut(Hotkey(code: code, flags: flags.rawValue, label: "")) }
    func releaseAll() {
        mouseUp()
        for key in Array(heldKeys.keys) { release(key) }
        resetScroll()
    }
    // Media event format follows the public SayAll KeyboardInjector system-key
    // implementation (GPL-3.0-only); see THIRD_PARTY_NOTICES.md.
    private func mediaKey(_ code: Int) {
        for phase in [0xA, 0xB] {
            let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: 0, context: nil,
                subtype: 8, data1: (code << 16) | (phase << 8), data2: -1)
            post(event?.cgEvent)
        }
    }
    func perform(_ command: Command) {
        switch command.action {
        case .leftClick: mouseDown(); mouseUp()
        case .rightClick: clickRight()
        case .enter: key(36)
        case .commandEnter: key(36, flags: .maskCommand)
        case .shiftEnter: key(36, flags: .maskShift)
        case .backspace: key(51)
        case .escape: key(53)
        case .tab: key(48)
        case .copy: key(8, flags: .maskCommand)
        case .paste: key(9, flags: .maskCommand)
        case .desktopLeft: key(123, flags: .maskControl)
        case .desktopRight: key(124, flags: .maskControl)
        case .missionControl: key(126, flags: .maskControl)
        case .showDesktop: key(103, flags: .maskSecondaryFn)
        case .appSwitcher: key(48, flags: .maskCommand)
        case .previousTab: key(33, flags: [.maskCommand, .maskShift])
        case .nextTab: key(30, flags: [.maskCommand, .maskShift])
        case .customShortcut: if let shortcut = command.shortcut { self.shortcut(shortcut) }
        case .volumeUp: mediaKey(0)
        case .volumeDown: mediaKey(1)
        case .mute: mediaKey(7)
        case .playPause: mediaKey(16)
        default: break
        }
    }
}
