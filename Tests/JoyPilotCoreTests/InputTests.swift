import XCTest
@testable import JoyPilotCore

final class InputTests: XCTestCase {
    func testLowSpeedScrollDoesNotDisappear() {
        for speed in [0.1, 0.25, 0.5, 0.75] {
            var axis = FractionalAxis()
            let result = (0..<120).reduce(Int32(0)) { sum, _ in sum + axis.consume(speed * 220 / 120) }
            XCTAssertEqual(Double(result) + axis.remainder, speed * 220, accuracy: 0.00001)
            XCTAssertGreaterThan(result, 0)
        }
    }
    func testScrollIndependentOfFrameRate() {
        var totals: [Int32] = []
        for fps in [60, 120, 200] {
            var axis = FractionalAxis()
            totals.append((0..<fps).reduce(Int32(0)) { sum, _ in sum + axis.consume(0.37 * 220 / Double(fps)) })
        }
        XCTAssertLessThanOrEqual((totals.max() ?? 0) - (totals.min() ?? 0), 1)
    }
    func testScrollStopReverseAndInvalidInput() {
        var axis = FractionalAxis()
        XCTAssertEqual(axis.consume(0.8), 0)
        XCTAssertEqual(axis.consume(-0.4), 0)
        XCTAssertEqual(axis.remainder, -0.4, accuracy: 0.0001)
        XCTAssertEqual(axis.consume(0), 0); XCTAssertEqual(axis.remainder, 0)
        XCTAssertEqual(axis.consume(.nan), 0)
    }
    func testSharedDragAndDuplicateHIDReports() {
        var router = InputRouter()
        XCTAssertEqual(router.press(.y, binding: ButtonBinding(.leftClick), now: 0), [.begin(Command(.leftClick))])
        XCTAssertTrue(router.press(.y, binding: ButtonBinding(.enter), now: 0.01).isEmpty)
        XCTAssertTrue(router.press(.a, binding: ButtonBinding(.leftClick), now: 0.02).isEmpty)
        XCTAssertTrue(router.release(.y, now: 0.1).isEmpty)
        XCTAssertEqual(router.release(.a, now: 0.2), [.end(Command(.leftClick))])
        XCTAssertTrue(router.release(.a, now: 0.3).isEmpty)
    }
    func testVoiceCleansDragAndSuppressesShortcutChords() {
        var router = InputRouter()
        _ = router.press(.y, binding: ButtonBinding(.leftClick), now: 0)
        _ = router.press(.r, binding: ButtonBinding(.airMouse), now: 0)
        let voice = router.press(.zr, binding: ButtonBinding(.voice), now: 0.1)
        XCTAssertTrue(voice.contains(.end(Command(.leftClick))))
        XCTAssertTrue(voice.contains(.end(Command(.airMouse))))
        XCTAssertTrue(voice.contains(.begin(Command(.voice))))
        XCTAssertTrue(router.press(.plus, binding: ButtonBinding(.enter), now: 0.2).isEmpty)
        XCTAssertEqual(router.release(.zr, now: 0.3), [.end(Command(.voice))])
        XCTAssertFalse(router.airMouseHeld)
    }
    func testCancelDropsPendingGesturesAndReleasesHeldKeys() {
        var router = InputRouter(), binding = ButtonBinding(.enter)
        binding.double = Command(.backspace)
        _ = router.press(.plus, binding: binding, now: 0)
        _ = router.release(.plus, now: 0.1)
        _ = router.press(.zr, binding: ButtonBinding(.voice), now: 0.2)
        XCTAssertEqual(router.cancel(), [.end(Command(.voice))])
        XCTAssertTrue(router.tick(now: 10).isEmpty)
        XCTAssertTrue(router.held.isEmpty)
    }
    func testDoubleClickOnlyFiresDoubleAction() {
        var router = InputRouter(), binding = ButtonBinding(.enter)
        binding.double = Command(.backspace)
        XCTAssertTrue(router.press(.plus, binding: binding, now: 0).isEmpty)
        XCTAssertTrue(router.release(.plus, now: 0.05).isEmpty)
        XCTAssertTrue(router.press(.plus, binding: binding, now: 0.15).isEmpty)
        XCTAssertEqual(router.release(.plus, now: 0.2), [.tap(Command(.backspace))])
        XCTAssertTrue(router.tick(now: 1).isEmpty)
    }
    func testSingleAndLongPressTiming() {
        var router = InputRouter(), binding = ButtonBinding(.enter)
        binding.double = Command(.backspace); binding.long = Command(.copy)
        _ = router.press(.plus, binding: binding, now: 0)
        _ = router.release(.plus, now: 0.1)
        XCTAssertTrue(router.tick(now: 0.2).isEmpty)
        XCTAssertEqual(router.tick(now: 0.37), [.tap(Command(.enter))])
        _ = router.press(.plus, binding: binding, now: 1)
        XCTAssertEqual(router.tick(now: 1.6), [.tap(Command(.copy))])
        XCTAssertTrue(router.release(.plus, now: 1.7).isEmpty)
    }
    func testMappingSnapshotAndPerAppInheritance() throws {
        var config = PilotSettings()
        config.profiles.append(AppProfile(id: "test.app", name: "Test"))
        config.set(ButtonBinding(.copy), button: .plus, scope: "test.app", layer: .base)
        XCTAssertEqual(config.binding(for: .plus, scope: "test.app", layer: .base).primary.action, .copy)
        XCTAssertEqual(config.binding(for: .plus, scope: "unknown", layer: .base).primary.action, .enter)
        XCTAssertEqual(config.binding(for: .x, scope: "test.app", layer: .rHeld).primary.action, .missionControl)
        XCTAssertEqual(config.binding(for: .y, scope: "test.app", layer: .rHeld).primary.action, .leftClick)
        let encoded = try JSONEncoder().encode(config)
        XCTAssertEqual(try JSONDecoder().decode(PilotSettings.self, from: encoded), config)
        var router = InputRouter()
        _ = router.press(.y, binding: ButtonBinding(.leftClick), now: 0)
        XCTAssertEqual(router.release(.y, now: 1), [.end(Command(.leftClick))])
    }
    func testGyroCalibrationFilteringAndReset() {
        var gyro = GyroProcessor()
        gyro.startCalibration()
        for _ in 0..<300 { _ = gyro.process(MotionVector(1,0,2), dt: 0.005, sensitivity: 15, smoothing: 0.04) }
        XCTAssertTrue(gyro.calibrated); XCTAssertFalse(gyro.calibrating)
        let stopped = gyro.process(MotionVector(1,0,2), dt: 0.005, sensitivity: 15, smoothing: 0.04)
        XCTAssertEqual(stopped.x, 0); XCTAssertEqual(stopped.y, 0)
        let movement = gyro.process(MotionVector(10,0,20), dt: 0.005, sensitivity: 15, smoothing: 0.005)
        XCTAssertLessThan(movement.x, 0); XCTAssertLessThan(movement.y, 0)
        let gap = gyro.process(MotionVector(10,0,20), dt: 1, sensitivity: 15, smoothing: 0.005)
        XCTAssertEqual(gap.x, 0)
    }
    func testMovingGyroCannotCalibrateAndVoiceModesDiffer() {
        var gyro = GyroProcessor(); gyro.startCalibration()
        for _ in 0..<350 { _ = gyro.process(MotionVector(30,0,0), dt: 0.005, sensitivity: 15, smoothing: 0.04) }
        XCTAssertFalse(gyro.calibrated); XCTAssertEqual(gyro.calibrationProgress, 0)
        var voice = VoiceSettings()
        voice.choose(.typeless); XCTAssertEqual(voice.gesture, .toggle); XCTAssertEqual(voice.shortcut, .fn)
        voice.choose(.doubao); XCTAssertEqual(voice.gesture, .hold); XCTAssertEqual(voice.shortcut.code, 54)
    }
}

