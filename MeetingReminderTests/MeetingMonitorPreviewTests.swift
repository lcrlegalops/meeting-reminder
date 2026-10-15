import XCTest
@testable import MeetingReminder

@MainActor
final class MeetingMonitorPreviewTests: XCTestCase {

    private var monitor: MeetingMonitor!

    override func setUp() {
        super.setUp()
        monitor = MeetingMonitor(calendarService: CalendarService())
    }

    override func tearDown() {
        monitor.stop()
        monitor = nil
        super.tearDown()
    }

    // MARK: - previewOverlay

    func testPreviewOverlaySetsShowOverlay() {
        monitor.previewOverlay()
        XCTAssertTrue(monitor.shouldShowOverlay)
    }

    func testPreviewOverlaySetsActiveEvent() {
        monitor.previewOverlay()
        XCTAssertNotNil(monitor.activeOverlayEvent)
    }

    func testPreviewOverlayEventTitle() {
        monitor.previewOverlay()
        XCTAssertEqual(monitor.activeOverlayEvent?.title, "Example Meeting")
    }

    func testPreviewOverlayEventCalendar() {
        monitor.previewOverlay()
        XCTAssertEqual(monitor.activeOverlayEvent?.calendar, "Preview")
    }

    func testPreviewOverlayEventStartsInFuture() {
        monitor.previewOverlay()
        let start = monitor.activeOverlayEvent?.startDate
        XCTAssertNotNil(start)
        XCTAssertGreaterThan(start!, Date())
    }

    func testPreviewOverlayEventStartsInApproximatelyTwoMinutes() {
        let before = Date()
        monitor.previewOverlay()
        let after = Date()

        let start = try! XCTUnwrap(monitor.activeOverlayEvent?.startDate)
        let lowerBound = before.addingTimeInterval(2 * 60 - 1)
        let upperBound = after.addingTimeInterval(2 * 60 + 1)
        XCTAssertTrue(start >= lowerBound && start <= upperBound,
                      "Expected start ~2 min from now, got \(start)")
    }

    func testPreviewOverlayEventHasVideoLink() {
        monitor.previewOverlay()
        XCTAssertNotNil(monitor.activeOverlayEvent?.videoLink)
    }

    func testPreviewOverlayEventIdHasPreviewPrefix() {
        monitor.previewOverlay()
        let id = monitor.activeOverlayEvent?.id ?? ""
        XCTAssertTrue(id.hasPrefix("preview-"), "Expected ID to start with 'preview-', got '\(id)'")
    }

    func testPreviewOverlayDismissResetsState() {
        monitor.previewOverlay()
        monitor.dismiss()
        XCTAssertFalse(monitor.shouldShowOverlay)
        XCTAssertNil(monitor.activeOverlayEvent)
    }

    func testPreviewOverlayCanBeCalledMultipleTimes() {
        monitor.previewOverlay()
        let firstID = monitor.activeOverlayEvent?.id
        monitor.dismiss()
        monitor.previewOverlay()
        let secondID = monitor.activeOverlayEvent?.id
        XCTAssertNotEqual(firstID, secondID, "Each preview should produce a unique event ID")
        XCTAssertTrue(monitor.shouldShowOverlay)
    }
}
