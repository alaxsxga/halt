import SwiftUI

@MainActor
final class ReminderOverlayViewModel: ObservableObject {
    let content: ReminderContent
    let imageBookmark: Data?
    let dismissKey: DismissKey
    let requiredPresses: Int

    @Published private(set) var progress = 0

    private let onDismiss: () -> Void
    private let onPause: (PauseOption) -> Void

    init(
        content: ReminderContent,
        imageBookmark: Data?,
        dismissKey: DismissKey,
        requiredPresses: Int,
        onDismiss: @escaping () -> Void,
        onPause: @escaping (PauseOption) -> Void
    ) {
        self.content = content
        self.imageBookmark = imageBookmark
        self.dismissKey = dismissKey
        self.requiredPresses = requiredPresses
        self.onDismiss = onDismiss
        self.onPause = onPause
    }

    func registerPress() {
        progress += 1
        if progress >= requiredPresses {
            onDismiss()
        }
    }

    func selectPause(_ option: PauseOption) {
        onPause(option)
    }
}

struct ReminderOverlayView: View {
    @ObservedObject var viewModel: ReminderOverlayViewModel

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThickMaterial)
                    .overlay {
                        overlayContent
                    }
                    .frame(
                        width: proxy.size.width * 0.6,
                        height: proxy.size.height * 0.6
                    )
            }
        }
    }

    @ViewBuilder
    private var overlayContent: some View {
        VStack(spacing: 12) {
            switch viewModel.content {
            case .text(let text):
                Text(text)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .image(let path):
                if let nsImage = loadImage(path: path, bookmark: viewModel.imageBookmark) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                        Text("Image could not be loaded.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.progress) / \(viewModel.requiredPresses)")
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Press \(viewModel.dismissKey.displayName) to dismiss")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Menu("Pause") {
                    ForEach(PauseOption.allCases) { option in
                        Button(option.displayName) {
                            viewModel.selectPause(option)
                        }
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(32)
    }
}
