import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    func setEnabled(_ enabled: Bool) {
        guard SMAppService.mainApp.status != (enabled ? .enabled : .notRegistered) else { return }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Ignore errors in the initial scaffold. This should surface in UX later.
        }
    }
}
