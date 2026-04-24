import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusCard
                .padding(.bottom, 8)

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

            if coordinator.scheduler.status == .paused || coordinator.scheduler.status == .disabled {
                Button("Resume Reminders") {
                    coordinator.resumeReminders()
                }
            }

            Divider()

            Button("Open Settings") {
                coordinator.showSettings()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }

    @ViewBuilder
    private var statusCard: some View {
        switch coordinator.scheduler.status {
        case .countingDown:
            if let next = coordinator.runtimeState.nextTriggerAt {
                ActiveStatusCard(
                    nextTriggerAt: next,
                    totalSeconds: Double(coordinator.settings.reminderIntervalMinutes * 60),
                    occurrenceText: occurrenceText
                )
            }
        case .paused:
            simpleCard(
                label: "PAUSED",
                color: .orange,
                detail: coordinator.runtimeState.pauseUntil.map {
                    "Resumes at \($0.formatted(date: .omitted, time: .shortened))"
                } ?? "Paused"
            )
        case .disabled:
            simpleCard(label: "DISABLED", color: .gray, detail: "Reminders off")
        case .completed:
            simpleCard(label: "COMPLETED", color: .green, detail: "All reminders done")
        case .showingReminder:
            simpleCard(label: "REMINDER", color: .blue, detail: "Reminder is showing")
        case .idle:
            simpleCard(label: "IDLE", color: .gray, detail: "Not started")
        }
    }

    private func simpleCard(label: String, color: Color, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var occurrenceText: String? {
        guard case .fixed(let total) = coordinator.settings.repeatMode,
              let remaining = coordinator.runtimeState.remainingOccurrences else { return nil }
        let current = total - remaining + 1
        return "Occurrence \(current) of \(total)"
    }

    private func formatRemainingTime(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct ActiveStatusCard: View {
    let nextTriggerAt: Date
    let totalSeconds: Double
    let occurrenceText: String?

    private var progress: Double {
        let remaining = max(0, nextTriggerAt.timeIntervalSinceNow)
        return totalSeconds > 0 ? remaining / totalSeconds : 0
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVE")
                    .font(.caption.bold())
                    .foregroundStyle(Color.green)

                Text("Next reminder at")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(nextTriggerAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if let text = occurrenceText {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 48, height: 48)
        }
        .padding(14)
        .background(Color.green.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
