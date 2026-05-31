import AppKit
import CoreGraphics
import Foundation

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private static let idlePauseThresholdSeconds: TimeInterval = 5 * 60
    private static let anyInputEventType = CGEventType(rawValue: UInt32.max)!

    private let preferencesStore = EyeBreakPreferencesStore()
    private let launchAtLoginController = LaunchAtLoginController()
    private var settings: EyeBreakSettings
    private var session: EyeBreakSession
    private var statusItem: NSStatusItem!
    private var tickTimer: Timer?
    private let overlayController = OverlayWindowController()
    private var settingsWindowController: SettingsWindowController?
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var autoPausedByInactivity = false

    override init() {
        let loadedSettings = preferencesStore.load()
        settings = loadedSettings
        session = EyeBreakSession(settings: loadedSettings)
        super.init()
        overlayController.onSnoozeFiveMinutes = { [weak self] in
            self?.snoozeRestFiveMinutes()
        }
        overlayController.onSkipThisRest = { [weak self] in
            self?.endRestNow()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureStatusItem()
        configureInactivityMonitoring()
        configureTimer()
        refreshPresentation()
        showSettingsOnLaunch()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showSettingsWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tickTimer?.invalidate()
        workspaceObserverTokens.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObserverTokens.removeAll()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refreshStatusButton()
        rebuildMenu()
    }

    private func configureTimer() {
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleTick()
            }
        }
        tickTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func handleTick() {
        evaluateInactivityAutoPause()
        let transitions = session.tick()
        if transitions.contains(.enteredRest) {
            NSSound.beep()
            overlayController.show(remainingSeconds: session.remainingSeconds)
        }
        if transitions.contains(.enteredWork) {
            overlayController.hide()
        }
        refreshPresentation()
    }

    private func configureInactivityMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [NSNotification.Name] = [
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.screensDidWakeNotification,
        ]

        workspaceObserverTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.evaluateInactivityAutoPause()
                }
            }
        }
    }

    private func evaluateInactivityAutoPause() {
        let idleSeconds = currentIdleSeconds()

        if session.status == .running,
           session.phase == .work,
           idleSeconds >= Self.idlePauseThresholdSeconds {
            autoPausedByInactivity = true
            session.pause()
            refreshPresentation()
            return
        }

        if autoPausedByInactivity,
           session.status == .paused,
           session.phase == .work,
           idleSeconds < Self.idlePauseThresholdSeconds {
            autoPausedByInactivity = false
            session.resume()
            refreshPresentation()
        }
    }

    private func currentIdleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: Self.anyInputEventType)
    }

    private func refreshPresentation() {
        if session.phase == .rest {
            overlayController.setVisible(true)
        } else if session.status != .paused {
            overlayController.hide()
        }

        if session.phase == .rest || session.status == .paused {
            overlayController.update(remainingSeconds: session.remainingSeconds)
        }

        refreshStatusButton()
        rebuildMenu()
    }

    private func refreshStatusButton() {
        statusItem.button?.title = statusTitle()
    }

    private func statusTitle() -> String {
        switch session.status {
        case .stopped:
            return Self.formatCountdown(session.remainingSeconds)
        case .running:
            return Self.formatCountdown(session.remainingSeconds)
        case .paused:
            return "⏸ \(Self.formatCountdown(session.remainingSeconds))"
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let summaryItem = NSMenuItem(title: summaryText(), action: nil, keyEquivalent: "")
        summaryItem.isEnabled = false
        menu.addItem(summaryItem)
        menu.addItem(.separator())

        switch session.status {
        case .stopped:
            menu.addItem(menuItem(title: "开始", action: #selector(startTapped), keyEquivalent: "s"))
        case .running:
            if session.phase == .rest {
                menu.addItem(menuItem(title: "延后 5 分钟", action: #selector(snoozeRestTapped), keyEquivalent: ""))
                menu.addItem(menuItem(title: "跳过本次休息", action: #selector(endRestTapped), keyEquivalent: ""))
                menu.addItem(.separator())
            }
            menu.addItem(menuItem(title: "暂停", action: #selector(pauseTapped), keyEquivalent: "p"))
        case .paused:
            menu.addItem(menuItem(title: "继续", action: #selector(resumeTapped), keyEquivalent: "r"))
        }

        menu.addItem(menuItem(title: "重置", action: #selector(resetTapped), keyEquivalent: ""))
        menu.addItem(menuItem(title: "设置…", action: #selector(settingsTapped), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "退出", action: #selector(quitTapped), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func summaryText() -> String {
        let workText = Self.formatCountdown(settings.workSeconds)
        let breakText = Self.formatCountdown(settings.breakSeconds)

        switch session.status {
        case .stopped:
            return "准备就绪 · 工作 \(workText) / 休息 \(breakText)"
        case .running:
            if session.phase == .rest {
                return "休息中 · 剩余 \(Self.formatCountdown(session.remainingSeconds))"
            }
            return "工作中 · 剩余 \(Self.formatCountdown(session.remainingSeconds))"
        case .paused:
            return "已暂停 · 剩余 \(Self.formatCountdown(session.remainingSeconds))"
        }
    }

    private func menuItem(title: String, action: Selector, keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    @objc private func startTapped() {
        autoPausedByInactivity = false
        session.start()
        refreshPresentation()
    }

    @objc private func pauseTapped() {
        autoPausedByInactivity = false
        session.pause()
        refreshPresentation()
    }

    @objc private func resumeTapped() {
        autoPausedByInactivity = false
        session.resume()
        refreshPresentation()
    }

    @objc private func snoozeRestTapped() {
        snoozeRestFiveMinutes()
    }

    @objc private func endRestTapped() {
        endRestNow()
    }

    @objc private func resetTapped() {
        autoPausedByInactivity = false
        session.reset()
        overlayController.hide()
        refreshPresentation()
    }

    @objc private func settingsTapped() {
        showSettingsWindow()
    }

    @objc private func quitTapped() {
        NSApp.terminate(nil)
    }

    private func applySettings(_ updatedSettings: EyeBreakSettings, resetCurrentCycle: Bool) {
        settings = updatedSettings
        preferencesStore.save(updatedSettings)
        session.update(settings: updatedSettings, resetCurrentCycle: resetCurrentCycle)
        refreshPresentation()
    }

    private func showSettingsOnLaunch() {
        showSettingsWindow()
    }

    private func showSettingsWindow() {
        let launchAtLoginEnabled = launchAtLoginController.isEnabled
        let launchAtLoginSupported = launchAtLoginController.isSupported

        if settingsWindowController == nil {
            let controller = SettingsWindowController(
                settings: settings,
                launchAtLoginEnabled: launchAtLoginEnabled,
                launchAtLoginSupported: launchAtLoginSupported
            )
            controller.onSave = { [weak self] updatedSettings, resetCurrentCycle in
                self?.applySettings(updatedSettings, resetCurrentCycle: resetCurrentCycle)
            }
            controller.onLaunchAtLoginChanged = { [weak self] enabled in
                self?.updateLaunchAtLogin(enabled: enabled)
            }
            controller.onClose = { [weak self] in
                self?.settingsWindowController = nil
            }
            settingsWindowController = controller
        } else {
            settingsWindowController?.updateLaunchAtLoginState(
                enabled: launchAtLoginEnabled,
                supported: launchAtLoginSupported
            )
        }
        settingsWindowController?.show()
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
            settingsWindowController?.updateLaunchAtLoginState(
                enabled: launchAtLoginController.isEnabled,
                supported: launchAtLoginController.isSupported
            )
        } catch {
            settingsWindowController?.updateLaunchAtLoginState(
                enabled: launchAtLoginController.isEnabled,
                supported: launchAtLoginController.isSupported
            )
            presentLaunchAtLoginError(error)
        }
    }

    private func snoozeRestFiveMinutes() {
        autoPausedByInactivity = false
        session.snoozeRest(bySeconds: 5 * 60)
        overlayController.update(remainingSeconds: session.remainingSeconds)
        refreshPresentation()
    }

    private func endRestNow() {
        autoPausedByInactivity = false
        session.endRestNow()
        overlayController.hide()
        refreshPresentation()
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "开机自启设置失败"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private static func formatCountdown(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }
}
