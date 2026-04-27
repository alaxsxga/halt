import Foundation

@MainActor
final class ReminderScheduler: ObservableObject {
    private let settingsStore: SettingsStore
    private let overlayPresenter: OverlayPresenter
    private var timer: Timer?

    @Published private(set) var status: SchedulerStatus
    private var isTestActive = false

    init(settingsStore: SettingsStore, overlayPresenter: OverlayPresenter) {
        self.settingsStore = settingsStore
        self.overlayPresenter = overlayPresenter
        self.status = settingsStore.runtimeState.status
        rewireCallbacks()
    }

    func triggerTestReminder() {
        isTestActive = true
        overlayPresenter.onDismiss = { [weak self] in
            Task { @MainActor in self?.endTestReminder() }
        }
        overlayPresenter.onPause = { [weak self] _ in
            Task { @MainActor in self?.endTestReminder() }
        }
        overlayPresenter.present(
            content: settingsStore.settings.content,
            imageBookmark: settingsStore.settings.lastImageBookmark,
            dismissKey: settingsStore.settings.dismissKey,
            requiredPresses: settingsStore.settings.dismissPressCount
        )
    }

    private func endTestReminder() {
        isTestActive = false
        overlayPresenter.dismiss()
        rewireCallbacks()
    }

    private func rewireCallbacks() {
        overlayPresenter.onDismiss = { [weak self] in
            Task { @MainActor in self?.handleDismiss() }
        }
        overlayPresenter.onPause = { [weak self] option in
            Task { @MainActor in self?.pause(for: option) }
        }
    }

    func startIfPossible() {
        guard settingsStore.settings.remindersEnabled else {
            transition(to: .disabled)
            return
        }

        if let pauseUntil = settingsStore.runtimeState.pauseUntil, pauseUntil > Date() {
            schedule(at: pauseUntil, status: .paused)
            return
        }

        if case .fixed(let configuredCount) = settingsStore.settings.repeatMode,
           settingsStore.runtimeState.remainingOccurrences == nil {
            settingsStore.updateRuntimeState { state in
                state.remainingOccurrences = configuredCount
            }
        }

        if case .fixed = settingsStore.settings.repeatMode,
           (settingsStore.runtimeState.remainingOccurrences ?? 0) <= 0 {
            transition(to: .completed)
            return
        }

        if let nextTriggerAt = settingsStore.runtimeState.nextTriggerAt, nextTriggerAt > Date() {
            schedule(at: nextTriggerAt, status: .countingDown)
            return
        }

        let triggerDate = Date().addingTimeInterval(TimeInterval(settingsStore.settings.reminderIntervalMinutes * 60))
        schedule(at: triggerDate, status: .countingDown)
    }

    func settingsDidChange() {
        timer?.invalidate()
        startIfPossible()
    }

    func triggerReminderNow() {
        timer?.invalidate()
        showReminder()
    }

    func resetForFreshStart() {
        timer?.invalidate()
        overlayPresenter.dismiss()
        settingsStore.updateRuntimeState { state in
            state = .default
            if case .fixed(let configuredCount) = settingsStore.settings.repeatMode {
                state.remainingOccurrences = configuredCount
            }
        }
        status = settingsStore.runtimeState.status
    }

    func pause(for option: PauseOption) {
        overlayPresenter.dismiss()

        guard let interval = option.pauseInterval else {
            settingsStore.update { settings in
                settings.remindersEnabled = false
            }
            settingsStore.updateRuntimeState { state in
                state.pauseUntil = nil
                state.nextTriggerAt = nil
            }
            transition(to: .disabled)
            return
        }

        let resumeDate = Date().addingTimeInterval(interval)
        settingsStore.updateRuntimeState { state in
            state.pauseUntil = resumeDate
            state.nextTriggerAt = resumeDate
        }
        schedule(at: resumeDate, status: .paused)
    }

    func resumeFromManualEnable() {
        settingsStore.updateRuntimeState { state in
            state.pauseUntil = nil
            state.nextTriggerAt = nil
            if case .fixed(let configuredCount) = settingsStore.settings.repeatMode,
               (state.remainingOccurrences ?? 0) <= 0 {
                state.remainingOccurrences = configuredCount
            }
        }
        startIfPossible()
    }

    private func handleDismiss() {
        overlayPresenter.dismiss()

        if case .fixed = settingsStore.settings.repeatMode {
            settingsStore.updateRuntimeState { state in
                if let current = state.remainingOccurrences {
                    state.remainingOccurrences = max(0, current - 1)
                }
            }

            if (settingsStore.runtimeState.remainingOccurrences ?? 0) == 0 {
                settingsStore.updateRuntimeState { state in
                    state.nextTriggerAt = nil
                    state.pauseUntil = nil
                }
                transition(to: .completed)
                return
            }
        }

        let delay = TimeInterval(settingsStore.settings.postDismissDelayMinutes * 60)
        let interval = TimeInterval(settingsStore.settings.reminderIntervalMinutes * 60)
        let nextTrigger = Date().addingTimeInterval(delay + interval)
        schedule(at: nextTrigger, status: .countingDown)
    }

    private func showReminder() {
        if isTestActive { endTestReminder() }
        transition(to: .showingReminder)
        settingsStore.updateRuntimeState { state in
            state.nextTriggerAt = nil
            state.pauseUntil = nil
        }
        overlayPresenter.present(
            content: settingsStore.settings.content,
            imageBookmark: settingsStore.settings.lastImageBookmark,
            dismissKey: settingsStore.settings.dismissKey,
            requiredPresses: settingsStore.settings.dismissPressCount
        )
    }

    private func schedule(at date: Date, status nextStatus: SchedulerStatus) {
        timer?.invalidate()

        let interval = max(0, date.timeIntervalSinceNow)
        settingsStore.updateRuntimeState { state in
            state.status = nextStatus
            state.nextTriggerAt = date
            state.pauseUntil = nextStatus == .paused ? date : nil
        }
        transition(to: nextStatus)

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if nextStatus == .paused {
                    self.startIfPossible()
                } else {
                    self.showReminder()
                }
            }
        }
    }

    private func transition(to newStatus: SchedulerStatus) {
        status = newStatus
        settingsStore.updateRuntimeState { state in
            state.status = newStatus
        }
    }
}
