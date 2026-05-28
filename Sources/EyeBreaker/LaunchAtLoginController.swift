import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }
        return false
    }

    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        case .notRegistered, .notFound:
            return false
        @unknown default:
            return false
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        guard #available(macOS 13.0, *) else {
            throw LaunchAtLoginError.unsupported
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        switch self {
        case .unsupported:
            return "当前系统版本不支持开机自启切换。"
        }
    }
}
