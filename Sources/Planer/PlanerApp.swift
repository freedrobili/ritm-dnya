import SwiftData
import SwiftUI

@main struct PlanerApp: App {
    private let container: ModelContainer
    init() {
        let schema = Schema([PlannerTask.self, ChecklistItem.self, PlannerTag.self, ClassMeeting.self, PlannerPerson.self, Habit.self, HabitMark.self, PlannerSetting.self])
        let configuration = ModelConfiguration("Planer", schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let settings = try context.fetch(FetchDescriptor<PlannerSetting>())
            AppearanceMigration.restore(from: Dictionary(uniqueKeysWithValues: settings.map { ($0.key, $0.value) }))
        } catch { fatalError("Не удалось открыть локальную базу планера: \(error)") }
    }
    var body: some Scene {
        WindowGroup("Ритм дня") { ContentView().modelContainer(container).frame(minWidth: 1100, minHeight: 680) }
            .windowResizability(.contentMinSize)
            .commands { SidebarCommands() }
    }
}
