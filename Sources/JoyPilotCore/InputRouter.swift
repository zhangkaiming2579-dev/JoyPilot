// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public enum InputEffect: Equatable {
    case begin(Command), end(Command), tap(Command)
}
/// Bindings are captured on press. Changes to app, profile or permissions must
/// cancel() before replacing the context. Duplicate HID edges are ignored.
public struct InputRouter {
    private struct Press {
        var binding: ButtonBinding
        var start: Double
        var second: Bool
        var longFired = false
        var active: Command?
        var repeatNext: Double?
    }
    private struct Pending { var binding: ButtonBinding; var deadline: Double }
    private var presses: [PadButton: Press] = [:]
    private var pending: [PadButton: Pending] = [:]
    private var counts: [Command: Int] = [:]
    public private(set) var held = Set<PadButton>()
    public var voiceHeld: Bool { counts.keys.contains { $0.action == .voice } }
    public var airMouseHeld: Bool { counts.keys.contains { $0.action == .airMouse } }
    public var precisionHeld: Bool { counts.keys.contains { $0.action == .precision } }
    public var scrollDirection: Double {
        guard !voiceHeld else { return 0 }
        return (counts.keys.contains { $0.action == .scrollUp } ? 1 : 0) - (counts.keys.contains { $0.action == .scrollDown } ? 1 : 0)
    }
    public init() {}
    private mutating func begin(_ command: Command) -> [InputEffect] {
        let count = counts[command, default: 0]
        counts[command] = count + 1
        return count == 0 ? [.begin(command)] : []
    }
    private mutating func end(_ command: Command) -> [InputEffect] {
        guard let count = counts[command] else { return [] }
        if count > 1 { counts[command] = count - 1; return [] }
        counts.removeValue(forKey: command)
        return [.end(command)]
    }
    public mutating func press(_ button: PadButton, binding: ButtonBinding, now: Double) -> [InputEffect] {
        guard held.insert(button).inserted else { return [] }
        if voiceHeld && binding.primary.action != .pause { return [] }
        var output: [InputEffect] = []
        if binding.primary.action == .voice {
            for command in counts.keys { output.append(.end(command)) }
            counts.removeAll(); presses.removeAll(); pending.removeAll()
        }
        let second = pending[button].map { now <= $0.deadline } ?? false
        if let old = pending.removeValue(forKey: button), !second { output.append(.tap(old.binding.primary)) }
        var press = Press(binding: binding, start: now, second: second)
        if binding.primary.action.isContinuous {
            press.active = binding.primary
            output += begin(binding.primary)
        } else if binding.double == nil && binding.long == nil {
            output.append(.tap(binding.primary))
            press.longFired = true
            if binding.repeats { press.repeatNext = now + 0.35 }
        }
        presses[button] = press
        return output
    }
    public mutating func release(_ button: PadButton, now: Double) -> [InputEffect] {
        guard held.remove(button) != nil, let press = presses.removeValue(forKey: button) else { return [] }
        if let active = press.active { return end(active) }
        if press.longFired { return [] }
        if press.second, let command = press.binding.double { return [.tap(command)] }
        if press.binding.double != nil { pending[button] = Pending(binding: press.binding, deadline: now + 0.26); return [] }
        return [.tap(press.binding.primary)]
    }
    public mutating func tick(now: Double) -> [InputEffect] {
        var effects: [InputEffect] = []
        for button in Array(pending.keys) {
            if let value = pending[button], now >= value.deadline {
                pending.removeValue(forKey: button); effects.append(.tap(value.binding.primary))
            }
        }
        for button in Array(presses.keys) {
            if var repeating = presses[button], let next = repeating.repeatNext, now >= next {
                effects.append(.tap(repeating.binding.primary))
                repeating.repeatNext = now + 0.1
                presses[button] = repeating
            }
            guard var press = presses[button], press.active == nil, !press.longFired,
                  now - press.start >= 0.5, let long = press.binding.long else { continue }
            press.longFired = true
            if long.action.isContinuous { press.active = long; effects += begin(long) }
            else { effects.append(.tap(long)) }
            presses[button] = press
        }
        return effects
    }
    public mutating func cancel() -> [InputEffect] {
        let output = counts.keys.map { InputEffect.end($0) }
        counts.removeAll(); presses.removeAll(); pending.removeAll(); held.removeAll()
        return output
    }
}

/// Separate pixel remainders per axis. Integer wheel events never discard the
/// fractional motion; stop/reverse resets prevent delayed movement afterwards.
public struct FractionalAxis {
    public private(set) var remainder = 0.0
    private var direction = 0.0
    public init() {}
    public mutating func consume(_ delta: Double) -> Int32 {
        guard delta.isFinite, abs(delta) < 1_000_000 else { reset(); return 0 }
        if delta == 0 { reset(); return 0 }
        let sign = delta > 0 ? 1.0 : -1.0
        if direction != sign { remainder = 0; direction = sign }
        remainder += delta
        let whole = remainder.rounded(.towardZero)
        remainder -= whole
        return Int32(whole)
    }
    public mutating func reset() { remainder = 0; direction = 0 }
}

public struct MotionVector: Equatable {
    public var x: Double; public var y: Double; public var z: Double
    public init(_ x: Double = 0, _ y: Double = 0, _ z: Double = 0) { self.x = x; self.y = y; self.z = z }
}
/// Gyro-only relative pointer with stationary zero-bias calibration. Joystick
/// movement and gyro movement are arbitrated by the host, never blindly added.
public struct GyroProcessor {
    public private(set) var bias = MotionVector()
    public private(set) var calibrationProgress = 0.0
    public private(set) var calibrating = false
    public private(set) var calibrated = false
    private var samples: [MotionVector] = []
    private var filtered = MotionVector()
    public init() {}
    public mutating func startCalibration() { calibrating = true; calibrationProgress = 0; samples = []; filtered = MotionVector() }
    public mutating func resetFilter() { filtered = MotionVector() }
    public mutating func process(_ raw: MotionVector, dt: Double, sensitivity: Double, smoothing: Double) -> (x: Double, y: Double) {
        guard raw.x.isFinite, raw.y.isFinite, raw.z.isFinite, dt > 0, dt <= 0.05 else { resetFilter(); return (0, 0) }
        if calibrating {
            // Discard moving batches instead of learning hand movement as bias.
            if max(abs(raw.x), abs(raw.y), abs(raw.z)) > 8 {
                samples.removeAll(); calibrationProgress = 0; return (0, 0)
            }
            samples.append(raw)
            calibrationProgress = min(1, Double(samples.count) / 300)
            if samples.count >= 300 {
                let n = Double(samples.count)
                bias = MotionVector(samples.reduce(0) { $0 + $1.x } / n, samples.reduce(0) { $0 + $1.y } / n, samples.reduce(0) { $0 + $1.z } / n)
                calibrating = false; calibrated = true; samples.removeAll()
            }
            return (0, 0)
        }
        let alpha = 1 - exp(-dt / max(0.001, smoothing))
        filtered.x += alpha * (raw.x - bias.x - filtered.x)
        filtered.z += alpha * (raw.z - bias.z - filtered.z)
        func suppress(_ rate: Double) -> Double { abs(rate) < 0.35 ? 0 : rate - (rate > 0 ? 0.35 : -0.35) }
        // Default upright right-hand grip: Z yaw controls horizontal, X pitch vertical.
        return (-suppress(filtered.z) * dt * sensitivity, -suppress(filtered.x) * dt * sensitivity)
    }
}
