import AppKit
import Foundation

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let contentController: SettingsContentViewController
    var onClose: (() -> Void)?

    var onSave: ((EyeBreakSettings) -> Void)? {
        didSet {
            contentController.onSave = onSave
        }
    }

    var onLaunchAtLoginChanged: ((Bool) -> Void)? {
        didSet {
            contentController.onLaunchAtLoginChanged = onLaunchAtLoginChanged
        }
    }

    init(settings: EyeBreakSettings, launchAtLoginEnabled: Bool, launchAtLoginSupported: Bool) {
        contentController = SettingsContentViewController(
            settings: settings,
            launchAtLoginEnabled: launchAtLoginEnabled,
            launchAtLoginSupported: launchAtLoginSupported
        )
        window = NSWindow(
            contentViewController: contentController
        )
        window.title = "护眼提醒 设置"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 380, height: 332))
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        contentController.onSave = nil
        contentController.onLaunchAtLoginChanged = nil
        super.init()
        window.delegate = self
    }

    func updateLaunchAtLoginState(enabled: Bool, supported: Bool) {
        contentController.updateLaunchAtLoginState(enabled: enabled, supported: supported)
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}

@MainActor
private final class SettingsContentViewController: NSViewController {
    var onSave: ((EyeBreakSettings) -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?

    private let workField = NSTextField()
    private let breakField = NSTextField()
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "开机自启", target: nil, action: nil)
    private let launchAtLoginHint = NSTextField(labelWithString: "")
    private let initialSettings: EyeBreakSettings
    private var launchAtLoginEnabled: Bool
    private var launchAtLoginSupported: Bool

    init(settings: EyeBreakSettings, launchAtLoginEnabled: Bool, launchAtLoginSupported: Bool) {
        initialSettings = settings
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.launchAtLoginSupported = launchAtLoginSupported
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let rootView = NSView()
        rootView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false

        let workRow = makeInputRow(title: "工作分钟", field: workField)
        let workPresets = makePresetRow(title: "常用工作时长", presets: [20, 25, 30, 45], action: #selector(workPresetTapped(_:)))
        let breakRow = makeInputRow(title: "休息分钟", field: breakField)
        let breakPresets = makePresetRow(title: "常用休息时长", presets: [1, 3, 5], action: #selector(breakPresetTapped(_:)))
        let launchAtLoginRow = makeLaunchAtLoginRow()
        let buttonRow = makeButtonRow()

        stack.addArrangedSubview(workRow)
        stack.addArrangedSubview(workPresets)
        stack.addArrangedSubview(breakRow)
        stack.addArrangedSubview(breakPresets)
        stack.addArrangedSubview(launchAtLoginRow)
        stack.addArrangedSubview(buttonRow)

        rootView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: rootView.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: rootView.bottomAnchor, constant: -20),
        ])

        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        workField.stringValue = String(initialSettings.workMinutes)
        breakField.stringValue = String(initialSettings.breakMinutes)
        applyLaunchAtLoginState()
    }

    private func makeInputRow(title: String, field: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.alignment = .left

        field.alignment = .right
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        field.controlSize = .regular
        field.isBezeled = true
        field.isEditable = true
        field.isSelectable = true
        field.delegate = self

        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        formatter.maximum = 999
        field.formatter = formatter
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let row = NSStackView(views: [label, NSView(), field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 12
        return row
    }

    private func makeButtonRow() -> NSStackView {
        let spacer = NSView()
        let cancelButton = NSButton(title: "取消", target: self, action: #selector(cancelTapped))
        cancelButton.bezelStyle = .rounded
        let saveButton = NSButton(title: "保存", target: self, action: #selector(saveTapped))
        saveButton.bezelStyle = .rounded

        let row = NSStackView(views: [spacer, cancelButton, saveButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fill
        row.spacing = 10
        return row
    }

    private func makeLaunchAtLoginRow() -> NSStackView {
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginToggled(_:))
        launchAtLoginCheckbox.controlSize = .regular

        launchAtLoginHint.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        launchAtLoginHint.textColor = .secondaryLabelColor
        launchAtLoginHint.lineBreakMode = .byWordWrapping
        launchAtLoginHint.maximumNumberOfLines = 0
        launchAtLoginHint.translatesAutoresizingMaskIntoConstraints = false

        let row = NSStackView(views: [launchAtLoginCheckbox, launchAtLoginHint])
        row.orientation = .vertical
        row.alignment = .leading
        row.distribution = .fill
        row.spacing = 4
        return row
    }

    private func makePresetRow(title: String, presets: [Int], action: Selector) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor

        let buttons = presets.map { value -> NSButton in
            let button = NSButton(title: "\(value)", target: self, action: action)
            button.bezelStyle = .rounded
            button.tag = value
            return button
        }

        let row = NSStackView(views: [label] + buttons)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.distribution = .fillProportionally
        row.spacing = 8
        return row
    }

    @objc private func cancelTapped() {
        view.window?.close()
    }

    @objc private func saveTapped() {
        let workMinutes = max(1, Int(workField.stringValue) ?? initialSettings.workMinutes)
        let breakMinutes = max(1, Int(breakField.stringValue) ?? initialSettings.breakMinutes)
        onSave?(EyeBreakSettings(workMinutes: workMinutes, breakMinutes: breakMinutes))
        view.window?.close()
    }

    @objc private func workPresetTapped(_ sender: NSButton) {
        workField.stringValue = "\(sender.tag)"
    }

    @objc private func breakPresetTapped(_ sender: NSButton) {
        breakField.stringValue = "\(sender.tag)"
    }

    @objc private func launchAtLoginToggled(_ sender: NSButton) {
        onLaunchAtLoginChanged?(sender.state == .on)
    }

    func updateLaunchAtLoginState(enabled: Bool, supported: Bool) {
        launchAtLoginEnabled = enabled
        launchAtLoginSupported = supported
        applyLaunchAtLoginState()
    }

    private func applyLaunchAtLoginState() {
        launchAtLoginCheckbox.state = launchAtLoginEnabled ? .on : .off
        launchAtLoginCheckbox.isEnabled = launchAtLoginSupported
        if launchAtLoginSupported {
            launchAtLoginHint.stringValue = "登录后自动打开本应用。"
        } else {
            launchAtLoginHint.stringValue = "当前系统版本不支持此功能。"
        }
    }
}

extension SettingsContentViewController: NSTextFieldDelegate {}
