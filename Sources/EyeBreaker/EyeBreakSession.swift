import Foundation

struct EyeBreakSession: Equatable {
    enum Transition: Equatable {
        case enteredRest
        case enteredWork
    }

    enum Phase: Equatable {
        case idle
        case work
        case rest
    }

    enum Status: Equatable {
        case stopped
        case running
        case paused
    }

    private(set) var phase: Phase
    private(set) var status: Status
    private(set) var remainingSeconds: Int
    private(set) var settings: EyeBreakSettings

    init(settings: EyeBreakSettings) {
        self.settings = settings
        phase = .idle
        status = .stopped
        remainingSeconds = settings.workSeconds
    }

    mutating func start() {
        switch status {
        case .running:
            break
        case .paused:
            status = .running
        case .stopped:
            phase = .work
            status = .running
            remainingSeconds = settings.workSeconds
        }
    }

    mutating func pause() {
        guard status == .running else {
            return
        }
        status = .paused
    }

    mutating func resume() {
        guard status == .paused else {
            return
        }
        status = .running
    }

    mutating func reset() {
        phase = .idle
        status = .stopped
        remainingSeconds = settings.workSeconds
    }

    mutating func update(settings newSettings: EyeBreakSettings, resetCurrentCycle: Bool = false) {
        settings = newSettings
        if resetCurrentCycle {
            phase = .work
            remainingSeconds = newSettings.workSeconds
            if status != .paused {
                status = .running
            }
        } else if status == .stopped || phase == .idle {
            remainingSeconds = newSettings.workSeconds
        }
    }

    mutating func snoozeRest(bySeconds additionalSeconds: Int) {
        guard phase == .rest else {
            return
        }

        remainingSeconds += max(1, additionalSeconds)
    }

    mutating func endRestNow() {
        guard phase == .rest else {
            return
        }

        phase = .work
        status = .running
        remainingSeconds = settings.workSeconds
    }

    mutating func tick(seconds: Int = 1) -> [Transition] {
        guard status == .running, seconds > 0 else {
            return []
        }

        var transitions: [Transition] = []
        for _ in 0..<seconds {
            if let transition = advanceOneSecond() {
                transitions.append(transition)
            }
        }
        return transitions
    }

    private mutating func advanceOneSecond() -> Transition? {
        remainingSeconds -= 1
        guard remainingSeconds <= 0 else {
            return nil
        }

        switch phase {
        case .idle, .work:
            phase = .rest
            remainingSeconds = settings.breakSeconds
            return .enteredRest
        case .rest:
            phase = .work
            remainingSeconds = settings.workSeconds
            return .enteredWork
        }
    }
}
