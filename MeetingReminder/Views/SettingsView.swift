import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("reminderMinutes") private var reminderMinutes: Int = 5
    @AppStorage("soundEnabled") private var soundEnabled: Bool = true
    @AppStorage("requireAction") private var requireAction: Bool = false
    @AppStorage("overlayBackground") private var overlayBackground: String = "dark"
    @AppStorage("showMeetings") private var showMeetings: Bool = true
    @AppStorage("showAppointments") private var showAppointments: Bool = true
    @AppStorage("showTasks") private var showTasks: Bool = true
    @AppStorage("endReminderMinutes") private var endReminderMinutes: Int = 0
    @AppStorage(ReminderFilter.skipFreeEventsKey) private var skipFreeEvents: Bool = false
    @AppStorage(ReminderFilter.excludedKeywordsKey) private var excludedKeywords: String = ""
    @AppStorage(WorkingHoursEvents.enabledKey) private var workingHoursEnabled: Bool = false
    @AppStorage(WorkingHoursEvents.startMinutesKey) private var workingHoursStartMinutes: Int = WorkingHoursEvents.defaultStartMinutes
    @AppStorage(WorkingHoursEvents.endMinutesKey) private var workingHoursEndMinutes: Int = WorkingHoursEvents.defaultEndMinutes
    @AppStorage(WorkingHoursEvents.daysKey) private var workingHoursDaysMask: Int = WorkingHoursEvents.defaultDaysMask
    @AppStorage(FocusCountdownCoordinator.enabledKey) private var focusCountdownEnabled: Bool = false
    @AppStorage(FocusCountdownLayout.storageKey) private var focusCountdownLayout: String = FocusCountdownLayout.defaultLayout.rawValue
    @ObservedObject var calendarService: CalendarService
    @ObservedObject var meetingMonitor: MeetingMonitor

    @State private var launchAtLogin = false
    @State private var enabledCalendarIDs: Set<String> = []
    @State private var connectedScreens: [NSScreen] = []
    @State private var enabledScreenIDs: Set<String> = []
    @State private var snoozeOptions: Set<Int> = [1, 2, 5, 10]

    private let snoozeOptionCandidates = [1, 2, 5, 10, 15]

    var body: some View {
        TabView {
            generalTab
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            eventTypesTab
                .tabItem {
                    Label("Event Types", systemImage: "line.3.horizontal.decrease.circle")
                }

            workingHoursTab
                .tabItem {
                    Label("Working Hours", systemImage: "clock")
                }

            focusTab
                .tabItem {
                    Label("Focus", systemImage: "timer")
                }

            calendarsTab
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }
        }
        .frame(width: 500, height: 480)
        .onAppear {
            loadSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            connectedScreens = NSScreen.screens
        }
    }

    private var generalTab: some View {
        Form {
            Section("Reminders") {
                Picker("Remind me before meetings:", selection: $reminderMinutes) {
                    Text("On time").tag(0)
                    Text("1 minute").tag(1)
                    Text("2 minutes").tag(2)
                    Text("5 minutes").tag(5)
                    Text("10 minutes").tag(10)
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: 4) {
                    Picker("Remind me when meeting is about to end:", selection: $endReminderMinutes) {
                        Text("Never").tag(0)
                        Text("1 minute").tag(1)
                        Text("2 minutes").tag(2)
                        Text("5 minutes").tag(5)
                        Text("10 minutes").tag(10)
                    }
                    .pickerStyle(.menu)
                    Text("Skipped when another meeting starts back-to-back.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section {
                Toggle("Play sound with reminder", isOn: $soundEnabled)
                Toggle("Require action (hide Snooze button)", isOn: $requireAction)
            }

            Section("Snooze options") {
                ForEach(snoozeOptionCandidates, id: \.self) { minutes in
                    Toggle(snoozeLabel(minutes: minutes), isOn: snoozeBinding(for: minutes))
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section("Test") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show a sample meeting reminder")
                        Text("Uses your current background, display, snooze and sound settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        meetingMonitor.previewOverlay()
                    } label: {
                        Label("Show Test Reminder", systemImage: "play.circle")
                    }
                }
            }

            Section {
                HStack {
                    Text("Calendar access:")
                    Spacer()
                    if calendarService.authorizationStatus == .authorized {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Request Access") {
                            Task {
                                await calendarService.requestAccess()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var appearanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Overlay Background")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                    ForEach(OverlayBackground.allCases) { bg in
                        Button {
                            overlayBackground = bg.rawValue
                        } label: {
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(bg.previewGradient)
                                    .frame(height: 88)
                                    .overlay(
                                        VStack(spacing: 2) {
                                            Text("Meeting")
                                                .font(.system(size: 11, weight: .bold))
                                            Text("in 3 min")
                                                .font(.system(size: 9))
                                                .opacity(0.75)
                                        }
                                        .foregroundColor(.white)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(overlayBackground == bg.rawValue ? Color.accentColor : Color.clear, lineWidth: 3)
                                    )

                                Text(bg.displayName)
                                    .font(.caption)
                                    .foregroundColor(overlayBackground == bg.rawValue ? .accentColor : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Displays")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(connectedScreens, id: \.stableID) { screen in
                        let isOnlyChecked = checkedScreenIDs == [screen.stableID]
                        Toggle(isOn: binding(forScreen: screen.stableID)) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(screen.localizedName)
                                Text(screenDetails(screen))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(isOnlyChecked)
                    }
                }

                Text("At least one display must be selected. If a selected display is disconnected, the reminder shows on all displays.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }

    private var eventTypesTab: some View {
        Form {
            Section {
                Toggle(isOn: $showMeetings) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Meetings", systemImage: "video.fill")
                        Text("Events with a Zoom or Google Meet link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showMeetings) { _ in calendarService.fetchEvents() }

                Toggle(isOn: $showAppointments) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Appointments", systemImage: "calendar")
                        Text("Calendar events without a video link")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showAppointments) { _ in calendarService.fetchEvents() }
            }

            Section {
                Toggle(isOn: $showTasks) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Tasks", systemImage: "checkmark.circle")
                        Text("Google Tasks (synced via Google Calendar)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .onChange(of: showTasks) { _ in calendarService.fetchEvents() }
            }

            Section("Filters") {
                Toggle("Skip events marked as Free", isOn: $skipFreeEvents)
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Ignore titles containing:", text: $excludedKeywords, prompt: Text("Focus, Lunch, Block"))
                    Text("Comma-separated, case-insensitive.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .onChange(of: skipFreeEvents) { _ in calendarService.fetchEvents() }
            .onChange(of: excludedKeywords) { _ in calendarService.fetchEvents() }

            Section {
                Text("Unchecked or filtered events still appear in the menu bar list, without a bell.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var workingHoursTab: some View {
        Form {
            Section {
                Toggle("Enable working hours reminders", isOn: $workingHoursEnabled)
                    .onChange(of: workingHoursEnabled) { _ in calendarService.fetchEvents() }
                Text("Shows an overlay at the start and end of your work day, so you remember to begin and wrap up on time.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Hours") {
                DatePicker("Start time:",
                           selection: startTimeBinding,
                           displayedComponents: .hourAndMinute)
                    .disabled(!workingHoursEnabled)
                DatePicker("End time:",
                           selection: endTimeBinding,
                           displayedComponents: .hourAndMinute)
                    .disabled(!workingHoursEnabled)
            }

            Section("Days") {
                HStack(spacing: 8) {
                    ForEach(orderedWeekdayIndices, id: \.self) { weekdayIndex in
                        DayChip(label: weekdayShortSymbol(for: weekdayIndex),
                                isOn: dayBinding(weekdayIndex: weekdayIndex))
                    }
                    Spacer()
                }
                .disabled(!workingHoursEnabled)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var focusTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("Show floating countdown to next meeting", isOn: $focusCountdownEnabled)
                .font(.system(size: 13, weight: .semibold))
            Text("A small always-on-top window that counts down to your next meeting. Drag it anywhere on screen.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Text("Layout")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 12) {
                ForEach(FocusCountdownLayout.allCases) { layout in
                    Button {
                        focusCountdownLayout = layout.rawValue
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .frame(height: 70)
                                .overlay(layoutPreview(layout))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(focusCountdownLayout == layout.rawValue ? Color.accentColor : Color.clear, lineWidth: 3)
                                )
                            Text(layout.displayName)
                                .font(.caption)
                                .foregroundColor(focusCountdownLayout == layout.rawValue ? .accentColor : .secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!focusCountdownEnabled)

            Spacer()

            HStack {
                Spacer()
                Button("Reset window position") {
                    NotificationCenter.default.post(name: .focusCountdownResetPosition, object: nil)
                }
                .disabled(!focusCountdownEnabled)
            }
        }
        .padding()
    }

    @ViewBuilder
    private func layoutPreview(_ layout: FocusCountdownLayout) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            // Loop a 60-second countdown so previews show the digits ticking.
            let cycle: TimeInterval = 60
            let remaining = Int(cycle - context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycle))
            let timeText = String(format: "%02d:%02d", remaining / 60, remaining % 60)
            let subtitle = "Standup"

            switch layout {
            case .modern:
                ModernDigitalView(time: timeText, subtitle: subtitle)
                    .padding(4)
            case .terminal:
                TerminalDigitalView(time: timeText, subtitle: subtitle)
                    .padding(4)
            case .flip:
                FlipDigitalView(time: timeText, subtitle: subtitle)
                    .padding(4)
            }
        }
    }

    private var calendarsTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select which calendars to monitor:")
                .font(.headline)

            if calendarService.availableCalendars.isEmpty {
                Text("No calendars available. Grant calendar access first.")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                        Toggle(isOn: binding(for: calendar.calendarIdentifier)) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 10, height: 10)
                                Text(calendar.title)
                            }
                        }
                    }
                }
            }

            Text("If none selected, all calendars are monitored.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private func binding(for calendarID: String) -> Binding<Bool> {
        Binding(
            get: { enabledCalendarIDs.contains(calendarID) },
            set: { enabled in
                if enabled {
                    enabledCalendarIDs.insert(calendarID)
                } else {
                    enabledCalendarIDs.remove(calendarID)
                }
                saveCalendarSelection()
            }
        )
    }

    /// Connected screens that are effectively checked. Empty or stale selection = all.
    private var checkedScreenIDs: Set<String> {
        let connectedIDs = Set(connectedScreens.map(\.stableID))
        let selected = enabledScreenIDs.intersection(connectedIDs)
        return selected.isEmpty ? connectedIDs : selected
    }

    private func binding(forScreen screenID: String) -> Binding<Bool> {
        Binding(
            get: { checkedScreenIDs.contains(screenID) },
            set: { enabled in
                var ids = checkedScreenIDs
                if enabled {
                    ids.insert(screenID)
                } else {
                    ids.remove(screenID)
                }
                guard !ids.isEmpty else { return }
                enabledScreenIDs = ids
                saveScreenSelection()
            }
        )
    }

    private func screenDetails(_ screen: NSScreen) -> String {
        let size = "\(Int(screen.frame.width)) × \(Int(screen.frame.height))"
        return screen == NSScreen.screens.first ? "Main · \(size)" : size
    }

    private func saveScreenSelection() {
        // All connected checked = store empty, so newly connected screens are included too
        let allChecked = enabledScreenIDs == Set(connectedScreens.map(\.stableID))
        UserDefaults.standard.set(allChecked ? [] : Array(enabledScreenIDs), forKey: "enabledScreenIDs")
    }

    private func loadSettings() {
        let ids = UserDefaults.standard.stringArray(forKey: "enabledCalendarIDs") ?? []
        enabledCalendarIDs = Set(ids)
        connectedScreens = NSScreen.screens
        enabledScreenIDs = Set(UserDefaults.standard.stringArray(forKey: "enabledScreenIDs") ?? [])

        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }

        loadSnoozeOptions()
    }

    private func loadSnoozeOptions() {
        let stored = UserDefaults.standard.array(forKey: "snoozeOptions") as? [Int] ?? []
        snoozeOptions = stored.isEmpty ? [1, 2, 5, 10] : Set(stored)
    }

    private func saveSnoozeOptions() {
        UserDefaults.standard.set(Array(snoozeOptions).sorted(), forKey: "snoozeOptions")
    }

    private func snoozeBinding(for minutes: Int) -> Binding<Bool> {
        Binding(
            get: { snoozeOptions.contains(minutes) },
            set: { enabled in
                if enabled {
                    snoozeOptions.insert(minutes)
                } else {
                    guard snoozeOptions.count > 1 else { return }
                    snoozeOptions.remove(minutes)
                }
                saveSnoozeOptions()
            }
        )
    }

    private func snoozeLabel(minutes: Int) -> String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private var orderedWeekdayIndices: [Int] {
        let firstWeekday = Calendar.current.firstWeekday // 1=Sun
        return (0..<7).map { (firstWeekday - 1 + $0) % 7 }
    }

    private func weekdayShortSymbol(for weekdayIndex: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols[weekdayIndex]
    }

    private func dayBinding(weekdayIndex: Int) -> Binding<Bool> {
        let bit = 1 << weekdayIndex
        return Binding(
            get: { (workingHoursDaysMask & bit) != 0 },
            set: { enabled in
                if enabled {
                    workingHoursDaysMask |= bit
                } else {
                    workingHoursDaysMask &= ~bit
                }
                calendarService.fetchEvents()
            }
        )
    }

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: workingHoursStartMinutes) },
            set: { newDate in
                workingHoursStartMinutes = Self.minutes(fromDate: newDate)
                calendarService.fetchEvents()
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: workingHoursEndMinutes) },
            set: { newDate in
                workingHoursEndMinutes = Self.minutes(fromDate: newDate)
                calendarService.fetchEvents()
            }
        )
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(bySettingHour: minutes / 60,
                             minute: minutes % 60,
                             second: 0,
                             of: Date()) ?? Date()
    }

    private static func minutes(fromDate date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    private func saveCalendarSelection() {
        UserDefaults.standard.set(Array(enabledCalendarIDs), forKey: "enabledCalendarIDs")
        calendarService.fetchEvents()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Launch-at-login toggle failed — silently ignore
            }
        }
    }
}

private struct DayChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                )
                .foregroundColor(isOn ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

enum OverlayBackground: String, CaseIterable, Identifiable {
    case dark
    case blue
    case purple
    case gradient
    case red
    case green
    case nightOcean
    case electric
    case cyber

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: return "Dark"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .gradient: return "Sunset"
        case .red: return "Red"
        case .green: return "Green"
        case .nightOcean: return "Night Ocean"
        case .electric: return "Electric"
        case .cyber: return "Cyber"
        }
    }

    var previewGradient: AnyShapeStyle {
        switch self {
        case .dark:
            return AnyShapeStyle(Color.black.opacity(0.85))
        case .blue:
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.05, green: 0.1, blue: 0.3).opacity(0.88),
                                        Color(red: 0.1, green: 0.2, blue: 0.5).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .purple:
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.2, green: 0.05, blue: 0.3).opacity(0.88),
                                        Color(red: 0.4, green: 0.1, blue: 0.5).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .gradient:
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.2).opacity(0.88),
                                        Color(red: 0.4, green: 0.1, blue: 0.2).opacity(0.88),
                                        Color(red: 0.6, green: 0.2, blue: 0.1).opacity(0.88)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        case .red:
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.3, green: 0.02, blue: 0.02).opacity(0.88),
                                        Color(red: 0.5, green: 0.05, blue: 0.05).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .green:
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.02, green: 0.15, blue: 0.1).opacity(0.88),
                                        Color(red: 0.05, green: 0.3, blue: 0.15).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .nightOcean:
            // #0a0e14 → #111821 → #1b2632 with cyan accent glow
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.039, green: 0.055, blue: 0.078).opacity(0.92),
                                        Color(red: 0.067, green: 0.094, blue: 0.129).opacity(0.90),
                                        Color(red: 0.106, green: 0.149, blue: 0.196).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .electric:
            // #0f172a → #1e293b → #334155 with neon blue tint
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.059, green: 0.09, blue: 0.165).opacity(0.92),
                                        Color(red: 0.118, green: 0.161, blue: 0.231).opacity(0.90),
                                        Color(red: 0.2, green: 0.255, blue: 0.333).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        case .cyber:
            // #050505 → #0d1117 → #161b22 with subtle blue glow
            return AnyShapeStyle(
                LinearGradient(colors: [Color(red: 0.02, green: 0.02, blue: 0.02).opacity(0.93),
                                        Color(red: 0.051, green: 0.067, blue: 0.09).opacity(0.91),
                                        Color(red: 0.086, green: 0.106, blue: 0.133).opacity(0.88)],
                               startPoint: .top, endPoint: .bottom)
            )
        }
    }
}
