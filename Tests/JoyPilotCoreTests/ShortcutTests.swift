import XCTest
@testable import JoyPilotCore
final class ShortcutTests: XCTestCase {
    func testControlArrowBalancesModifiers() {
        let events = ShortcutPlan.tap(Hotkey(code: 123, flags: 0x40000, label: "Ctrl Left"))
        XCTAssertEqual(events.map(\.code), [59,123,123,59])
        XCTAssertEqual(events.map(\.down), [true,true,false,false])
        XCTAssertEqual(events.last?.flags, 0)
    }
    func testCommandTabActuallyReleasesCommand() {
        let events = ShortcutPlan.tap(Hotkey(code: 48, flags: 0x100000, label: "Cmd Tab"))
        XCTAssertEqual(events.first?.code, 55)
        XCTAssertEqual(events.last?.code, 55)
        XCTAssertEqual(events.last?.down, false)
        XCTAssertEqual(events.last?.flags, 0)
    }
    func testPhysicalModifierIsPreservedNotReleased() {
        let events = ShortcutPlan.tap(Hotkey(code: 8, flags: 0x100000, label: "Cmd C"), physicalFlags: 0x100000)
        XCTAssertEqual(events.count, 2)
        XCTAssertTrue(events.allSatisfy { !$0.modifier })
        XCTAssertEqual(events.last?.flags, 0x100000)
    }
    func testRightCommandAndFnRemainDistinct() {
        let right = ShortcutPlan.tap(.rightCommand)
        XCTAssertEqual(right.first?.code, 54); XCTAssertEqual(right.first?.flags, 0x100010)
        XCTAssertTrue(right.allSatisfy(\.modifier)); XCTAssertEqual(right.last?.flags, 0)
        let fn = ShortcutPlan.tap(.fn)
        XCTAssertEqual(fn.first?.code, 63); XCTAssertEqual(fn.first?.flags, 0x800000)
    }
}