final class RepeatAndMigrationTests: XCTestCase {
    func testRepeatStopsOnReleaseAndContextCancel() {
        var router = InputRouter(), binding = ButtonBinding(.backspace)
        binding.repeats = true
        XCTAssertEqual(router.press(.plus, binding: binding, now: 0), [.tap(Command(.backspace))])
        XCTAssertTrue(router.tick(now: 0.2).isEmpty)
        XCTAssertEqual(router.tick(now: 0.36), [.tap(Command(.backspace))])
        XCTAssertTrue(router.tick(now: 0.4).isEmpty)
        _ = router.release(.plus, now: 0.43)
        XCTAssertTrue(router.tick(now: 1).isEmpty)
        _ = router.press(.plus, binding: binding, now: 2)
        _ = router.cancel()
        XCTAssertTrue(router.tick(now: 5).isEmpty)
    }
    func testPreviousSettingsWithoutRepeatOrAppFieldsStillDecode() throws {
        let data = Data(#"{"primary":{"action":"enter"}}"#.utf8)
        let binding = try JSONDecoder().decode(ButtonBinding.self, from: data)
        XCTAssertEqual(binding.primary.action, .enter)
        XCTAssertFalse(binding.repeats)
        XCTAssertNil(binding.primary.applicationID)
    }
}
