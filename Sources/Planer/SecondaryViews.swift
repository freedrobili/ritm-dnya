import Charts
import SwiftData
import SwiftUI

struct ClassesView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ClassMeeting.weekday) private var classes: [ClassMeeting]
    @Query(sort: \PlannerPerson.position) private var people: [PlannerPerson]
    @Query private var settings: [PlannerSetting]
    @State private var editing: ClassMeeting?
    @State private var adding = false
    @State private var filterPerson: UUID?
    private let weekdays = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    private var visible: [ClassMeeting] { classes.filter { $0.personID == filterPerson }.sorted { ($0.weekday, $0.startsAt) < ($1.weekday, $1.startsAt) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { VStack(alignment: .leading) { Text("Расписание пар").font(.largeTitle.bold()); Text("Повторяется каждую неделю с учётом чётности и семестра").foregroundStyle(.secondary) }; Spacer(); Button("Добавить пару", systemImage: "plus") { adding = true }.buttonStyle(.borderedProminent) }
            HStack {
                Picker("График", selection: $filterPerson) { Text("Я").tag(Optional<UUID>.none); ForEach(people) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 220)
                DatePicker("Начало семестра", selection: settingBinding("semester_start"), displayedComponents: .date)
                DatePicker("Конец", selection: settingBinding("semester_end"), displayedComponents: .date)
            }
            List {
                ForEach(1...7, id: \.self) { weekday in
                    let rows = visible.filter { $0.weekday == weekday }
                    if !rows.isEmpty {
                        Section(weekdays[weekday - 1]) {
                            ForEach(rows) { lesson in
                                HStack(spacing: 12) {
                                    Text("\(lesson.startsAt)–\(lesson.endsAt)").font(.system(.body, design: .monospaced)).frame(width: 116, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 3) { Label(lesson.subject, systemImage: PlannerIcon.lesson).fontWeight(.semibold); Text([lesson.room, lesson.groupName, lesson.kind].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                                    Spacer(); Text(parityTitle(lesson.weekParity)).font(.caption).padding(5).background(.quaternary, in: Capsule())
                                    Button { editing = lesson } label: { Image(systemName: "pencil") }.buttonStyle(.plain)
                                    Button(role: .destructive) { context.delete(lesson); save() } label: { Image(systemName: "trash") }.buttonStyle(.plain)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                }
            }.listStyle(.inset)
        }.padding(24).sheet(isPresented: $adding) { ClassEditor(lesson: nil, people: people, personID: filterPerson) }.sheet(item: $editing) { ClassEditor(lesson: $0, people: people, personID: $0.personID) }
    }
    private func settingBinding(_ key: String) -> Binding<Date> {
        Binding(get: { settings.first(where: { $0.key == key }).flatMap { parsePlannerDate($0.value) } ?? Date.now }, set: { date in
            if let existing = settings.first(where: { $0.key == key }) { existing.value = iso(date) } else { context.insert(PlannerSetting(key: key, value: iso(date))) }; save()
        })
    }
    private func save() { try? context.save() }
}

struct ClassEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let lesson: ClassMeeting?
    let people: [PlannerPerson]
    let personID: UUID?
    @State private var subject = ""
    @State private var weekday = 1
    @State private var days: Set<Int> = []
    @State private var start = "09:00"
    @State private var end = "10:30"
    @State private var room = ""
    @State private var group = ""
    @State private var kind = ""
    @State private var parity = "all"
    @State private var owner: UUID?
    private let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
    init(lesson: ClassMeeting?, people: [PlannerPerson], personID: UUID?) {
        self.lesson = lesson; self.people = people; self.personID = personID
        _subject = State(initialValue: lesson?.subject ?? ""); _weekday = State(initialValue: lesson?.weekday ?? 1); _days = State(initialValue: lesson.map { [$0.weekday] } ?? [1]); _start = State(initialValue: lesson?.startsAt ?? "09:00"); _end = State(initialValue: lesson?.endsAt ?? "10:30"); _room = State(initialValue: lesson?.room ?? ""); _group = State(initialValue: lesson?.groupName ?? ""); _kind = State(initialValue: lesson?.kind ?? ""); _parity = State(initialValue: lesson?.weekParity ?? "all"); _owner = State(initialValue: lesson?.personID ?? personID)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lesson == nil ? "Новая пара" : "Изменить пару").font(.title2.bold())
            TextField("Название предмета", text: $subject).textFieldStyle(.roundedBorder)
            HStack { TextField("Начало", text: $start).textFieldStyle(.roundedBorder); TextField("Конец", text: $end).textFieldStyle(.roundedBorder) }
            HStack { TextField("Аудитория", text: $room).textFieldStyle(.roundedBorder); TextField("Группа / подгруппа", text: $group).textFieldStyle(.roundedBorder) }
            TextField("Тип занятия", text: $kind).textFieldStyle(.roundedBorder)
            if lesson == nil { HStack { ForEach(1...7, id: \.self) { day in Toggle(dayNames[day - 1], isOn: Binding(get: { days.contains(day) }, set: { if $0 { days.insert(day) } else { days.remove(day) } })).toggleStyle(.button) } } } else { Picker("День недели", selection: $weekday) { ForEach(1...7, id: \.self) { Text(dayNames[$0 - 1]).tag($0) } } }
            Picker("Неделя", selection: $parity) { Text("Каждую").tag("all"); Text("Чётная").tag("even"); Text("Нечётная").tag("odd") }
            Picker("График", selection: $owner) { Text("Я").tag(Optional<UUID>.none); ForEach(people) { Text($0.name).tag(Optional($0.id)) } }
            HStack { Spacer(); Button("Отмена") { dismiss() }; Button("Сохранить") { save() }.keyboardShortcut(.defaultAction).disabled(subject.isEmpty) }
        }.padding(22).frame(width: 540)
    }
    private func save() {
        if let lesson { lesson.subject = subject; lesson.weekday = weekday; lesson.startsAt = start; lesson.endsAt = end; lesson.room = room; lesson.groupName = group; lesson.kind = kind; lesson.weekParity = parity; lesson.personID = owner }
        else { for day in days.sorted() { context.insert(ClassMeeting(weekday: day, startsAt: start, endsAt: end, subject: subject, kind: kind, room: room, groupName: group, weekParity: parity, personID: owner)) } }
        try? context.save(); dismiss()
    }
}

struct PeopleView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannerPerson.position) private var people: [PlannerPerson]
    @Query private var tasks: [PlannerTask]
    @Query private var classes: [ClassMeeting]
    @State private var name = ""
    @State private var color = "blue"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Люди").font(.largeTitle.bold())
            Text("Ведите расписания близких отдельно, переключайтесь между ними и накладывайте графики в планере.").foregroundStyle(.secondary)
            HStack { TextField("Имя человека", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 260); colorPicker; Button("Добавить", systemImage: "plus") { add() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            List(people) { person in
                HStack { Circle().fill(PlannerPalette.color(person.color)).frame(width: 11, height: 11); TextField("Имя", text: Binding(get: { person.name }, set: { person.name = $0; try? context.save() })).font(.headline).frame(width: 190); Picker("Цвет", selection: Binding(get: { person.color }, set: { person.color = $0; try? context.save() })) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Text(key.capitalized).tag(key) } }.frame(width: 130); Spacer(); Text("\(tasks.filter { $0.personID == person.id && $0.deletedAt == nil }.count) задач · \(classes.filter { $0.personID == person.id }.count) пар").foregroundStyle(.secondary); Button(role: .destructive) { remove(person) } label: { Image(systemName: "trash") }.buttonStyle(.plain) }.padding(.vertical, 5)
            }.listStyle(.inset)
            Spacer()
        }.padding(24)
    }
    private var colorPicker: some View { Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text($0.capitalized).tag($0) } }.frame(width: 130) }
    private func add() { context.insert(PlannerPerson(name: name.trimmingCharacters(in: .whitespaces), color: color, position: people.count)); try? context.save(); name = "" }
    private func remove(_ person: PlannerPerson) { tasks.filter { $0.personID == person.id }.forEach(context.delete); classes.filter { $0.personID == person.id }.forEach(context.delete); context.delete(person); try? context.save() }
}

