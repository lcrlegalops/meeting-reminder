import AppKit
import Combine
import SwiftUI

@MainActor
final class FocusCountdownWindowController: NSObject, NSWindowDelegate {
    private static let positionKey = "focusCountdownPosition"
    private static let sizeKey = "focusCountdownSize"
    private static let defaultSize = NSSize(width: 220, height: 90)
    private static let minSize = NSSize(width: 120, height: 60)
    private static let maxSize = NSSize(width: 800, height: 600)

    private var panel: NSPanel?
    private var resetObserver: Any?

    func show(service: FocusCountdownService) {
        guard panel == nil else { return }

        let size = Self.loadSize()
        let origin = Self.loadOrigin(for: size)
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovable = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.minSize = Self.minSize
        panel.maxSize = Self.maxSize
        panel.delegate = self

        let view = FocusCountdownView(service: service)
        panel.contentView = NSHostingView(rootView: view)
        panel.orderFrontRegardless()

        self.panel = panel

        resetObserver = NotificationCenter.default.addObserver(
            forName: .focusCountdownResetPosition,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.resetToDefaultPosition() }
        }
    }

    func close() {
        if let panel = panel {
            Self.saveOrigin(panel.frame.origin)
            panel.orderOut(nil)
        }
        panel = nil
        if let resetObserver {
            NotificationCenter.default.removeObserver(resetObserver)
        }
        resetObserver = nil
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Self.saveOrigin(window.frame.origin)
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        Self.saveSize(window.frame.size)
    }

    private func resetToDefaultPosition() {
        guard let panel else { return }
        UserDefaults.standard.removeObject(forKey: Self.positionKey)
        UserDefaults.standard.removeObject(forKey: Self.sizeKey)
        let size = Self.defaultSize
        let origin = Self.defaultOrigin(for: size)
        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: true)
    }

    private static func loadOrigin(for size: NSSize) -> NSPoint {
        if let saved = UserDefaults.standard.dictionary(forKey: positionKey) as? [String: Double],
           let x = saved["x"], let y = saved["y"] {
            let point = NSPoint(x: x, y: y)
            if NSScreen.screens.contains(where: { $0.frame.contains(point) }) {
                return point
            }
        }
        return defaultOrigin(for: size)
    }

    private static func defaultOrigin(for size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: 100, y: 100)
        }
        let frame = screen.visibleFrame
        return NSPoint(x: frame.maxX - size.width - 20, y: frame.minY + 20)
    }

    private static func saveOrigin(_ point: NSPoint) {
        UserDefaults.standard.set(
            ["x": Double(point.x), "y": Double(point.y)],
            forKey: positionKey
        )
    }

    private static func loadSize() -> NSSize {
        if let saved = UserDefaults.standard.dictionary(forKey: sizeKey) as? [String: Double],
           let w = saved["w"], let h = saved["h"] {
            let clampedW = min(max(w, Double(minSize.width)), Double(maxSize.width))
            let clampedH = min(max(h, Double(minSize.height)), Double(maxSize.height))
            return NSSize(width: clampedW, height: clampedH)
        }
        return defaultSize
    }

    private static func saveSize(_ size: NSSize) {
        UserDefaults.standard.set(
            ["w": Double(size.width), "h": Double(size.height)],
            forKey: sizeKey
        )
    }
}

enum FocusCountdownLayout: String, CaseIterable, Identifiable {
    case modern
    case terminal
    case flip

    static let storageKey = "focusCountdownLayout"
    static let defaultLayout: FocusCountdownLayout = .modern

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .modern: return "Modern"
        case .terminal: return "Terminal"
        case .flip: return "Flip"
        }
    }
}

struct FocusCountdownView: View {
    @ObservedObject var service: FocusCountdownService
    @AppStorage(FocusCountdownLayout.storageKey)
    private var layoutRaw: String = FocusCountdownLayout.defaultLayout.rawValue

    private var layout: FocusCountdownLayout {
        FocusCountdownLayout(rawValue: layoutRaw) ?? .modern
    }

