import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator

    @State private var repeatModeSelection = RepeatModeSelection.infinite
    @State private var fixedRepeatCount = 3
    @State private var contentSelection = ContentSelection.text
    @State private var textContent = ""
    @State private var imagePath = ""
    @State private var isTextEditorFocused: Bool = false

    var body: some View {
        Form {
            Section {
                statusBanner
            }

            Section("Reminder Schedule") {
                Stepper(value: Binding(
                    get: { coordinator.settings.reminderIntervalMinutes },
                    set: { newValue in
                        updateSettings { settings in
                            settings.reminderIntervalMinutes = max(1, newValue)
                        }
                    }
                ), in: 1...120) {
                    HStack {
                        Text("Reminder interval")
                        Spacer()
                        Text("\(coordinator.settings.reminderIntervalMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }

                Picker("Repeat mode", selection: $repeatModeSelection) {
                    ForEach(RepeatModeSelection.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: repeatModeSelection) { _, value in
                    switch value {
                    case .infinite:
                        updateSettings { $0.repeatMode = .infinite }
                    case .fixed:
                        updateSettings { $0.repeatMode = .fixed(count: fixedRepeatCount) }
                    }
                }

                if repeatModeSelection == .fixed {
                    Stepper(value: $fixedRepeatCount, in: 1...10) {
                        HStack {
                            Text("Occurrences")
                            Spacer()
                            Text("\(fixedRepeatCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: fixedRepeatCount) { _, value in
                        updateSettings { $0.repeatMode = .fixed(count: value) }
                    }
                }

                Stepper(value: Binding(
                    get: { coordinator.settings.postDismissDelayMinutes },
                    set: { newValue in
                        updateSettings { settings in
                            settings.postDismissDelayMinutes = newValue
                        }
                    }
                ), in: 0...10) {
                    HStack {
                        Text("Delay before next countdown")
                        Spacer()
                        Text(coordinator.settings.postDismissDelayMinutes == 0 ? "None" : "\(coordinator.settings.postDismissDelayMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Reminder Content") {
                Picker("Content type", selection: $contentSelection) {
                    ForEach(ContentSelection.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .onChange(of: contentSelection) { _, value in
                    switch value {
                    case .text:
                        updateSettings {
                            $0.content = .text(textContent.isEmpty ? $0.lastTextContent : textContent)
                        }
                    case .image:
                        if imagePath.isEmpty == false {
                            updateSettings {
                                $0.content = .image(path: imagePath)
                                $0.lastImagePath = imagePath
                            }
                        }
                    }
                }

                if contentSelection == .text {
                    ZStack(alignment: .topLeading) {
                        InsetTextEditor(text: $textContent, onFocusChange: { isTextEditorFocused = $0 })
                            .frame(minHeight: 80, maxHeight: 160)
                            .onChange(of: textContent) { _, value in
                                updateSettings {
                                    $0.content = .text(value)
                                    $0.lastTextContent = value
                                }
                            }

                        if textContent.isEmpty && !isTextEditorFocused {
                            Text("Reminder text")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 10)
                                .padding(.leading, 6)
                                .allowsHitTesting(false)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    }
                } else {
                    HStack {
                        Text(imagePath.isEmpty ? "No image selected" : imagePath)
                            .foregroundStyle(imagePath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose Image") {
                            selectImage()
                        }
                    }
                }
            }

            Section("Dismissal") {
                Picker("Dismiss key", selection: Binding(
                    get: { coordinator.settings.dismissKey },
                    set: { newValue in
                        updateSettings { settings in
                            settings.dismissKey = newValue
                        }
                    }
                )) {
                    ForEach(DismissKey.allCases) { key in
                        Text(key.displayName).tag(key)
                    }
                }

                Stepper(value: Binding(
                    get: { coordinator.settings.dismissPressCount },
                    set: { newValue in
                        updateSettings { settings in
                            settings.dismissPressCount = newValue
                        }
                    }
                ), in: 1...10) {
                    HStack {
                        Text("Required key presses")
                        Spacer()
                        Text("\(coordinator.settings.dismissPressCount)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Startup And Control") {
                Toggle("Launch at login", isOn: Binding(
                    get: { coordinator.settings.launchAtLoginEnabled },
                    set: { newValue in
                        updateSettings { settings in
                            settings.launchAtLoginEnabled = newValue
                        }
                    }
                ))
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .navigationTitle("Halt Settings")
        .onAppear {
            syncFromSettings()
        }
        .safeAreaInset(edge: .bottom) {
            if coordinator.onboardingRequired {
                onboardingFooter
            } else {
                activeFooter
            }
        }
    }

    private var onboardingFooter: some View {
        HStack {
            Button("Close") {
                coordinator.closeSettings()
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 4) {
                Text("Initial setup is not complete.")
                    .font(.headline)
                Text("Adjust settings first. The countdown starts only after you confirm.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Finish Setup And Start Reminders") {
                coordinator.completeOnboarding()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.bar)
    }

    private var activeFooter: some View {
        HStack {
            Button("Close") {
                coordinator.closeSettings()
            }
            .buttonStyle(.bordered)

            Spacer()

            Button("Show Test Reminder Now") {
                coordinator.triggerReminderNowFromSettings()
            }
            .buttonStyle(.bordered)

            Button(primaryActionTitle) {
                performPrimaryAction()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.bar)
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch coordinator.scheduler.status {
        case .countingDown:
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reminders Active")
                        .font(.headline)
                    if let next = coordinator.runtimeState.nextTriggerAt {
                        Text("Next reminder at \(next.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .paused:
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paused")
                        .font(.headline)
                    if let until = coordinator.runtimeState.pauseUntil {
                        Text("Resumes at \(until.formatted(date: .omitted, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .disabled:
            HStack(spacing: 8) {
                Image(systemName: "slash.circle")
                    .foregroundStyle(.secondary)
                Text("Reminders Disabled")
                    .font(.headline)
            }
        case .completed:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
                Text("All Reminders Completed")
                    .font(.headline)
            }
        case .showingReminder:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(.blue)
                Text("Reminder Currently Showing")
                    .font(.headline)
            }
        case .idle:
            HStack(spacing: 8) {
                Image(systemName: "pause.circle")
                    .foregroundStyle(.secondary)
                Text("Not Started")
                    .font(.headline)
            }
        }
    }

    private var primaryActionTitle: String {
        coordinator.settings.remindersEnabled ? "Save And Restart" : "Enable Reminders"
    }

    private func performPrimaryAction() {
        if coordinator.settings.remindersEnabled {
            coordinator.saveSettingsAndClose()
        } else {
            coordinator.enableRemindersAndClose()
        }
    }

    private func syncFromSettings() {
        switch coordinator.settings.repeatMode {
        case .infinite:
            repeatModeSelection = .infinite
        case .fixed(let count):
            repeatModeSelection = .fixed
            fixedRepeatCount = count
        }

        switch coordinator.settings.content {
        case .text(let text):
            contentSelection = .text
            textContent = text
            imagePath = coordinator.settings.lastImagePath
        case .image(let path):
            contentSelection = .image
            imagePath = path
            textContent = coordinator.settings.lastTextContent
        }
    }

    private func updateSettings(_ mutate: (inout ReminderSettings) -> Void) {
        coordinator.settingsStore.update(mutate)
    }

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            imagePath = url.path
            updateSettings {
                $0.content = .image(path: url.path)
                $0.lastImagePath = url.path
            }
        }
    }
}

private struct InsetTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let textView = FocusAwareTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textContainerInset = NSSize(width: 6, height: 10)
        textView.textContainer?.lineFragmentPadding = 0
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = context.coordinator
        textView.onFocusChange = context.coordinator.onFocusChange

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InsetTextEditor

        init(_ parent: InsetTextEditor) { self.parent = parent }

        func onFocusChange(_ focused: Bool) {
            parent.onFocusChange(focused)
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            guard !textView.hasMarkedText() else { return }
            parent.text = textView.string
        }
    }
}

private class FocusAwareTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result { onFocusChange?(true) }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { onFocusChange?(false) }
        return result
    }
}

private enum RepeatModeSelection: String, CaseIterable, Identifiable {
    case infinite
    case fixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .infinite: return "Repeat indefinitely"
        case .fixed: return "Fixed number of times"
        }
    }
}

private enum ContentSelection: String, CaseIterable, Identifiable {
    case text
    case image

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        }
    }
}
