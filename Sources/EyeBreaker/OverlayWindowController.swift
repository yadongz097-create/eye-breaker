import AppKit
import Foundation

@MainActor
final class OverlayWindowController {
    private let window: NSWindow
    private let titleLabel = NSTextField(labelWithString: "该休息了")
    private let countdownLabel = NSTextField(labelWithString: "20:00")
    private let hintLabel = NSTextField(labelWithString: "把视线移开，看看远处，活动一下肩颈。")
    private var escapeMonitor: Any?
    var onSnoozeFiveMinutes: (() -> Void)?
    var onSkipThisRest: (() -> Void)?

    init() {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.level = .screenSaver
        window.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.76)
        window.isOpaque = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.hidesOnDeactivate = false

        let rootView = NSView(frame: screenFrame)
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 0.76).cgColor

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.distribution = .gravityAreas
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false

        configureLabel(titleLabel, size: 34, weight: .semibold, color: .white)
        configureLabel(countdownLabel, size: 88, weight: .bold, color: .systemGreen)
        configureLabel(hintLabel, size: 20, weight: .regular, color: .white.withAlphaComponent(0.85))

        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(countdownLabel)
        stack.addArrangedSubview(hintLabel)
        stack.addArrangedSubview(makeButtonRow())

        rootView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: rootView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 40),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -40),
        ])

        window.contentView = rootView
    }

    func show(remainingSeconds: Int) {
        update(remainingSeconds: remainingSeconds)
        installEscapeMonitor()
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        removeEscapeMonitor()
        window.orderOut(nil)
    }

    func setVisible(_ visible: Bool) {
        if visible {
            installEscapeMonitor()
            window.orderFrontRegardless()
        } else {
            hide()
        }
    }

    func update(remainingSeconds: Int) {
        countdownLabel.stringValue = Self.formatCountdown(remainingSeconds)
    }

    var isVisible: Bool {
        window.isVisible
    }

    private func configureLabel(_ label: NSTextField, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = false
        label.alignment = .center
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
    }

    private static func formatCountdown(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    private func makeButtonRow() -> NSStackView {
        let snoozeButton = NSButton(title: "延后 5 分钟", target: self, action: #selector(snoozeTapped))
        snoozeButton.bezelStyle = .rounded

        let skipButton = NSButton(title: "跳过本次休息", target: self, action: #selector(skipTapped))
        skipButton.bezelStyle = .rounded
        skipButton.keyEquivalent = "\u{1b}"
        skipButton.keyEquivalentModifierMask = []

        let row = NSStackView(views: [snoozeButton, skipButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillEqually
        row.spacing = 16
        return row
    }

    @objc private func snoozeTapped() {
        onSnoozeFiveMinutes?()
    }

    @objc private func skipTapped() {
        onSkipThisRest?()
    }

    private func installEscapeMonitor() {
        guard escapeMonitor == nil else { return }
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isVisible else {
                return event
            }
            if event.keyCode == 53 || event.charactersIgnoringModifiers == "\u{1b}" {
                self.skipTapped()
                return nil
            }
            return event
        }
    }

    private func removeEscapeMonitor() {
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }
}