struct HabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.position) private var habits: [Habit]
    @Query private var marks: [HabitMark]
    @State private var week = Date.now.plannerDay
    @State private var name = ""
    @State private var weekdays = Set(1...7)
    @State private var target = 1
    @State private var editing: Habit?
    private var monday: Date { Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: week)?.start.plannerDay ?? week }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { VStack(alignment: .leading) { Text("Привычки").font(.largeTitle.bold()); Text("Отмечайте регулярность и следите за сериями").foregroundStyle(.secondary) }; Spacer(); Button { week = week.addingDays(-7) } label: { Image(systemName: "chevron.left") }; Text(monday.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day().month(.wide))).frame(minWidth: 160); Button { week = week.addingDays(7) } label: { Image(systemName: "chevron.right") } }
            HStack(spacing: 0) {
                Text("Привычка").frame(width: 220, alignment: .leading)
                ForEach(0..<7, id: \.self) { offset in let day = monday.addingDays(offset); VStack { Text(day.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.narrow)).uppercased()); Text(day.formatted(.dateTime.day())).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) }
                Text("Серия").frame(width: 100)
            }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Divider()
            ForEach(habits) { habit in
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 3) { Text(habit.name).font(.headline); Text("Цель: \(habit.dailyTarget) в день").font(.caption).foregroundStyle(.secondary) }.frame(width: 220, alignment: .leading)
                    ForEach(0..<7, id: \.self) { offset in
                        let day = monday.addingDays(offset); let scheduled = habit.weekdays.contains(day.plannerWeekday); let mark = marks.first { $0.habitID == habit.id && $0.day == day.plannerDay }
                        Button { toggle(habit, day: day, mark: mark) } label: {
                            if !scheduled { Text("—").foregroundStyle(.tertiary) }
                            else { ZStack { Circle().stroke(PlannerPalette.color(habit.color).opacity(0.35), lineWidth: 1).frame(width: 31, height: 31); Circle().trim(from: 0, to: min(1, Double(mark?.count ?? 0) / Double(max(1, habit.dailyTarget)))).stroke(PlannerPalette.color(habit.color), style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90)).frame(width: 31, height: 31); if (mark?.count ?? 0) >= habit.dailyTarget { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(PlannerPalette.color(habit.color)) } else if (mark?.count ?? 0) > 0 { Text("\(mark!.count)").font(.caption2) } } }
                        }.buttonStyle(.plain).disabled(!scheduled || day > .now.plannerDay).frame(maxWidth: .infinity)
                    }
                    VStack(spacing: 2) { Text("\(streak(for: habit)) · макс. \(bestStreak(for: habit))").font(.caption); Text("30 дней: \(completionRate(habit))%").font(.caption2).foregroundStyle(.secondary) }.frame(width: 100)
                }.padding(.vertical, 8).contextMenu { Button("Изменить") { editing = habit }; Button("Удалить", role: .destructive) { remove(habit) } }
            }
            Divider()
            HStack { TextField("Новая привычка", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 240); Stepper("Раз в день: \(target)", value: $target, in: 1...50).frame(width: 180); Button("Добавить", systemImage: "plus") { addHabit() }.disabled(name.isEmpty) }
            HStack { ForEach(1...7, id: \.self) { day in Toggle(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][day-1], isOn: Binding(get: { weekdays.contains(day) }, set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } })).toggleStyle(.button) } }
            Spacer()
        }.padding(24).sheet(item: $editing) { HabitEditor(habit: $0) }
    }
    private func toggle(_ habit: Habit, day: Date, mark: HabitMark?) {
        guard habit.weekdays.contains(day.plannerWeekday) else { return }
        if let mark { mark.count = mark.count >= habit.dailyTarget ? 0 : mark.count + 1 }
        else { context.insert(HabitMark(habitID: habit.id, day: day, count: 1)) }
        try? context.save()
    }
    private func addHabit() { context.insert(Habit(name: name, weekdays: weekdays.sorted(), dailyTarget: target, position: habits.count)); try? context.save(); name = "" }
    private func remove(_ habit: Habit) { marks.filter { $0.habitID == habit.id }.forEach(context.delete); context.delete(habit); try? context.save() }
    private func streak(for habit: Habit) -> Int {
        let doneDays = Set(marks.filter { $0.habitID == habit.id && $0.count >= habit.dailyTarget }.map(\.day))
        var cursor = Date.now.plannerDay
        if habit.weekdays.contains(cursor.plannerWeekday) && !marks.contains(where: { $0.habitID == habit.id && $0.day == cursor && $0.count >= habit.dailyTarget }) && !marks.contains(where: { $0.habitID == habit.id && $0.day == cursor && $0.count > 0 }) { cursor = cursor.addingDays(-1) }
        var result = 0
        for _ in 0..<500 { if !habit.weekdays.contains(cursor.plannerWeekday) { cursor = cursor.addingDays(-1); continue }; guard doneDays.contains(cursor) else { break }; result += 1; cursor = cursor.addingDays(-1) }
        return result
    }
    private func bestStreak(for habit: Habit) -> Int {
        let done = Set(marks.filter { $0.habitID == habit.id && $0.count >= habit.dailyTarget }.map(\.day)); guard let first = done.min() else { return 0 }
        var cursor = first; var run = 0; var best = 0
        while cursor <= Date.now.plannerDay { if habit.weekdays.contains(cursor.plannerWeekday) { if done.contains(cursor) { run += 1; best = max(best, run) } else { run = 0 } }; cursor = cursor.addingDays(1) }
        return best
    }
    private func completionRate(_ habit: Habit) -> Int {
        let today = Date.now.plannerDay
        let days = (0..<30).map { today.addingDays(-$0) }.filter { habit.weekdays.contains($0.plannerWeekday) }
        guard !days.isEmpty else { return 0 }
        let completed = days.filter { day in marks.contains { $0.habitID == habit.id && $0.day == day && $0.count >= habit.dailyTarget } }.count
        return completed * 100 / days.count
    }
}

