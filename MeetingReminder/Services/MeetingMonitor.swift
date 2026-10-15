import AppKit
import Combine
import Foundation

@MainActor
protocol CalendarServiceProtocol: AnyObject {
    var events: [MeetingEvent] { get }
}

enum OverlayKind {
    case start
    case ending
}

@MainActor
final class MeetingMonitor: ObservableObject {
    @Published var activeOverlayEvent: MeetingEvent?
    @Published var shouldShowOverlay = false
    @Published var activeOverlayKind: OverlayKind = .start

    private var calendarService: any CalendarServiceProtocol
    private var checkTimer: Timer?
    private var shownEventIDs: Set<String> = []
    private var snoozedEvents: [String: Date] = [:]
    private var endReminderShownEventIDs: Set<String> = []
    private var endReminderSnoozes: [String: Date] = [:]
    private var lastCleanupDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()

    var reminderMinutes: Int {
        guard UserDefaults.standard.object(forKey: "reminderMinutes") != nil else { return 5 }
        return UserDefaults.standard.integer(forKey: "reminderMinutes").clamped(to: 0...30)
    }

    var endReminderMinutes: Int {
        UserDefaults.standard.integer(forKey: "endReminderMinutes")
    }

    var endReminderEnabled: Bool {
        endReminderMinutes > 0
    }

    init(calendarService: any CalendarServiceProtocol) {
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
        activeOverlayKind = .start
    }

    func snooze(minutes: Int = 1) {
        guard let event = activeOverlayEvent else { return }
        let requested = Date().addingTimeInterval(TimeInterval(minutes * 60))
        switch activeOverlayKind {
        case .start:
            snoozedEvents[event.id] = requested
            shownEventIDs.remove(event.id)
        case .ending:
            // Never snooze past the meeting's end time.
            let until = min(requested, event.endDate)
            if until > Date() {
                endReminderSnoozes[event.id] = until
                endReminderShownEventIDs.remove(event.id)
            } else {
                // Meeting already ended — treat as acknowledge.
                endReminderShownEventIDs.insert(event.id)
            }
        }
        dismiss()
    }

    func snoozeUntilStart() {
        guard let event = activeOverlayEvent else { return }
        snoozedEvents[event.id] = event.startDate
        shownEventIDs.remove(event.id)
        dismiss()
    }

    func previewOverlay() {
        let now = Date()
        let event = MeetingEvent(
            id: "preview-\(now.timeIntervalSince1970)",
            title: "Example Meeting",
            startDate: now.addingTimeInterval(2 * 60),
            endDate: now.addingTimeInterval(62 * 60),
            calendar: "Preview",
            videoLink: URL(string: "https://zoom.us/j/00000000000"),
            type: .meeting
        )
        activeOverlayKind = .start
        activeOverlayEvent = event
        shouldShowOverlay = true
        playSoundIfEnabled()
    }

    func joinMeeting() {
        guard let event = activeOverlayEvent, let url = event.videoLink else { return }
        guard url.scheme == "https" || url.scheme == "http" else { return }
        VideoLinkDetector.openMeetingURL(url)
        dismiss()
    }

    private func checkUpcomingMeetings() {
        let now = Date()

        // Reset shown IDs at the start of a new day
        if !Calendar.current.isDate(now, inSameDayAs: lastCleanupDate) {
            shownEventIDs.removeAll()
            snoozedEvents.removeAll()
            endReminderShownEventIDs.removeAll()
            endReminderSnoozes.removeAll()
            lastCleanupDate = now
        }

        // Clean up expired snoozes
        snoozedEvents = snoozedEvents.filter { $0.value > now }

        checkStartReminders(now: now)

        guard !shouldShowOverlay else { return }

        checkEndReminders(now: now)
    }

    private func checkStartReminders(now: Date) {
        let reminderSeconds = TimeInterval(reminderMinutes * 60)

        for event in calendarService.events where shouldRemind(event) {
            let timeUntil = event.startDate.timeIntervalSince(now)

            // Skip if already shown
            guard !shownEventIDs.contains(event.id) else { continue }

            // Skip if snoozed and snooze hasn't expired
            if let snoozeUntil = snoozedEvents[event.id], now < snoozeUntil {
                continue
            }

            // Trigger overlay if event is within reminder window
            if timeUntil > 0 && timeUntil <= reminderSeconds {
                triggerOverlay(for: event, kind: .start)
                return
            }

            // Also trigger for events that are in progress (snoozed past start)
            if timeUntil <= 0 && event.endDate > now {
                triggerOverlay(for: event, kind: .start)
                return
            }
        }
    }

    private func checkEndReminders(now: Date) {
        guard endReminderEnabled else { return }

        let windowSeconds = TimeInterval(endReminderMinutes * 60)
        let preReminderSeconds = TimeInterval(reminderMinutes * 60)

        for event in calendarService.events where shouldRemind(event) {
            // Skip if user acknowledged this meeting's end-reminder
            if endReminderShownEventIDs.contains(event.id) { continue }

            // Skip if snoozed and snooze hasn't expired
            if let snoozeUntil = endReminderSnoozes[event.id], now < snoozeUntil {
                continue
            }

            let isInWindow = event.startDate <= now &&
                             event.endDate > now &&
                             event.endDate.timeIntervalSince(now) <= windowSeconds
            let hasExpiredSnooze = endReminderSnoozes[event.id].map { now >= $0 } ?? false

            guard isInWindow || hasExpiredSnooze else { continue }

            // Suppress if another upcoming meeting's pre-meeting reminder would fire
            // before or at this meeting's end — the regular start-reminder will cover the transition.
            let hasBackToBack = calendarService.events.contains { other in
                shouldRemind(other) &&
                other.id != event.id &&
                other.startDate > now &&
                other.startDate.addingTimeInterval(-preReminderSeconds) <= event.endDate
            }

            if hasBackToBack { continue }

            triggerOverlay(for: event, kind: .ending)
            return
        }
    }

    private func triggerOverlay(for event: MeetingEvent, kind: OverlayKind) {
        switch kind {
        case .start:
            shownEventIDs.insert(event.id)
        case .ending:
            endReminderShownEventIDs.insert(event.id)
        }
        activeOverlayKind = kind
        activeOverlayEvent = event
        shouldShowOverlay = true
        playSoundIfEnabled()
    }

    private func playSoundIfEnabled() {
        if UserDefaults.standard.object(forKey: "soundEnabled") == nil ||
           UserDefaults.standard.bool(forKey: "soundEnabled") {
            NSSound.beep()
        }
    }

    /// Whether an overlay fires for this event: not filtered out (Free/keywords)
    /// and its event type is enabled in Settings > Event Types.
    func shouldRemind(_ event: MeetingEvent) -> Bool {
        event.triggersReminder && Self.isEventTypeEnabled(event.type)
    }

    static func isEventTypeEnabled(_ type: MeetingEventType) -> Bool {
        let key: String
        switch type {
        case .meeting:      key = "showMeetings"
        case .appointment:  key = "showAppointments"
        case .task:         key = "showTasks"
        case .workingHours: return true // opted into separately in Working Hours
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
