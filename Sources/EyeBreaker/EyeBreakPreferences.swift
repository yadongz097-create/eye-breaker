import Foundation

struct EyeBreakPreferencesStore {
    private let userDefaults: UserDefaults
    private let key = "EyeBreaker.preferences.v1"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> EyeBreakSettings {
        guard
            let data = userDefaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(EyeBreakSettings.self, from: data)
        else {
            return .defaultValue
        }

        return decoded
    }

    func save(_ settings: EyeBreakSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        userDefaults.set(data, forKey: key)
    }
}
