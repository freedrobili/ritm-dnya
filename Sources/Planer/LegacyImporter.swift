import CSQLite
import Foundation
import SwiftData

@MainActor enum LegacyImporter {
    struct ResultSummary { var tasks = 0; var classes = 0; var people = 0; var habits = 0; var tags = 0 }
    enum ImportError: LocalizedError { case open(String), read(String)
        var errorDescription: String? { switch self { case .open(let message): "Не удалось открыть базу: \(message)"; case .read(let message): "Не удалось прочитать базу: \(message)" } }
    }

    static func importDatabase(at url: URL, into context: ModelContext) throws -> ResultSummary {
        let imported = try context.fetch(FetchDescriptor<PlannerSetting>(predicate: #Predicate { $0.key == "legacy_import_complete" }))
        guard imported.isEmpty else { throw ImportError.read("Перенос из веб-планера уже выполнялся. Повторный импорт может создать дубликаты.") }
        var handle: OpaquePointer?
        guard sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let handle else {
            throw ImportError.open(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_close(handle) }
        var summary = ResultSummary()
        let peopleRows = try rows(handle, "SELECT id,name,color,position FROM people ORDER BY position,id")
        var personMap: [Int: UUID] = [:]
        for row in peopleRows {
            let id = row.int("id")
            let person = PlannerPerson(legacyID: id, name: row.string("name"), color: row.string("color", fallback: "blue"), position: row.int("position"))
            context.insert(person); personMap[id] = person.id; summary.people += 1
        }
        let tagRows = try rows(handle, "SELECT id,name,color FROM tags ORDER BY id")
        var tagMap: [Int: UUID] = [:]
        for row in tagRows {
            let id = row.int("id")
            let tag = PlannerTag(legacyID: id, name: row.string("name"), color: row.string("color", fallback: "blue"))
            context.insert(tag); tagMap[id] = tag.id; summary.tags += 1
        }
        let assignments = (try? rows(handle, "SELECT task_id,tag_id FROM tag_task")) ?? []
        let taskTags = Dictionary(grouping: assignments, by: { $0.int("task_id") })
        let taskRows = try rows(handle, "SELECT id,title,description,date,time,ends_at,done,deleted_at,person_id,created_at FROM tasks")
        var taskMap: [Int: UUID] = [:]
        for row in taskRows {
            let id = row.int("id")
            let tagIDs = (taskTags[id] ?? []).compactMap { tagMap[$0.int("tag_id")] }
            let task = PlannerTask(legacyID: id, title: row.string("title"), details: row.string("description"), day: parseDate(row.string("date")) ?? .now, startsAt: row.optionalString("time"), endsAt: row.optionalString("ends_at"), isDone: row.int("done") != 0, deletedAt: row.optionalDate("deleted_at"), personID: personMap[row.optionalInt("person_id") ?? -1], tagIDs: tagIDs, createdAt: row.optionalDate("created_at") ?? .now)
            context.insert(task); taskMap[id] = task.id; summary.tasks += 1
        }
        for row in try rows(handle, "SELECT task_id,title,done,position FROM task_items ORDER BY position,id") {
            if let taskID = taskMap[row.int("task_id")] { context.insert(ChecklistItem(taskID: taskID, title: row.string("title"), isDone: row.int("done") != 0, position: row.int("position"))) }
        }
        for row in try rows(handle, "SELECT id,weekday,starts_at,ends_at,subject,kind,room,group_name,weeks,person_id FROM lessons") {
            let personID = personMap[row.optionalInt("person_id") ?? -1]
            context.insert(ClassMeeting(legacyID: row.int("id"), weekday: row.int("weekday"), startsAt: row.string("starts_at"), endsAt: row.string("ends_at"), subject: row.string("subject"), kind: row.string("kind"), room: row.string("room"), groupName: row.string("group_name"), weekParity: row.string("weeks", fallback: "all"), personID: personID)); summary.classes += 1
        }
        for row in try rows(handle, "SELECT id,name,color,weekdays,target,position,created_at FROM habits") {
            let weekdays = (try? JSONSerialization.jsonObject(with: Data(row.string("weekdays").utf8))) as? [Int] ?? Array(1...7)
            context.insert(Habit(legacyID: row.int("id"), name: row.string("name"), color: row.string("color", fallback: "green"), weekdays: weekdays, dailyTarget: max(1, row.int("target")), position: row.int("position"), createdAt: row.optionalDate("created_at") ?? .now)); summary.habits += 1
        }
        let habitModels = try context.fetch(FetchDescriptor<Habit>())
        let habitMap = Dictionary(uniqueKeysWithValues: habitModels.compactMap { model in model.legacyID.map { ($0, model.id) } })
        for row in try rows(handle, "SELECT habit_id,date,count FROM habit_checks") {
            if let habitID = habitMap[row.int("habit_id")], let day = parseDate(row.string("date")) { context.insert(HabitMark(habitID: habitID, day: day, count: row.int("count"))) }
        }
        var importedSettings: [String: String] = [:]
        for row in try rows(handle, "SELECT key,value FROM settings") {
            let key = row.string("key"); let value = row.string("value")
            context.insert(PlannerSetting(key: key, value: value)); importedSettings[key] = value
        }
        AppearanceMigration.restore(from: importedSettings)
        context.insert(PlannerSetting(key: "legacy_import_complete", value: url.lastPathComponent))
        try context.save()
        return summary
    }

    private static func rows(_ db: OpaquePointer, _ sql: String) throws -> [[String: String]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            let error = String(cString: sqlite3_errmsg(db))
            if error.localizedCaseInsensitiveContains("no such table") { return [] }
            throw ImportError.read(error)
        }
        defer { sqlite3_finalize(statement) }
        var result: [[String: String]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: String] = [:]
            for column in 0..<sqlite3_column_count(statement) {
                guard let name = sqlite3_column_name(statement, column) else { continue }
                let value = sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
                row[String(cString: name)] = value
            }
            result.append(row)
        }
        return result
    }

    private static func parseDate(_ value: String) -> Date? {
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Moscow"); formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}

private extension Dictionary where Key == String, Value == String {
    func string(_ key: String, fallback: String = "") -> String { self[key] ?? fallback }
    func optionalString(_ key: String) -> String? { guard let value = self[key], !value.isEmpty else { return nil }; return value }
    func int(_ key: String) -> Int { Int(self[key] ?? "") ?? 0 }
    func optionalInt(_ key: String) -> Int? { guard let value = self[key], !value.isEmpty else { return nil }; return Int(value) }
    func optionalDate(_ key: String) -> Date? { guard let value = optionalString(key) else { return nil }; return LegacyImporterDate.parse(value) }
}
private enum LegacyImporterDate {
    static func parse(_ value: String) -> Date? {
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ssXXXXX"] {
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Europe/Moscow"); formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
