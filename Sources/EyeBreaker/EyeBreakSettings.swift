import Foundation

struct EyeBreakSettings: Codable, Equatable {
    var workMinutes: Int
    var breakMinutes: Int

    init(workMinutes: Int, breakMinutes: Int) {
        self.workMinutes = max(1, workMinutes)
        self.breakMinutes = max(1, breakMinutes)
    }

    var workSeconds: Int {
        workMinutes * 60
    }

    var breakSeconds: Int {
        breakMinutes * 60
    }

    static let defaultValue = EyeBreakSettings(workMinutes: 20, breakMinutes: 1)
}
