import Combine
import SwiftUI

@main
struct MeetingReminderApp: App {
    @StateObject private var calendarService = CalendarService()
    @StateObject private var meetingMonitor: MeetingMonitor
    @StateObject private var overlayCoordinator: OverlayCoordinator
    @StateObject private var focusCountdownCoordinator: FocusCountdownCoordinator

    init() {
        let calendar = CalendarService()
        let monitor = MeetingMonitor(calendarService: calendar)
        let coordinator = OverlayCoordinator(monitor: monitor)
        let focusCountdown = FocusCountdownCoordinator(calendarService: calendar)
        _calendarService = StateObject(wrappedValue: calendar)
        _meetingMonitor = StateObject(wrappedValue: monitor)
        _overlayCoordinator = StateObject(wrappedValue: coordinator)
        _focusCountdownCoordinator = StateObject(wrappedValue: focusCountdown)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                calendarService: calendarService,
                meetingMonitor: meetingMonitor
            )
            .onAppear {
                Task {
                    await calendarService.requestAccess()
                    meetingMonitor.start()
                    overlayCoordinator.startObserving()
                    focusCountdownCoordinator.start()
                }
            }
        } label: {
            Label("Meeting Reminder", systemImage: "calendar.badge.clock")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(calendarService: calendarService, meetingMonitor: meetingMonitor)
        }
    }
}

@MainActor
final class OverlayCoordinator: ObservableObject {
    private let monitor: MeetingMonitor
    private let windowController = OverlayWindowController()
    private var cancellable: AnyCancellable?

    init(monitor: MeetingMonitor) {
        self.monitor = monitor
    }

    func startObserving() {
        cancellable = monitor.$shouldShowOverlay
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldShow in
                guard let self else { return }
                if shouldShow, let event = monitor.activeOverlayEvent {
                    windowController.show(
                        event: event,
                        kind: monitor.activeOverlayKind,
                        onDismiss: { [weak self] in self?.monitor.dismiss() },
                        onSnooze: { [weak self] minutes in self?.monitor.snooze(minutes: minutes) },
                        onJoin: { [weak self] in self?.monitor.joinMeeting() },
                        onRemindOnTime: { [weak self] in self?.monitor.snoozeUntilStart() }
                    )
                } else {
                    windowController.close()
                }
            }
    }
}
