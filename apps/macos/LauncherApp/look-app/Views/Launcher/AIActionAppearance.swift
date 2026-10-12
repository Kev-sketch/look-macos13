import AppKit
import UniformTypeIdentifiers

/// How a planner-proposed action presents across the launcher: row icon, type
/// badge, and verb, keyed by tool id. The main-bar action row, its preview
/// panel, and the hint lines all read from here, so supporting a new tool is
/// one entry - never another hand-styled row.
enum AIActionAppearance {
    struct Look {
        let symbol: String
        let typeName: String
        let verb: String
    }

    static func look(forToolID toolID: String) -> Look {
        // Explicit `return` in every case: this was a Swift 5.9 switch
        // expression (implicit return), which Swift 5.8 does not parse.
        switch toolID {
        case "calendar.add_event":
            return Look(symbol: "calendar.badge.plus", typeName: "Event", verb: "Add to Calendar")
        case "calendar.block_time":
            return Look(symbol: "timer", typeName: "Focus", verb: "Block time")
        case "calendar.move_event":
            return Look(symbol: "calendar.badge.clock", typeName: "Event", verb: "Reschedule")
        case "calendar.cancel_event":
            return Look(symbol: "calendar.badge.minus", typeName: "Event", verb: "Remove from Calendar")
        case "reminder.add":
            return Look(symbol: "checklist", typeName: "Reminder", verb: "Add Reminder")
        case "reminder.complete":
            return Look(symbol: "checkmark.circle", typeName: "Reminder", verb: "Mark Done")
        case "reminder.remove":
            return Look(symbol: "minus.circle", typeName: "Reminder", verb: "Remove Reminder")
        case "reminder.snooze":
            return Look(symbol: "clock.badge", typeName: "Reminder", verb: "Snooze")
        default:
            return Look(symbol: "sparkles", typeName: "Action", verb: "Run")
        }
    }

    static func icon(forToolID toolID: String) -> NSImage {
        NSImage(systemSymbolName: look(forToolID: toolID).symbol, accessibilityDescription: nil)
            ?? NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil)
            ?? NSWorkspace.shared.icon(for: .plainText)
    }
}
