import Foundation
import SwiftData
import SwiftUI

@Model final class PlannerTask {
    @Attribute(.unique) var id: UUID
    var legacyID: Int?
    var title: String
    var details: String
    var day: Date
    var startsAt: String?
    var endsAt: String?
    var isDone: Bool
    var deletedAt: Date?
    var personID: UUID?
    var tagIDs: [UUID]
    var createdAt: Date
    var icon: String?
    init(id: UUID = UUID(), legacyID: Int? = nil, title: String, details: String = "", day: Date = .now, startsAt: String? = nil, endsAt: String? = nil, isDone: Bool = false, deletedAt: Date? = nil, personID: UUID? = nil, tagIDs: [UUID] = [], createdAt: Date = .now, icon: String? = nil) {
        self.id = id; self.legacyID = legacyID; self.title = title; self.details = details; self.day = Calendar.current.startOfDay(for: day)
        self.startsAt = startsAt; self.endsAt = endsAt; self.isDone = isDone; self.deletedAt = deletedAt; self.personID = personID; self.tagIDs = tagIDs; self.createdAt = createdAt; self.icon = icon
    }
}

@Model final class ChecklistItem {
    @Attribute(.unique) var id: UUID
    var taskID: UUID
    var title: String
    var isDone: Bool
    var position: Int
    init(id: UUID = UUID(), taskID: UUID, title: String, isDone: Bool = false, position: Int = 0) { self.id = id; self.taskID = taskID; self.title = title; self.isDone = isDone; self.position = position }
}

@Model final class PlannerTag {
    @Attribute(.unique) var id: UUID
    var legacyID: Int?
    var name: String
    var color: String
    var icon: String?
    init(id: UUID = UUID(), legacyID: Int? = nil, name: String, color: String, icon: String? = nil) { self.id = id; self.legacyID = legacyID; self.name = name; self.color = color; self.icon = icon }
}

@Model final class ClassMeeting {
    @Attribute(.unique) var id: UUID
    var legacyID: Int?
    var weekday: Int
    var startsAt: String
    var endsAt: String
    var subject: String
    var kind: String
    var room: String
    var groupName: String
    var weekParity: String
    var personID: UUID?
    init(id: UUID = UUID(), legacyID: Int? = nil, weekday: Int, startsAt: String, endsAt: String, subject: String, kind: String = "", room: String = "", groupName: String = "", weekParity: String = "all", personID: UUID? = nil) {
        self.id = id; self.legacyID = legacyID; self.weekday = weekday; self.startsAt = startsAt; self.endsAt = endsAt; self.subject = subject; self.kind = kind; self.room = room; self.groupName = groupName; self.weekParity = weekParity; self.personID = personID
    }
}

@Model final class PlannerPerson {
    @Attribute(.unique) var id: UUID
    var legacyID: Int?
    var name: String
    var color: String
    var position: Int
    init(id: UUID = UUID(), legacyID: Int? = nil, name: String, color: String, position: Int = 0) { self.id = id; self.legacyID = legacyID; self.name = name; self.color = color; self.position = position }
}

@Model final class Habit {
    @Attribute(.unique) var id: UUID
    var legacyID: Int?
    var name: String
    var color: String
    var weekdays: [Int]
    var dailyTarget: Int
    var position: Int
    var createdAt: Date
    init(id: UUID = UUID(), legacyID: Int? = nil, name: String, color: String = "green", weekdays: [Int] = Array(1...7), dailyTarget: Int = 1, position: Int = 0, createdAt: Date = .now) {
        self.id = id; self.legacyID = legacyID; self.name = name; self.color = color; self.weekdays = weekdays; self.dailyTarget = dailyTarget; self.position = position; self.createdAt = createdAt
    }
}

@Model final class HabitMark {
    @Attribute(.unique) var id: UUID
    var habitID: UUID
    var day: Date
    var count: Int
    init(id: UUID = UUID(), habitID: UUID, day: Date, count: Int = 0) { self.id = id; self.habitID = habitID; self.day = Calendar.current.startOfDay(for: day); self.count = count }
}

@Model final class PlannerSetting {
    @Attribute(.unique) var key: String
    var value: String
    init(key: String, value: String) { self.key = key; self.value = value }
}

enum PlannerSection: String, CaseIterable, Identifiable {
    case planner = "Планер", tasks = "Задачи", classes = "Пары", people = "Люди", habits = "Привычки", statistics = "Статистика", appearance = "Оформление"
    var id: String { rawValue }
    var symbol: String { switch self { case .planner: "calendar.day.timeline.left"; case .tasks: "checklist"; case .classes: PlannerIcon.lesson; case .people: "person.2"; case .habits: "checkmark.circle"; case .statistics: "chart.bar"; case .appearance: "paintpalette" } }
}

