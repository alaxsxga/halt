import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: ReminderSettings
    @Published private(set) var runtimeState: ReminderRuntimeState

    private let defaults: UserDefaults
    private let settingsKey = "reminder.settings"
    private let runtimeStateKey = "reminder.runtime-state"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = Self.loadValue(forKey: settingsKey, defaults: defaults, decoder: decoder) ?? .default
        self.runtimeState = Self.loadValue(forKey: runtimeStateKey, defaults: defaults, decoder: decoder) ?? .default
    }

    func update(_ mutate: (inout ReminderSettings) -> Void) {
        var next = settings
        mutate(&next)
        settings = next
        persist(next, forKey: settingsKey)
    }

    func updateRuntimeState(_ mutate: (inout ReminderRuntimeState) -> Void) {
        var next = runtimeState
        mutate(&next)
        runtimeState = next
        persist(next, forKey: runtimeStateKey)
    }

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadValue<T: Decodable>(
        forKey key: String,
        defaults: UserDefaults,
        decoder: JSONDecoder
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
