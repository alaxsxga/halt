import Foundation

enum RepeatMode: Codable, Equatable {
    case infinite
    case fixed(count: Int)

    var displayText: String {
        switch self {
        case .infinite:
            return "Repeat indefinitely"
        case .fixed(let count):
            return "Repeat \(count) times"
        }
    }
}

enum ReminderContent: Codable, Equatable {
    case text(String)
    case image(path: String)
}

enum DismissKey: String, Codable, CaseIterable, Identifiable {
    case rightArrow
    case leftArrow
    case upArrow
    case downArrow
    case space
    case returnKey
    case a
    case b
    case c
    case d
    case e
    case f
    case g
    case h
    case i
    case j
    case k
    case l
    case m
    case n
    case o
    case p
    case q
    case r
    case s
    case t
    case u
    case v
    case w
    case x
    case y
    case z
    case zero
    case one
    case two
    case three
    case four
    case five
    case six
    case seven
    case eight
    case nine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rightArrow: return "Right Arrow"
        case .leftArrow: return "Left Arrow"
        case .upArrow: return "Up Arrow"
        case .downArrow: return "Down Arrow"
        case .space: return "Space"
        case .returnKey: return "Return"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        default: return rawValue.uppercased()
        }
    }

    var keyCode: UInt16 {
        switch self {
        case .a: return 0
        case .s: return 1
        case .d: return 2
        case .f: return 3
        case .h: return 4
        case .g: return 5
        case .z: return 6
        case .x: return 7
        case .c: return 8
        case .v: return 9
        case .b: return 11
        case .q: return 12
        case .w: return 13
        case .e: return 14
        case .r: return 15
        case .y: return 16
        case .t: return 17
        case .one: return 18
        case .two: return 19
        case .three: return 20
        case .four: return 21
        case .six: return 22
        case .five: return 23
        case .returnKey: return 36
        case .seven: return 26
        case .eight: return 28
        case .nine: return 25
        case .zero: return 29
        case .o: return 31
        case .u: return 32
        case .i: return 34
        case .p: return 35
        case .l: return 37
        case .j: return 38
        case .k: return 40
        case .n: return 45
        case .m: return 46
        case .space: return 49
        case .leftArrow: return 123
        case .rightArrow: return 124
        case .downArrow: return 125
        case .upArrow: return 126
        }
    }
}

enum PauseOption: String, CaseIterable, Identifiable {
    case halfHour
    case oneHour
    case twoHours
    case threeHours
    case disable

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .halfHour: return "Pause for 30 minutes"
        case .oneHour: return "Pause for 1 hour"
        case .twoHours: return "Pause for 2 hours"
        case .threeHours: return "Pause for 3 hours"
        case .disable: return "Do not show again"
        }
    }

    var pauseInterval: TimeInterval? {
        switch self {
        case .halfHour: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .threeHours: return 3 * 60 * 60
        case .disable: return nil
        }
    }
}

struct ReminderSettings: Codable, Equatable {
    var hasCompletedOnboarding = false
    var remindersEnabled = true
    var reminderIntervalMinutes = 40
    var repeatMode: RepeatMode = .infinite
    var content: ReminderContent = .text("Time to take a break.")
    var lastTextContent: String = "Time to take a break."
    var lastImagePath: String = ""
    var lastImageBookmark: Data?
    var dismissKey: DismissKey = .rightArrow
    var dismissPressCount = 10
    var postDismissDelayMinutes = 3
    var launchAtLoginEnabled = false

    static let `default` = ReminderSettings()
}

enum SchedulerStatus: Codable, Equatable {
    case idle
    case countingDown
    case showingReminder
    case paused
    case disabled
    case completed

    var menuBarSymbolName: String {
        switch self {
        case .idle:
            return "pause.circle"
        case .countingDown:
            return "timer"
        case .showingReminder:
            return "exclamationmark.circle"
        case .paused:
            return "moon.zzz"
        case .disabled:
            return "slash.circle"
        case .completed:
            return "checkmark.circle"
        }
    }
}

struct ReminderRuntimeState: Codable, Equatable {
    var status: SchedulerStatus = .idle
    var remainingOccurrences: Int?
    var nextTriggerAt: Date?
    var pauseUntil: Date?

    static let `default` = ReminderRuntimeState()
}
