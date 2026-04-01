import AppKit
import Combine
import Foundation

@MainActor
final class MeetingMonitor: ObservableObject {
    @Published var activeOverlayEvent: MeetingEvent?
    @Published var shouldShowOverlay = false

    private var calendarService: CalendarService
    private var checkTimer: Timer?
    private var shownEventIDs: Set<String> = []
    private var snoozedEvents: [String: Date] = [:]
    private var lastCleanupDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    var reminderMinutes: Int {
        guard UserDefaults.standard.object(forKey: "reminderMinutes") != nil else { return 5 }
        return UserDefaults.standard.integer(forKey: "reminderMinutes").clamped(to: 0...30)
    }

    init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    func start() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUpcomingMeetings()
            }
        }
        // Also check immediately
        checkUpcomingMeetings()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    func dismiss() {
        shouldShowOverlay = false
        activeOverlayEvent = nil
    }

    func snooze(minutes: Int = 1) {
        guard let event = activeOverlayEvent else { return }
        snoozedEvents[event.id] = Date().addingTimeInterval(TimeInterval(minutes * 60))
        shownEventIDs.remove(event.id)
        dismiss()
    }

    func snoozeUntilStart() {
        guard let event = activeOverlayEvent else { return }
        snoozedEvents[event.id] = event.startDate
        shownEventIDs.remove(event.id)
        dismiss()
    }

    func joinMeeting() {
        guard let event = activeOverlayEvent, let url = event.videoLink else { return }
        guard url.scheme == "https" || url.scheme == "http" else { return }
        NSWorkspace.shared.open(url)
        dismiss()
    }

    private func checkUpcomingMeetings() {
        let now = Date()
        let reminderSeconds = TimeInterval(reminderMinutes * 60)

        // Reset shown IDs at the start of a new day
        if !Calendar.current.isDate(now, inSameDayAs: lastCleanupDate) {
            shownEventIDs.removeAll()
            snoozedEvents.removeAll()
            lastCleanupDate = now
        }

        // Clean up expired snoozes
        snoozedEvents = snoozedEvents.filter { $0.value > now }

        for event in calendarService.events {
            let timeUntil = event.startDate.timeIntervalSince(now)

            // Skip if this event type has reminders disabled
            guard isEventTypeEnabled(event.type) else { continue }

            // Skip if already shown
            guard !shownEventIDs.contains(event.id) else { continue }

            // Skip if snoozed and snooze hasn't expired
            if let snoozeUntil = snoozedEvents[event.id], now < snoozeUntil {
                continue
            }

            // Trigger overlay if event is within reminder window
            if timeUntil > 0 && timeUntil <= reminderSeconds {
                triggerOverlay(for: event)
                return
            }

            // Also trigger for events that just started (within 60 seconds)
            if timeUntil <= 0 && timeUntil > -60 {
                triggerOverlay(for: event)
                return
            }
        }
    }

    private func triggerOverlay(for event: MeetingEvent) {
        shownEventIDs.insert(event.id)
        activeOverlayEvent = event
        shouldShowOverlay = true

        if UserDefaults.standard.object(forKey: "soundEnabled") == nil ||
           UserDefaults.standard.bool(forKey: "soundEnabled") {
            NSSound.beep()
        }
    }

    private func isEventTypeEnabled(_ type: MeetingEventType) -> Bool {
        let key: String
        switch type {
        case .meeting:     key = "showMeetings"
        case .appointment: key = "showAppointments"
        case .task:        key = "showTasks"
        }
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
