// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import AppKit
import JoyPilotCore

struct HotkeyRecorder: View {
    let label: String
    let value: Hotkey?
    let onRecorded: (Hotkey) -> Void
    @State private var recording = false
    var body: some View {
        Button { recording.toggle() } label: {
            HStack {
                Image(systemName: recording ? "record.circle" : "keyboard")
                Text(recording ? "按快捷键，Esc 取消…" : value?.label ?? label).font(.system(size: 13))
                Spacer(minLength: 0)
            }.padding(10).frame(maxWidth: .infinity)
                .background(recording ? PilotPalette.accent.opacity(0.12) : Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(recording ? PilotPalette.accent : Color.gray.opacity(0.25)))
        }
        .buttonStyle(.plain).accessibilityLabel(label)
        .background(KeyMonitor(active: recording, onFinish: { hotkey in recording = false; if let hotkey { onRecorded(hotkey) } }).frame(width: 0, height: 0))
    }
}
private struct KeyMonitor: NSViewRepresentable {
    let active: Bool
    let onFinish: (Hotkey?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) { context.coordinator.update(active: active, completion: onFinish) }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }
    final class Coordinator {
        private var monitor: Any?
        private var candidate: Hotkey?
        private var completion: ((Hotkey?) -> Void)?
        func update(active: Bool, completion: @escaping (Hotkey?) -> Void) {
            self.completion = completion
            if !active { stop(); return }
            guard monitor == nil else { return }
            candidate = nil
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                guard let self else { return event }
                if event.type == .keyDown {
                    if event.keyCode == 53 { self.finish(nil) }
                    else { self.finish(self.hotkey(event)) }
                    return nil
                }
                let generic: NSEvent.ModifierFlags
                switch event.keyCode {
                case 54,55: generic = .command
                case 56,60: generic = .shift
                case 58,61: generic = .option
                case 59,62: generic = .control
                case 63: generic = .function
                default: return event
                }
                if event.modifierFlags.contains(generic) { self.candidate = self.hotkey(event) }
                else if let candidate = self.candidate, candidate.code == event.keyCode { self.finish(candidate) }
                return nil
            }
        }
        private func hotkey(_ event: NSEvent) -> Hotkey {
            let flags = event.modifierFlags.intersection([.command, .shift, .control, .option, .function]).rawValue
            if event.keyCode == 54 { return .rightCommand }
            if event.keyCode == 63 { return .fn }
            let modifierNames: [UInt16: String] = [55: "左 Command", 56: "左 Shift", 60: "右 Shift", 58: "左 Option", 61: "右 Option", 59: "左 Control", 62: "右 Control"]
            if let name = modifierNames[event.keyCode] { return Hotkey(code: event.keyCode, flags: UInt64(flags), label: name) }
            var label = ""
            if event.modifierFlags.contains(.control) { label += "⌃" }
            if event.modifierFlags.contains(.option) { label += "⌥" }
            if event.modifierFlags.contains(.shift) { label += "⇧" }
            if event.modifierFlags.contains(.command) { label += "⌘" }
            let names: [UInt16:String] = [36:"Return",48:"Tab",49:"Space",51:"Delete",123:"←",124:"→",125:"↓",126:"↑"]
            label += names[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "键 \(event.keyCode)"
            return Hotkey(code: event.keyCode, flags: UInt64(flags), label: label)
        }
        private func finish(_ result: Hotkey?) { let action = completion; stop(); DispatchQueue.main.async { action?(result) } }
        func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil; candidate = nil }
        deinit { stop() }
    }
}
