// SPDX-License-Identifier: GPL-3.0-only
import Foundation

public struct PlannedKeyEvent: Equatable {
    public let code: UInt16
    public let down: Bool
    public let flags: UInt64
    public let modifier: Bool
}
/// Explicit modifier transitions keep a synthetic shortcut balanced. Modifiers
/// that were already physically held are not virtually pressed or released.
public enum ShortcutPlan {
    public static let modifierCodes: Set<UInt16> = [54,55,56,60,58,61,59,62,63]
    private static let modifierKeys: [(UInt16, UInt64)] = [(59, 0x40000), (58, 0x80000), (56, 0x20000), (55, 0x100000), (63, 0x800000)]
    public static func tap(_ key: Hotkey, physicalFlags: UInt64 = 0) -> [PlannedKeyEvent] {
        if modifierCodes.contains(key.code) {
            return [PlannedKeyEvent(code: key.code, down: true, flags: key.flags | physicalFlags, modifier: true),
                    PlannedKeyEvent(code: key.code, down: false, flags: physicalFlags, modifier: true)]
        }
        var state = physicalFlags
        var added: [(UInt16, UInt64)] = []
        var events: [PlannedKeyEvent] = []
        for (code, flag) in modifierKeys where key.flags & flag != 0 && physicalFlags & flag == 0 {
            state |= flag; added.append((code, flag))
            events.append(PlannedKeyEvent(code: code, down: true, flags: state, modifier: true))
        }
        let requested = state | key.flags
        events.append(PlannedKeyEvent(code: key.code, down: true, flags: requested, modifier: false))
        events.append(PlannedKeyEvent(code: key.code, down: false, flags: requested, modifier: false))
        for (code, flag) in added.reversed() {
            state &= ~flag
            events.append(PlannedKeyEvent(code: code, down: false, flags: state, modifier: true))
        }
        return events
    }
}
