import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(statusText)
                .font(.headline)

            if let nextTriggerAt = coordinator.runtimeState.nextTriggerAt,
               coordinator.scheduler.status == .countingDown || coordinator.scheduler.status == .paused {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coordinator.scheduler.status == .paused ? "Paused until" : "Next reminder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(nextTriggerAt, style: .time)
                        .font(.body.monospacedDigit())
                }
            }

            Divider()

            Button("Trigger Reminder Now") {
                coordinator.triggerReminderNow()
            }

            if coordinator.scheduler.status == .paused || coordinator.scheduler.status == .disabled {
                Button("Pause") {}
                    .disabled(true)
            } else {
                Menu("Pause") {
                    ForEach(PauseOption.allCases.filter { $0 != .disable }) { option in
                        Button(option.displayName) {
                            coordinator.pause(for: option)
                        }
                    }
                    Divider()
                    Button(PauseOption.disable.displayName) {
                        coordinator.pause(for: .disable)
                    }
                }
            }

            Button("Resume Reminders") {
                coordinator.resumeReminders()
            }
            .disabled(coordinator.scheduler.status != .paused && coordinator.scheduler.status != .disabled)

            Divider()

            Button("Open Settings") {
                coordinator.showSettings()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(14)
        .frame(width: 240)
    }

    private var statusText: String {
        switch coordinator.scheduler.status {
        case .idle:
            return "Idle"
        case .countingDown:
            return "Countdown active"
        case .showingReminder:
            return "Reminder visible"
        case .paused:
            return "Paused"
        case .disabled:
            return "Disabled"
        case .completed:
            return "Completed"
        }
    }
}
