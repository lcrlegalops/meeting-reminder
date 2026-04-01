import SwiftUI

struct MenuBarView: View {
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var meetingMonitor: MeetingMonitor
    @Environment(\.dismiss) private var dismiss

    @AppStorage("showMeetings")     private var showMeetings: Bool = true
    @AppStorage("showAppointments") private var showAppointments: Bool = true
    @AppStorage("showTasks")        private var showTasks: Bool = true

    private var upcomingEvents: [MeetingEvent] {
        calendarService.events.filter { $0.timeUntilStart > -300 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if calendarService.authorizationStatus != .authorized {
                calendarAccessSection
            } else if upcomingEvents.isEmpty {
                noEventsSection
            } else {
                eventListSection
            }

            Divider()
                .padding(.vertical, 6)

            PreferencesButton {
                dismiss()
            }

            Divider()
                .padding(.vertical, 6)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit Meeting Reminder")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: - Sections

    private var calendarAccessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Calendar Access Required", systemImage: "calendar.badge.exclamationmark")
                .font(.headline)

            if calendarService.authorizationStatus == .denied {
                Text("Access was denied. Open System Settings to allow it.")
                    .font(.callout)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Open System Settings") {
                    NSWorkspace.shared.open(
                        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!
                    )
                }
            } else {
                Text("Click below to allow calendar access.")
                    .font(.callout)
                    .foregroundColor(.primary)
                Button("Request Access") {
                    Task { await calendarService.requestAccess() }
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var noEventsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Nothing coming up", systemImage: "checkmark.circle")
                .font(.headline)
            Text("You're free for the rest of the day")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var eventListSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Up Next")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)

            ForEach(upcomingEvents.prefix(8)) { event in
                eventRow(event)
                if event.id != upcomingEvents.prefix(8).last?.id {
                    Divider().padding(.vertical, 2)
                }
            }
        }
    }

    // MARK: - Event Row

    private func eventRow(_ event: MeetingEvent) -> some View {
        HStack(spacing: 0) {
            // Type accent bar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(typeColor(event.type))
                .frame(width: 3)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(event.formattedStartTime)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if event.isInProgress {
                        Text("· In progress")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    } else {
                        Text("· in \(event.formattedTimeUntil)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                // Bell: shown when reminder is active for this type
                if isMonitored(event) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 9))
                        .foregroundColor(typeColor(event.type).opacity(0.7))
                }

                // Join button for meetings
                if let url = event.videoLink, url.scheme == "https" || url.scheme == "http" {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "video.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.borderless)
                    .help("Join \(VideoLinkDetector.serviceName(for: url))")
                }
            }
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    private func typeColor(_ type: MeetingEventType) -> Color {
        switch type {
        case .meeting:     return .blue
        case .appointment: return .purple
        case .task:        return .orange
        }
    }

    private func isMonitored(_ event: MeetingEvent) -> Bool {
        switch event.type {
        case .meeting:     return showMeetings
        case .appointment: return showAppointments
        case .task:        return showTasks
        }
    }
}

private struct PreferencesButton: View {
    var onDismiss: () -> Void

    var body: some View {
        if #available(macOS 14.0, *) {
            PreferencesButton14(onDismiss: onDismiss)
        } else {
            Button {
                onDismiss()
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.title.contains("Settings") || window.title.contains("Preferences") {
                        window.orderFrontRegardless()
                    }
                }
            } label: {
                Text("Preferences…")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}

@available(macOS 14.0, *)
private struct PreferencesButton14: View {
    @Environment(\.openSettings) private var openSettings
    var onDismiss: () -> Void

    var body: some View {
        Button {
            onDismiss()
            openSettings()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.title.contains("Settings") || window.title.contains("Preferences") {
                    window.orderFrontRegardless()
                }
            }
        } label: {
            Text("Preferences…")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
