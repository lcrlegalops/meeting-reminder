import AppKit
import SwiftUI

final class OverlayWindowController {
    private var panels: [NSPanel] = []

    func show(event: MeetingEvent, onDismiss: @escaping () -> Void,
              onSnooze: @escaping () -> Void, onJoin: @escaping () -> Void,
              onRemindOnTime: @escaping () -> Void) {
        close()

        for screen in targetScreens() {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = false
            panel.isMovable = false
            panel.hidesOnDeactivate = false

            let overlayView = OverlayView(
                event: event,
                onDismiss: { [weak self] in
                    self?.close()
                    onDismiss()
                },
                onSnooze: { [weak self] in
                    self?.close()
                    onSnooze()
                },
                onJoin: { [weak self] in
                    self?.close()
                    onJoin()
                },
                onRemindOnTime: { [weak self] in
                    self?.close()
                    onRemindOnTime()
                }
            )

            panel.contentView = NSHostingView(rootView: overlayView)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            panel.makeKey()

            panels.append(panel)
        }

        // Activate the app to receive keyboard events
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        for panel in panels {
            panel.orderOut(nil)
        }
        panels.removeAll()
    }

    /// Screens selected in Settings. Empty selection = all screens.
    /// Falls back to all screens if no selected screen is connected.
    private func targetScreens() -> [NSScreen] {
        let ids = Set(UserDefaults.standard.stringArray(forKey: "enabledScreenIDs") ?? [])
        guard !ids.isEmpty else { return NSScreen.screens }
        let selected = NSScreen.screens.filter { ids.contains($0.stableID) }
        return selected.isEmpty ? NSScreen.screens : selected
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// Display UUID — stable across reboots and reconnects, unlike the raw display ID.
    var stableID: String {
        guard let displayID else { return localizedName }
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let string = CFUUIDCreateString(nil, uuid) {
            return string as String
        }
        return "\(displayID)"
    }
}
