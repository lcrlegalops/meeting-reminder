import Foundation

enum WorkingHoursEvents {
    static let enabledKey = "workingHoursEnabled"
    static let startMinutesKey = "workingHoursStartMinutes"
    static let endMinutesKey = "workingHoursEndMinutes"
    static let daysKey = "workingHoursDays"

    static let defaultStartMinutes = 9 * 60
    static let defaultEndMinutes = 17 * 60
    static let defaultDaysMask = 0b0111110 // Mon–Fri (bit 0 = Sunday)

    static func synthesize(for now: Date, defaults: UserDefaults = .standard) -> [MeetingEvent] {
        guard defaults.bool(forKey: enabledKey) else { return [] }

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: now) // 1=Sun … 7=Sat
        let daysMask = (defaults.object(forKey: daysKey) as? Int) ?? defaultDaysMask
        let weekdayBit = 1 << (weekday - 1)
        guard daysMask & weekdayBit != 0 else { return [] }

        let startMinutes = (defaults.object(forKey: startMinutesKey) as? Int) ?? defaultStartMinutes
        let endMinutes = (defaults.object(forKey: endMinutesKey) as? Int) ?? defaultEndMinutes

        let dayStamp = dayStampFormatter.string(from: calendar.startOfDay(for: now))
        let lowerBound = now.addingTimeInterval(-300)

        var result: [MeetingEvent] = []

        if let startDate = calendar.date(bySettingHour: startMinutes / 60,
                                         minute: startMinutes % 60,
                                         second: 0, of: now),
           startDate > lowerBound {
            result.append(
                MeetingEvent(
                    id: "working-hours-start-\(dayStamp)",
                    title: "Start of work day",
                    startDate: startDate,
                    endDate: startDate.addingTimeInterval(60),
                    calendar: "Working Hours",
                    type: .workingHours
                )
            )
        }

        if let endDate = calendar.date(bySettingHour: endMinutes / 60,
                                       minute: endMinutes % 60,
                                       second: 0, of: now),
           endDate > lowerBound {
            result.append(
                MeetingEvent(
                    id: "working-hours-end-\(dayStamp)",
                    title: "End of work day",
                    startDate: endDate,
                    endDate: endDate.addingTimeInterval(60),
                    calendar: "Working Hours",
                    type: .workingHours
                )
            )
        }

        return result
    }

    private static let dayStampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
