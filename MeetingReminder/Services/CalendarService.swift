import Combine
import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    @Published var events: [MeetingEvent] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var reminderAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableCalendars: [EKCalendar] = []

    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    private var notificationObserver: Any?

    init() {
        updateAuthorizationStatus()
        setupNotificationObserver()
    }

    deinit {
        refreshTimer?.invalidate()
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func requestAccess() async {
        if #available(macOS 14.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                updateAuthorizationStatus()
                if granted {
                    fetchEvents()
                    startAutoRefresh()
                }
            } catch {
                // Calendar access denied or error — no action needed
            }
        } else {
            let granted = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
            updateAuthorizationStatus()
            if granted {
                fetchEvents()
                startAutoRefresh()
            }
        }
    }

    func requestReminderAccess() async {
        if #available(macOS 14.0, *) {
            do {
                _ = try await eventStore.requestFullAccessToReminders()
            } catch {
                // Reminder access denied or error — no action needed
            }
        } else {
            _ = await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        fetchEvents()
    }

    func startMonitoring() {
        fetchEvents()
        startAutoRefresh()
    }

    func fetchEvents() {
        let now = Date()
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else { return }

        let predicate = eventStore.predicateForEvents(
            withStart: now.addingTimeInterval(-300), // include events that just started
            end: endOfDay,
            calendars: nil
        )

        let ekEvents = eventStore.events(matching: predicate)

        let enabledCalendarIDs = Set(
            UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") ?? []
        )

        let calendarEvents = ekEvents
            .filter { event in
                guard !event.isAllDay else { return false }

                if let attendees = event.attendees,
                   let me = attendees.first(where: { $0.isCurrentUser }),
                   me.participantStatus == .declined {
                    return false
                }

                if !enabledCalendarIDs.isEmpty {
                    return enabledCalendarIDs.contains(event.calendar.calendarIdentifier)
                }

                return true
            }
            .map { ekEvent -> MeetingEvent in
                let videoLink = VideoLinkDetector.detectLink(in: ekEvent)
                return MeetingEvent(from: ekEvent, videoLink: videoLink)
            }
            .filter { isEventTypeEnabled($0.type) }

        events = calendarEvents.sorted { $0.startDate < $1.startDate }

        availableCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        // Fetch tasks async and merge
        if isEventTypeEnabled(.task) && reminderAccessGranted {
            Task {
                await fetchRemindersAndMerge(existingEvents: events, endOfDay: endOfDay, now: now)
            }
        }
    }

    private func fetchRemindersAndMerge(existingEvents: [MeetingEvent], endOfDay: Date, now: Date) async {
        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars.isEmpty ? nil : calendars)

        let reminders: [EKReminder] = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { result in
                continuation.resume(returning: result ?? [])
            }
        }

        let taskEvents = reminders.compactMap { reminder -> MeetingEvent? in
            guard !reminder.isCompleted else { return nil }
            guard let components = reminder.dueDateComponents,
                  components.hour != nil, // only tasks with a specific time
                  let dueDate = Calendar.current.date(from: components) else { return nil }
            guard dueDate >= now.addingTimeInterval(-300) && dueDate <= endOfDay else { return nil }
            return MeetingEvent(from: reminder, dueDate: dueDate)
        }

        let existingIDs = Set(existingEvents.map { $0.id })
        let newTasks = taskEvents.filter { !existingIDs.contains($0.id) }
        guard !newTasks.isEmpty else { return }

        events = (existingEvents + newTasks).sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Event type filter helpers

    private func isEventTypeEnabled(_ type: MeetingEventType) -> Bool {
        let key: String
        switch type {
        case .meeting:     key = "showMeetings"
        case .appointment: key = "showAppointments"
        case .task:        key = "showTasks"
        }
        // Default true when key not set
        guard UserDefaults.standard.object(forKey: key) != nil else { return true }
        return UserDefaults.standard.bool(forKey: key)
    }

    var reminderAccessGranted: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    // MARK: - Private

    private func updateAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        reminderAuthorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetchEvents()
            }
        }
    }

    private func setupNotificationObserver() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.fetchEvents()
            }
        }
    }
}