struct HabitEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    @State private var name: String
    @State private var color: String
    @State private var weekdays: Set<Int>
    @State private var target: Int
    init(habit: Habit) { self.habit = habit; _name = State(initialValue: habit.name); _color = State(initialValue: habit.color); _weekdays = State(initialValue: Set(habit.weekdays)); _target = State(initialValue: habit.dailyTarget) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Изменить привычку").font(.title2.bold())
            TextField("Название", text: $name).textFieldStyle(.roundedBorder)
            Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text($0.capitalized).tag($0) } }
            Stepper("Цель в день: \(target)", value: $target, in: 1...50)
            HStack { ForEach(1...7, id: \.self) { day in Toggle(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][day-1], isOn: Binding(get: { weekdays.contains(day) }, set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } })).toggleStyle(.button) } }
            HStack { Spacer(); Button("Отмена") { dismiss() }; Button("Сохранить") { habit.name = name; habit.color = color; habit.weekdays = weekdays.sorted(); habit.dailyTarget = target; try? context.save(); dismiss() }.keyboardShortcut(.defaultAction).disabled(name.isEmpty || weekdays.isEmpty) }
        }.padding(22).frame(width: 500)
    }
}

struct StatisticsView: View {
    @Query(sort: \PlannerTask.day) private var tasks: [PlannerTask]
    @Query(sort: \PlannerTag.name) private var tags: [PlannerTag]
    private var recent: [PlannerTask] { tasks.filter { $0.deletedAt == nil && $0.personID == nil && $0.day >= Calendar.current.date(byAdding: .weekOfYear, value: -7, to: Date.now.plannerDay)! } }
    private var weeks: [(String, Int, Int)] {
        (0..<8).reversed().map { ago in
            let start = Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: Date.now)?.start.addingTimeInterval(Double(-ago * 7 * 86400)) ?? .now
            let end = start.addingTimeInterval(7 * 86400)
            let items = recent.filter { $0.day >= start && $0.day < end }
            return (start.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).day().month(.abbreviated)), items.filter(\.isDone).count, items.count)
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Статистика").font(.largeTitle.bold())
                let done = recent.filter(\.isDone).count
                HStack { metric("Выполнено за 8 недель", "\(done) / \(recent.count)", "\(percent(done, recent.count))%"); metric("Серия сейчас", "\(streak()) дней", "Лучшая: \(bestStreak()) дней"); metric("Сегодня", "\(tasks.filter { Calendar.current.isDateInToday($0.day) && $0.isDone }.count)", "задач выполнено") }
                GroupBox("Задачи по неделям") {
                    Chart(weeks, id: \.0) { week in
                        BarMark(x: .value("Неделя", week.0), y: .value("Выполнено", week.1)).foregroundStyle(Color.accentColor).position(by: .value("Тип", "Выполнено"))
                        BarMark(x: .value("Неделя", week.0), y: .value("Осталось", max(0, week.2 - week.1))).foregroundStyle(Color.accentColor.opacity(0.22)).position(by: .value("Тип", "Осталось"))
                    }.frame(height: 230)
                }
                GroupBox("По дням недели") {
                    let weekdayCounts = (1...7).map { weekday in (weekday, recent.filter { Calendar(identifier: .iso8601).component(.weekday, from: $0.day) == weekday && $0.isDone }.count) }
                    Chart(weekdayCounts, id: \.0) { row in BarMark(x: .value("День", ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][row.0 - 1]), y: .value("Выполнено", row.1)).foregroundStyle(Color.accentColor) }.frame(height: 160)
                }
                GroupBox("По тегам") { ForEach(tags) { tag in let rows = recent.filter { $0.tagIDs.contains(tag.id) }; HStack { Image(systemName: tag.icon ?? PlannerIcon.tagDefault).foregroundStyle(PlannerPalette.color(tag.color)); Text(tag.name); Spacer(); Text("\(rows.filter(\.isDone).count) / \(rows.count)").foregroundStyle(.secondary) } } }
            }.padding(24)
        }
    }
    private func metric(_ title: String, _ value: String, _ foot: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).foregroundStyle(.secondary); Text(value).font(.title.bold()); Text(foot).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12)) }
    private func percent(_ a: Int, _ b: Int) -> Int { b == 0 ? 0 : a * 100 / b }
    private func streak() -> Int { streaks().0 }
    private func bestStreak() -> Int { streaks().1 }
    private func streaks() -> (Int, Int) {
        let days = Set(recent.filter(\.isDone).map(\.day)); var cursor = Date.now.plannerDay; if !days.contains(cursor) { cursor = cursor.addingDays(-1) }; var current = 0
        while days.contains(cursor) { current += 1; cursor = cursor.addingDays(-1) }
        var best = 0; var run = 0; var previous: Date?
        for day in days.sorted() { run = previous.map { Calendar.current.isDate(day, inSameDayAs: $0.addingDays(1)) ? run + 1 : 1 } ?? 1; best = max(best, run); previous = day }
        return (current, best)
    }
}

