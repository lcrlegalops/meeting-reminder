import XCTest
@testable import MeetingReminder

final class ClampedExtensionTests: XCTestCase {

    func testValueInRange() {
        XCTAssertEqual(5.clamped(to: 0...10), 5)
    }

    func testValueBelowRange() {
        XCTAssertEqual((-1).clamped(to: 0...10), 0)
    }

    func testValueAboveRange() {
        XCTAssertEqual(20.clamped(to: 0...30), 20)
    }

    func testZeroInRange() {
        XCTAssertEqual(0.clamped(to: 0...30), 0)
    }

    func testValueAtLowerBound() {
        XCTAssertEqual(0.clamped(to: 0...10), 0)
    }

    func testValueAtUpperBound() {
        XCTAssertEqual(30.clamped(to: 0...30), 30)
    }

    func testAboveUpperBoundClamped() {
        XCTAssertEqual(99.clamped(to: 0...30), 30)
    }
}