    var body: some View {
        let time: String
        let subtitle: String
        if let event = service.nextEvent {
            time = Self.formatted(service.remaining)
            subtitle = event.title
        } else {
            time = layout == .terminal ? "--:--" : "—:—"
            subtitle = "No meetings"
        }

        return Group {
            switch layout {
            case .modern: ModernDigitalView(time: time, subtitle: subtitle)
            case .terminal: TerminalDigitalView(time: time, subtitle: subtitle)
            case .flip: FlipDigitalView(time: time, subtitle: subtitle)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(4)
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }
}

// MARK: - Digital styles

struct ModernDigitalView: View {
    let time: String
    let subtitle: String

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                VStack(spacing: max(2, h * 0.04)) {
                    Text(time)
                        .font(.system(size: max(14, h * 0.46), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                    Text(subtitle)
                        .font(.system(size: max(8, h * 0.16)))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, max(8, geo.size.width * 0.06))
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

struct TerminalDigitalView: View {
    let time: String
    let subtitle: String

    private static let phosphor = Color(red: 0.30, green: 1.0, blue: 0.45)

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Self.phosphor.opacity(0.45), lineWidth: 1)
                    )

                // Subtle scanlines.
                Canvas { ctx, size in
                    let lineSpacing = max(2, size.height * 0.05)
                    var y: CGFloat = 0
                    while y < size.height {
                        var p = Path()
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(p, with: .color(Self.phosphor.opacity(0.05)),
                                   lineWidth: 0.5)
                        y += lineSpacing
                    }
                }
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: max(1, h * 0.03)) {
                    Text("> \(time)")
                        .font(.system(size: max(14, h * 0.44), weight: .regular, design: .monospaced))
                        .foregroundColor(Self.phosphor)
                        .shadow(color: Self.phosphor.opacity(0.7), radius: max(2, h * 0.05))
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                    Text(subtitle.uppercased())
                        .font(.system(size: max(8, h * 0.15), design: .monospaced))
                        .foregroundColor(Self.phosphor.opacity(0.78))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, max(8, w * 0.05))
                .frame(width: w, height: h, alignment: .leading)
            }
        }
    }
}

struct FlipDigitalView: View {
    let time: String
    let subtitle: String

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let chars = Array(time)
            let digitCount = max(1, chars.filter { $0 != ":" }.count)
            let colonCount = chars.filter { $0 == ":" }.count
            let subtitleH = max(8, h * 0.16)
            let gapBelow = max(2, h * 0.05)
            let rowAvailH = max(20, h - subtitleH - gapBelow)
            let spacing: CGFloat = max(1, h * 0.018)

            // Solve for card size that fits both width and height budgets.
            let totalUnits = CGFloat(digitCount) + CGFloat(colonCount) * 0.4
            let totalSpacing = spacing * CGFloat(max(0, chars.count - 1))
            let widthBudget = max(0, w - totalSpacing - max(8, w * 0.04))
            let unitW = widthBudget / max(0.1, totalUnits)
            let cardH = min(rowAvailH, unitW / 0.62)
            let cardW = cardH * 0.62
            let colonW = cardH * 0.28

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.08))

                VStack(spacing: gapBelow) {
                    HStack(spacing: spacing) {
                        ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                            if ch == ":" {
                                Text(":")
                                    .font(.system(size: cardH * 0.7, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .frame(width: colonW, height: cardH)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: max(2, cardH * 0.08))
                                        .fill(Color(white: 0.16))
                                    Text(String(ch))
                                        .font(.system(size: cardH * 0.72, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                    Rectangle()
                                        .fill(Color.black.opacity(0.55))
                                        .frame(height: 1)
                                }
                                .frame(width: cardW, height: cardH)
                            }
                        }
                    }

                    Text(subtitle)
                        .font(.system(size: subtitleH * 0.85, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, max(8, w * 0.05))
                }
                .frame(width: w, height: h)
            }
        }
    }
}