struct AppearanceView: View {
    @AppStorage("planner.theme") private var theme = "system"
    @AppStorage("planner.accent") private var accent = "blue"
    @AppStorage("planner.surface") private var surface = "paper"
    @AppStorage("planner.font") private var font = "system"
    @AppStorage("planner.textSize") private var textSize = "m"
    @AppStorage("planner.width") private var width = "normal"
    @AppStorage("planner.lessonColor") private var lessonColor = "#7444c4"
    @AppStorage("planner.dayStart") private var dayStart = 7
    @AppStorage("planner.dayEnd") private var dayEnd = 23
    @AppStorage("planner.density") private var density = "comfortable"
    @AppStorage("planner.corner") private var corner = 12.0
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 22) {
            Text("Оформление").font(.largeTitle.bold())
            Text("Настройте тему и акцентный цвет приложения.").foregroundStyle(.secondary)
            GroupBox("Тема") { Picker("Тема", selection: $theme) { Text("Системная").tag("system"); Text("Светлая").tag("light"); Text("Тёмная").tag("dark") }.pickerStyle(.segmented).padding(8) }
            GroupBox("Основной цвет") { LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], spacing: 10) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Button { accent = key } label: { HStack { Circle().fill(PlannerPalette.color(key)).frame(width: 14, height: 14); Text(key.capitalized); if accent == key { Image(systemName: "checkmark") } }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain) } }.padding(8) }
            GroupBox("Свой цвет акцента") { ColorPicker("Выбрать цвет", selection: Binding(get: { PlannerPalette.color(accent) }, set: { accent = $0.hexString }), supportsOpacity: false).padding(8) }
            GroupBox("Фон карточек") { Picker("Палитра", selection: $surface) { Text("Бумага").tag("paper"); Text("Чистый").tag("white"); Text("Тёплый").tag("warm"); Text("Шалфей").tag("sage"); Text("Небо").tag("sky") }.pickerStyle(.segmented).padding(8) }
            GroupBox("Шрифт и размеры") { VStack(alignment: .leading, spacing: 10) { Picker("Стиль текста", selection: $font) { Text("Системный").tag("system"); Text("Книжный").tag("classic"); Text("Мягкий").tag("rounded"); Text("Моно").tag("mono"); Text("Строгий").tag("strict") }; Picker("Размер", selection: $textSize) { Text("Меньше").tag("s"); Text("Обычный").tag("m"); Text("Крупнее").tag("l") }.pickerStyle(.segmented) }.padding(8) }
            GroupBox("Ширина страницы") { Picker("Макет", selection: $width) { Text("Узкий").tag("narrow"); Text("Обычный").tag("normal"); Text("Широкий").tag("wide") }.pickerStyle(.segmented).padding(8) }
            GroupBox("Часы в расписании") { HStack { Picker("С", selection: $dayStart) { ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }; Picker("До", selection: $dayEnd) { ForEach(dayStart..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } } }.padding(8) }
            GroupBox("Цвет пар") { ColorPicker("Выбрать цвет", selection: Binding(get: { PlannerPalette.color(lessonColor) }, set: { lessonColor = $0.hexString }), supportsOpacity: false).padding(8) }
            GroupBox("Плотность и скругление") { VStack(alignment: .leading, spacing: 10) { Picker("Расположение", selection: $density) { Text("Компактно").tag("compact"); Text("Обычно").tag("comfortable"); Text("Просторно").tag("spacious") }.pickerStyle(.segmented); HStack { Text("Скругление карточек"); Slider(value: $corner, in: 6...22, step: 1); Text("\(Int(corner)) pt").monospacedDigit() } }.padding(8) }
        }.padding(24).frame(maxWidth: 700, alignment: .leading)
        }.tint(PlannerPalette.color(accent)).preferredColorScheme(theme == "system" ? nil : (theme == "dark" ? .dark : .light))
    }
}