enum PlannerPalette {
    static let colors: [String: Color] = [
        "blue": Color(hex: "4B8DD8"), "green": Color(hex: "469A79"), "red": Color(hex: "D56C69"), "purple": Color(hex: "9072C2"), "orange": Color(hex: "D8894B"), "pink": Color(hex: "CB74A1"), "teal": Color(hex: "409E9C"), "gray": Color(hex: "89919D"), "amber": Color(hex: "92621F")
    ]
    static func label(for key: String) -> String {
        switch key {
        case "amber": "Янтарный"
        case "blue": "Синий"
        case "gray": "Серый"
        case "green": "Зелёный"
        case "orange": "Оранжевый"
        case "pink": "Розовый"
        case "purple": "Фиолетовый"
        case "red": "Красный"
        case "teal": "Бирюзовый"
        default: key
        }
    }

    static func color(_ key: String) -> Color { if colors[key] != nil { return colors[key]! }; if key.count == 6 || key.count == 7 { return Color(hex: key) }; return colors["blue"]! }
}

struct PlannerIconOption: Identifiable {
    let symbol: String
    let title: String
    var id: String { symbol }
}

enum PlannerIcon {
    static let taskDefault = "checklist"
    static let tagDefault = "tag"
    static let lesson = "graduationcap"
    static let options: [PlannerIconOption] = [
        .init(symbol: "checklist", title: "Список"),
        .init(symbol: "briefcase", title: "Работа"),
        .init(symbol: "house", title: "Дом"),
        .init(symbol: "book.closed", title: "Учёба"),
        .init(symbol: "graduationcap", title: "Занятия"),
        .init(symbol: "heart", title: "Личное"),
        .init(symbol: "figure.run", title: "Спорт"),
        .init(symbol: "cart", title: "Покупки"),
        .init(symbol: "phone", title: "Звонок"),
        .init(symbol: "envelope", title: "Письмо"),
        .init(symbol: "star", title: "Важное"),
        .init(symbol: "lightbulb", title: "Идея"),
        .init(symbol: "pencil", title: "Заметка"),
        .init(symbol: "calendar", title: "План"),
        .init(symbol: "fork.knife", title: "Еда"),
        .init(symbol: "airplane", title: "Поездка"),
        .init(symbol: "music.note", title: "Музыка"),
        .init(symbol: "tag", title: "Тег")
    ]
}

extension Color {
    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(srgbRed: 0.29, green: 0.55, blue: 0.85, alpha: 1)
        func byte(_ component: CGFloat) -> Int {
            Int((min(max(component, 0), 1) * 255).rounded())
        }
        return String(format: "#%02X%02X%02X", byte(color.redComponent), byte(color.greenComponent), byte(color.blueComponent))
    }
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(.sRGB, red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
    }
}

extension Date {
    var plannerDay: Date { Calendar.current.startOfDay(for: self) }
    var plannerWeekday: Int { let weekday = Calendar.current.component(.weekday, from: self); return weekday == 1 ? 7 : weekday - 1 }
    func addingDays(_ count: Int) -> Date { Calendar.current.date(byAdding: .day, value: count, to: self) ?? self }
    var russianDay: String { formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.wide).day().month(.wide)) }
}

func parsePlannerDate(_ value: String) -> Date? {
    for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Moscow"); formatter.dateFormat = format
        if let date = formatter.date(from: value) { return date }
    }
    return nil
}

enum AppearanceMigration {
    static func restore(from settings: [String: String]) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "planner.importedAppearance") else { return }
        let keys = ["theme", "accent", "background", "font", "text_size", "radius", "density", "width", "lesson_color", "day_start", "day_end"]
        let values = Dictionary(uniqueKeysWithValues: keys.compactMap { key in settings["appearance.\(key)"].map { (key, $0) } })
        guard !values.isEmpty else { return }
        if let value = values["theme"] { defaults.set(value, forKey: "planner.theme") }
        if let value = values["accent"] { defaults.set(value, forKey: "planner.accent") }
        if let value = values["background"] { defaults.set(value, forKey: "planner.surface") }
        if let value = values["font"] { defaults.set(value, forKey: "planner.font") }
        if let value = values["text_size"] { defaults.set(value, forKey: "planner.textSize") }
        if let value = values["density"] { defaults.set(value, forKey: "planner.density") }
        if let value = values["width"] { defaults.set(value, forKey: "planner.width") }
        if let value = values["lesson_color"] { defaults.set(value, forKey: "planner.lessonColor") }
        if let value = values["day_start"], let hour = Int(value) { defaults.set(hour, forKey: "planner.dayStart") }
        if let value = values["day_end"], let hour = Int(value) { defaults.set(hour, forKey: "planner.dayEnd") }
        if let radius = values["radius"] { defaults.set(radius == "sharp" ? 6.0 : radius == "soft" ? 18.0 : 12.0, forKey: "planner.corner") }
        defaults.set(true, forKey: "planner.importedAppearance")
    }
}
