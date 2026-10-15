# HLD: Configurable Snooze Durations

## Problem
The overlay's "Snooze" button hardcodes a 1-minute snooze. Users cannot choose a different duration from the overlay, and there is no way to configure which snooze options appear.

## Goal
- Let users pick a snooze duration at the moment the overlay appears.
- Let users configure which duration options are available via the Preferences > General tab.

## Approach

### Storage
- Key: `"snoozeOptions"` in `UserDefaults.standard` as `[Int]` (minutes).
- Default value: `[1, 2, 5, 10]`.
- Accessed via a small helper on `UserDefaults` to avoid raw-array `@AppStorage` limitations.

### Preferences → General tab (`SettingsView.swift`)
- New **"Snooze Options"** section below the existing "Remind me before meetings" picker.
- Shows the full candidate list: 1, 2, 5, 10, 15 minutes.
- Each candidate is a `Toggle`; toggling persists the enabled set to `UserDefaults`.
- Validation: at least one option must remain enabled (disable the toggle for the last remaining item).

### Overlay (`OverlayView.swift`)
- Replace the plain `Button("Snooze 1 min")` with a `Menu` button.
- Label: `"Snooze"` with a `clock.arrow.circlepath` icon.
- Menu items: one per enabled snooze option, e.g. "1 minute", "5 minutes".
- Selecting an item calls `onSnooze(minutes:)`.

### `OverlayWindow.swift` (wiring)
- Change `onSnooze: @escaping () -> Void` → `onSnooze: @escaping (Int) -> Void`.
- Pass the chosen duration into `OverlayView`.

### `MeetingMonitor.swift`
- Change `func snooze()` → `func snooze(minutes: Int)`.
- Replace hardcoded `snoozeInterval = 60` with `snoozeInterval = TimeInterval(minutes * 60)`.

### `MeetingReminderApp.swift` (coordinator)
- Update `onSnooze` closure in `OverlayCoordinator` to forward the `minutes` argument.

## Tasks
- [x] T1 — `MeetingMonitor`: accept `minutes` parameter in `snooze(minutes:)` — was already implemented; no change needed
- [x] T2 — `OverlayWindow` / `OverlayView`: thread `(Int) -> Void` closure; replace button with `Menu`
- [x] T3 — `SettingsView`: add Snooze Options section with toggles
- [x] T4 — `MeetingReminderApp`: update coordinator closure signature

## Out of scope
- Custom free-text duration entry.
- Per-meeting snooze history.
- Reordering snooze options.

## Known limitations
- `@AppStorage` does not support `[Int]`, so we read/write `UserDefaults` directly in `SettingsView` using `onAppear` / `onChange`.
