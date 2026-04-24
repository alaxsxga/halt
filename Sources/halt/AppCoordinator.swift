import AppKit
import Combine
import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    let settingsStore: SettingsStore
    let scheduler: ReminderScheduler
    let overlayPresenter: OverlayPresenter
    let launchAtLoginManager: LaunchAtLoginManager

    private var cancellables = Set<AnyCancellable>()
    private var hasPerformedInitialLaunchSetup = false
    private lazy var settingsWindowController = SettingsWindowController(coordinator: self)

    init() {
        let store = SettingsStore()
        let loginManager = LaunchAtLoginManager()
        let overlayPresenter = OverlayPresenter()
        let scheduler = ReminderScheduler(
            settingsStore: store,
            overlayPresenter: overlayPresenter
        )

        self.settingsStore = store
        self.scheduler = scheduler
        self.overlayPresenter = overlayPresenter
        self.launchAtLoginManager = loginManager

        bindSettings()
        scheduler.resetForFreshStart()

        DispatchQueue.main.async { [weak self] in
            self?.handleInitialLaunch()
        }
    }

    var settings: ReminderSettings {
        settingsStore.settings
    }

    var runtimeState: ReminderRuntimeState {
        settingsStore.runtimeState
    }

    var onboardingRequired: Bool {
        settingsStore.settings.hasCompletedOnboarding == false
    }

    func handleInitialLaunch() {
        guard hasPerformedInitialLaunchSetup == false else { return }
        hasPerformedInitialLaunchSetup = true
        showSettings()
    }

    func completeOnboarding() {
        guard onboardingRequired else { return }
        scheduler.resetForFreshStart()
        settingsStore.update { settings in
            settings.hasCompletedOnboarding = true
            settings.remindersEnabled = true
        }
        scheduler.startIfPossible()
        settingsWindowController.closeWindow()
    }

    func showSettings() {
        settingsWindowController.present()
    }

    func closeSettings() {
        settingsWindowController.closeWindow()
    }

    func triggerReminderNow() {
        scheduler.triggerReminderNow()
    }

    func triggerReminderNowFromSettings() {
        scheduler.triggerTestReminder()
    }

    func saveSettingsAndClose() {
        scheduler.resetForFreshStart()
        scheduler.startIfPossible()
        settingsWindowController.closeWindow()
    }

    func enableRemindersAndClose() {
        scheduler.resetForFreshStart()
        settingsStore.update { settings in
            settings.remindersEnabled = true
        }
        scheduler.startIfPossible()
        settingsWindowController.closeWindow()
    }

    func resetOnboardingForDebug() {
        scheduler.resetForFreshStart()
        settingsStore.update { settings in
            settings.hasCompletedOnboarding = false
            settings.remindersEnabled = false
        }
        showSettings()
    }

    func pause(for option: PauseOption) {
        scheduler.pause(for: option)
    }

    func resumeReminders() {
        settingsStore.update { settings in
            settings.remindersEnabled = true
        }
        scheduler.resumeFromManualEnable()
    }

    private func bindSettings() {
        settingsStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        scheduler.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        settingsStore.$settings
            .sink { [weak self] settings in
                self?.launchAtLoginManager.setEnabled(settings.launchAtLoginEnabled)
            }
            .store(in: &cancellables)
    }
}
