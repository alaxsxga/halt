import AppKit
import SwiftUI

@MainActor
final class OverlayPresenter {
    var onDismiss: (() -> Void)?
    var onPause: ((PauseOption) -> Void)?

    private var window: NSPanel?
    private var inputMonitor: InputMonitor?
    private var reminderSession: ReminderSession?
    private var workspaceObserver: NSObjectProtocol?

    func present(content: ReminderContent, imageBookmark: Data?, dismissKey: DismissKey, requiredPresses: Int) {
        let overlayViewModel = ReminderOverlayViewModel(
            content: content,
            imageBookmark: imageBookmark,
            dismissKey: dismissKey,
            requiredPresses: requiredPresses,
            onDismiss: { [weak self] in self?.onDismiss?() },
            onPause: { [weak self] option in self?.onPause?(option) }
        )

        reminderSession = ReminderSession(
            origin: AppIdentity(application: NSWorkspace.shared.frontmostApplication),
            viewModel: overlayViewModel,
            isVisible: false
        )

        installWorkspaceObserverIfNeeded()
        updateVisibilityForFrontmostApplication()
    }

    func dismiss() {
        inputMonitor?.stop()
        inputMonitor = nil
        window?.close()
        window = nil
        reminderSession = nil
        uninstallWorkspaceObserver()
    }

    private func installWorkspaceObserverIfNeeded() {
        guard workspaceObserver == nil else { return }
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateVisibilityForFrontmostApplication()
            }
        }
    }

    private func uninstallWorkspaceObserver() {
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }
    }

    private func updateVisibilityForFrontmostApplication() {
        guard let reminderSession else { return }
        let frontmost = AppIdentity(application: NSWorkspace.shared.frontmostApplication)
        let selfApp = AppIdentity(application: NSRunningApplication.current)
        // Also keep visible when Halt itself is frontmost (we activated it to receive key events).
        if reminderSession.origin.matches(frontmost) || selfApp.matches(frontmost) {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private func showOverlay() {
        guard var reminderSession else { return }

        let contentView = ReminderOverlayView(viewModel: reminderSession.viewModel)
        let hostingView = NSHostingView(rootView: contentView)
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let frame = screen?.frame else { return }

        let panel: NSPanel
        if let existingPanel = window {
            panel = existingPanel
            panel.setFrame(frame, display: true)
            panel.contentView = hostingView
        } else {
            let createdPanel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            createdPanel.collectionBehavior = [
                NSWindow.CollectionBehavior.canJoinAllSpaces,
                NSWindow.CollectionBehavior.fullScreenAuxiliary
            ]
            createdPanel.isOpaque = false
            createdPanel.backgroundColor = NSColor.clear
            createdPanel.level = NSWindow.Level.statusBar
            createdPanel.hasShadow = false
            createdPanel.ignoresMouseEvents = false
            createdPanel.contentView = hostingView
            window = createdPanel
            panel = createdPanel
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        if inputMonitor == nil {
            inputMonitor = InputMonitor(targetKey: reminderSession.viewModel.dismissKey) {
                reminderSession.viewModel.registerPress()
            }
            inputMonitor?.start()
        }

        reminderSession.isVisible = true
        self.reminderSession = reminderSession
    }

    private func hideOverlay() {
        guard var reminderSession else { return }
        inputMonitor?.stop()
        inputMonitor = nil
        window?.orderOut(nil)
        reminderSession.isVisible = false
        self.reminderSession = reminderSession
    }
}

private struct ReminderSession {
    let origin: AppIdentity
    let viewModel: ReminderOverlayViewModel
    var isVisible: Bool
}

private struct AppIdentity {
    let bundleIdentifier: String?
    let processIdentifier: pid_t?

    init(application: NSRunningApplication?) {
        self.bundleIdentifier = application?.bundleIdentifier
        self.processIdentifier = application?.processIdentifier
    }

    func matches(_ other: AppIdentity) -> Bool {
        if let bundleIdentifier, let otherBundleIdentifier = other.bundleIdentifier {
            return bundleIdentifier == otherBundleIdentifier
        }
        if let processIdentifier, let otherProcessIdentifier = other.processIdentifier {
            return processIdentifier == otherProcessIdentifier
        }
        return false
    }
}
