# TODO

## Merge upstream commits

`main` has split off from upstream [nilBora/meeting-reminder](https://github.com/nilBora/meeting-reminder) (`origin`). Upstream has 55 commits we don't have. Merge them with `git fetch origin && git merge origin/main`, resolve conflicts, rebuild and test.

Features upstream added:

- **Configurable snooze durations**: a duration-picker menu on the overlay and a snooze options section in Preferences
- **Preview overlay** button in Preferences > General
- **Mandatory action option**, plus a fix for the overlay not coming back after snoozing past the meeting start
- **End-of-meeting reminder** ("remind me when meeting is about to end"), with full snooze options
- **Working-hours overlay reminders**
- **Floating countdown** to the next meeting, with countdown styles and a resizable window, counting down to the end of an ongoing meeting
- **Native meeting links** preferred (opens the Zoom/Teams app instead of the browser)
- **Event filtering by type and keywords**
- **Distribution**: a release workflow (GitHub Actions), a Homebrew cask and installer code signing

Expected conflicts:

- Upstream's event filtering overlaps with our Event Types tab (v1.3.0) and the type filter in `MeetingMonitor` (v1.3.1).
- `SettingsView.swift` (new tabs and sections on both sides), `OverlayView.swift` (snooze menu vs. our Remind-on-time button) and `MenuBarView.swift` (Up Next list vs. popover height changes).
- Upstream renamed the app and scheme to `MeetingReminder` (`9d45f3c`). Check that the project file merges cleanly.
