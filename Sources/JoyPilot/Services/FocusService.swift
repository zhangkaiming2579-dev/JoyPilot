// SPDX-License-Identifier: GPL-3.0-only
import AppKit
import ApplicationServices
import JoyPilotCore

final class FocusService {
    private struct Candidate { let element: AXUIElement; let target: FocusTarget; let score: Double }
    private let queue = DispatchQueue(label: "JoyPilot.focus", qos: .userInitiated)
    private let lock = NSLock()
    private var generation = UUID()
    func cancel() { lock.lock(); generation = UUID(); lock.unlock() }
    private func current(_ token: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; return generation == token }
    private func begin() -> UUID { lock.lock(); defer { lock.unlock() }; let token = UUID(); generation = token; return token }

    func focus(pid: pid_t, target: FocusTarget?, completion: @escaping (String, Bool) -> Void) {
        let token = begin()
        queue.async { [weak self] in
            guard let self else { return }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.1)
            let declared = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            if declared == .attributeUnsupported {
                _ = AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            }
            var failure = "未找到输入框，请先为这个应用学习输入框"
            let deadline = Date().addingTimeInterval(3)
            repeat {
                guard self.current(token) else { return }
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
                    self.finish(token, "目标应用已切换，已取消定位", false, completion); return
                }
                if let window = self.element(app, kAXFocusedWindowAttribute) {
                    let candidates = self.scan(window, learned: target, token: token)
                    if let best = candidates.first, target == nil || best.score >= 80 {
                        let set = AXUIElementSetAttributeValue(best.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                        if set == .success {
                            for _ in 0..<3 {
                                if let focused = self.element(app, kAXFocusedUIElementAttribute), self.sameControl(focused, best.element) {
                                    self.finish(token, "输入框已获得焦点", true, completion); return
                                }
                                Thread.sleep(forTimeInterval: 0.04)
                            }
                            failure = "已请求聚焦，但未确认焦点；请重新学习输入框"
                        }
                    } else if target != nil { failure = "已学习的输入框未匹配，请切到对应页面或重新学习" }
                }
                Thread.sleep(forTimeInterval: 0.15)
            } while Date() < deadline && self.current(token)
            self.finish(token, failure, false, completion)
        }
    }
    func verify(pid: pid_t, completion: @escaping (String, Bool) -> Void) {
        let token = begin()
        queue.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, self.current(token) else { return }
            let app = AXUIElementCreateApplication(pid)
            let good = NSWorkspace.shared.frontmostApplication?.processIdentifier == pid && self.element(app, kAXFocusedUIElementAttribute).map { self.isEditable($0) } == true
            self.finish(token, good ? "输入框已获得焦点" : "快捷键已发送，但未确认输入框焦点", good, completion)
        }
    }
    func learn(pid: pid_t, completion: @escaping (FocusTarget?, String) -> Void) {
        let token = begin()
        queue.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.current(token) else { return }
            let app = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(app, 0.15)
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid,
                  let focused = self.element(app, kAXFocusedUIElementAttribute), self.isEditable(focused),
                  let window = self.element(app, kAXFocusedWindowAttribute), let windowFrame = self.frame(window),
                  let learned = self.snapshot(focused, window: windowFrame) else {
                DispatchQueue.main.async { if self.current(token) { completion(nil, "未捕获可编辑输入框，请点进目标输入框后重试") } }; return
            }
            DispatchQueue.main.async { if self.current(token) { completion(learned, "已学习输入框；按 Home 可定位") } }
        }
    }
    private func finish(_ token: UUID, _ message: String, _ success: Bool, _ completion: @escaping (String, Bool) -> Void) {
        DispatchQueue.main.async { [weak self] in if self?.current(token) == true { completion(message, success) } }
    }
    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func element(_ object: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(object, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    private func string(_ object: AXUIElement, _ name: String) -> String { attribute(object, name) as? String ?? "" }
    private func frame(_ object: AXUIElement) -> CGRect? {
        guard let p = attribute(object, kAXPositionAttribute), let s = attribute(object, kAXSizeAttribute), CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &point), AXValueGetValue(s as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: point, size: size)
    }
    private func isEditable(_ object: AXUIElement) -> Bool {
        let role = string(object, kAXRoleAttribute), subrole = string(object, kAXSubroleAttribute)
        guard [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole].contains(role), subrole != kAXSecureTextFieldSubrole,
              (attribute(object, kAXEnabledAttribute) as? Bool) != false else { return false }
        let semantic = (string(object, kAXIdentifierAttribute) + " " + string(object, "AXPlaceholderValue")).lowercased()
        guard !["omnibox", "urlbar", "地址栏", "address and search"].contains(where: { semantic.contains($0) }) else { return false }
        var value = DarwinBoolean(false), selection = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(object, kAXValueAttribute as CFString, &value)
        AXUIElementIsAttributeSettable(object, kAXSelectedTextRangeAttribute as CFString, &selection)
        return value.boolValue || selection.boolValue || (attribute(object, "AXEditable") as? Bool) == true
    }
    private func snapshot(_ object: AXUIElement, window: CGRect) -> FocusTarget? {
        guard let rect = frame(object), window.width > 0, window.height > 0 else { return nil }
        var ancestors: [String] = [], parent = element(object, kAXParentAttribute)
        for _ in 0..<4 {
            guard let current = parent else { break }
            ancestors.append(string(current, kAXRoleAttribute) + ":" + string(current, kAXIdentifierAttribute))
            parent = element(current, kAXParentAttribute)
        }
        return FocusTarget(role: string(object, kAXRoleAttribute), identifier: string(object, kAXIdentifierAttribute),
                           placeholder: string(object, "AXPlaceholderValue"), ancestors: ancestors,
                           x: (rect.minX-window.minX)/window.width, y: (rect.minY-window.minY)/window.height,
                           width: rect.width/window.width, height: rect.height/window.height)
    }
    private func scan(_ window: AXUIElement, learned: FocusTarget?, token: UUID) -> [Candidate] {
        guard let bounds = frame(window) else { return [] }
        var pending: [AXUIElement] = [window], cursor = 0, visited = Set<CFHashCode>(), found: [Candidate] = []
        let deadline = Date().addingTimeInterval(0.7)
        while cursor < pending.count && cursor < 4000 && Date() < deadline && current(token) {
            let item = pending[cursor]; cursor += 1
            guard visited.insert(CFHash(item)).inserted else { continue }
            if isEditable(item), let snapshot = snapshot(item, window: bounds) {
                var score = snapshot.role == kAXTextAreaRole ? 30.0 : 10.0
                let semantics = (snapshot.identifier + " " + snapshot.placeholder).lowercased()
                if ["message", "prompt", "chat", "消息", "发送", "聊天"].contains(where: { semantics.contains($0) }) { score += 25 }
                score += snapshot.y * 5
                if let learned {
                    guard snapshot.role == learned.role else { continue }
                    score = 25
                    if !learned.identifier.isEmpty && snapshot.identifier == learned.identifier { score += 80 }
                    if !learned.placeholder.isEmpty && snapshot.placeholder == learned.placeholder { score += 35 }
                    if !learned.ancestors.isEmpty && snapshot.ancestors == learned.ancestors { score += 30 }
                    let distance = hypot(snapshot.x-learned.x, snapshot.y-learned.y)
                    if distance < 0.12 { score += 25 }
                    if abs(snapshot.width-learned.width) < 0.12 { score += 10 }
                }
                found.append(Candidate(element: item, target: snapshot, score: score))
            }
            if let children = attribute(item, kAXChildrenAttribute) as? [AXUIElement] { pending += children }
        }
        return found.sorted { $0.score > $1.score }
    }
    private func sameControl(_ first: AXUIElement, _ second: AXUIElement) -> Bool {
        if CFEqual(first, second) { return isEditable(first) }
        guard isEditable(first), let a = frame(first), let b = frame(second) else { return false }
        return abs(a.minX-b.minX) < 3 && abs(a.minY-b.minY) < 3 && abs(a.width-b.width) < 3 && abs(a.height-b.height) < 3
    }
}