struct TagManagerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlannerTag.name) private var tags: [PlannerTag]
    @Query private var tasks: [PlannerTask]
    @State private var name = ""
    @State private var color = "blue"
    @State private var icon = PlannerIcon.tagDefault
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Теги").font(.title2.bold())
                Spacer()
                Button("Готово") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            HStack {
                TextField("Название", text: $name).textFieldStyle(.roundedBorder)
                PlannerIconPicker(selection: $icon, title: "Значок нового тега").labelStyle(.iconOnly)
                Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text($0.capitalized).tag($0) } }.frame(width: 120)
                Button("Добавить") {
                    context.insert(PlannerTag(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, icon: icon))
                    try? context.save()
                    name = ""; icon = PlannerIcon.tagDefault
                }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            List(tags) { tag in
                HStack {
                    PlannerIconPicker(selection: Binding(get: { tag.icon ?? PlannerIcon.tagDefault }, set: { tag.icon = $0; try? context.save() }), title: "Значок тега \(tag.name)")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(PlannerPalette.color(tag.color))
                    TextField("Тег", text: Binding(get: { tag.name }, set: { tag.name = $0; try? context.save() }))
                    Picker("Цвет", selection: Binding(get: { tag.color }, set: { tag.color = $0; try? context.save() })) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Text(key.capitalized).tag(key) } }.frame(width: 120)
                    Button(role: .destructive) { tasks.forEach { $0.tagIDs.removeAll { $0 == tag.id } }; context.delete(tag); try? context.save() } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Удалить тег \(tag.name)")
                }
            }
        }.padding(20).frame(width: 500, height: 420)
    }
}

private func iso(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
private func parityTitle(_ value: String) -> String { switch value { case "odd": "Нечётная"; case "even": "Чётная"; default: "Каждую неделю" } }
