# TODO

## Merge upstream commits — done (v1.5.0)

Merged 55 upstream commits from [nilBora/meeting-reminder](https://github.com/nilBora/meeting-reminder) (`origin`) on 2026-10-15. Future merges: `git fetch origin && git merge origin/main`.

How the two sides were combined, for future merges:

- **Event filtering:** our Event Types tab is the only UI. Upstream's "Skip Free" and "Excluded keywords" moved into it. Upstream's `meetingsOnly` logic is kept in `ReminderFilter` but not shown in the UI.
- **Snooze:** upstream's configurable snooze menu, with our "Remind me on time" as an "Until start" entry.
- **Preview:** upstream's `previewOverlay()`, triggered from General > Test.
- **Settings tabs:** Displays moved into Appearance, Test into General (6 tabs).
- **Working hours:** events have type `.workingHours` and aren't affected by Event Types toggles.
