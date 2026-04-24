import AppKit

final class InputMonitor {
    private let targetKey: DismissKey
    private let onMatchingKeyPress: () -> Void
    private var localMonitor: Any?
    private var lastKeyDownCode: UInt16?

    init(targetKey: DismissKey, onMatchingKeyPress: @escaping () -> Void) {
        self.targetKey = targetKey
        self.onMatchingKeyPress = onMatchingKeyPress
    }

    func start() {
        stop()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            self?.handle(event)
            // Consume the target key so AppKit doesn't play the system alert sound.
            if event.keyCode == self?.targetKey.keyCode {
                return nil
            }
            return event
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        lastKeyDownCode = nil
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            guard event.keyCode == targetKey.keyCode else { return }
            guard lastKeyDownCode != event.keyCode else { return }
            lastKeyDownCode = event.keyCode
            onMatchingKeyPress()
        case .keyUp:
            if event.keyCode == lastKeyDownCode {
                lastKeyDownCode = nil
            }
        default:
            break
        }
    }
}
