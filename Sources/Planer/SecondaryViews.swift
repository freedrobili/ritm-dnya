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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if visible.isEmpty {
                        ContentUnavailableView("Пар пока нет", systemImage: PlannerIcon.lesson, description: Text("Добавьте пару для выбранного графика."))
                            .frame(maxWidth: .infinity)
                            .rhythmCard()
                    }
                    ForEach(1...7, id: \.self) { weekday in
                        let rows = visible.filter { $0.weekday == weekday }
                        if !rows.isEmpty {
                            SectionCard(weekdays[weekday - 1]) {
                                ForEach(rows) { lesson in
                                    HStack(spacing: 12) {
                                        Text("\(lesson.startsAt)–\(lesson.endsAt)").font(.system(.body, design: .monospaced)).frame(width: 116, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 3) { Label(lesson.subject, systemImage: PlannerIcon.lesson).fontWeight(.semibold); Text([lesson.room, lesson.groupName, lesson.kind].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary) }
                                        Spacer(); Text(parityTitle(lesson.weekParity)).font(.caption).padding(5).background(.quaternary, in: Capsule())
                                        Button { editing = lesson } label: { Image(systemName: "pencil") }
                                            .accessibilityLabel("Изменить пару: \(lesson.subject)").help("Изменить пару")
                                        Button(role: .destructive) { context.delete(lesson); save() } label: { Image(systemName: "trash") }
                                            .accessibilityLabel("Удалить пару: \(lesson.subject)").help("Удалить пару")
                                    }.padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
                .padding(1)
            }
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
    private var canSave: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (lesson != nil || !days.isEmpty)
    }
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
            HStack { Spacer(); Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction); Button("Сохранить") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!canSave) }
        }.rhythmEditor(width: 540)
    }
    private func save() {
        guard canSave else { return }
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
    @State private var personToDelete: PlannerPerson?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Люди").font(.largeTitle.bold())
            Text("Ведите расписания близких отдельно, переключайтесь между ними и накладывайте графики в планере.").foregroundStyle(.secondary)
            HStack { TextField("Имя человека", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 260); colorPicker; Button("Добавить", systemImage: "plus") { add() }.buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if people.isEmpty {
                        ContentUnavailableView("Графиков пока нет", systemImage: "person.2", description: Text("Добавьте человека, чтобы вести его расписание."))
                            .frame(maxWidth: .infinity)
                            .rhythmCard()
                    }
                    ForEach(people) { person in
                        HStack(spacing: 12) {
                            Circle().fill(PlannerPalette.color(person.color)).frame(width: 11, height: 11).accessibilityHidden(true)
                            TextField("Имя", text: Binding(get: { person.name }, set: { person.name = $0; try? context.save() }))
                                .font(.headline).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                            Picker("Цвет", selection: Binding(get: { person.color }, set: { person.color = $0; try? context.save() })) {
                                ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Text(PlannerPalette.label(for: key)).tag(key) }
                            }.frame(width: 136)
                            Spacer(minLength: 8)
                            Text("\(tasks.filter { $0.personID == person.id && $0.deletedAt == nil }.count) задач · \(classes.filter { $0.personID == person.id }.count) пар")
                                .foregroundStyle(.secondary)
                            Button(role: .destructive) { personToDelete = person } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Удалить график: \(person.name)").help("Удалить график")
                        }
                        .rhythmCard()
                    }
                }.padding(1)
            }
        }
        .padding(24)
        .confirmationDialog("Удалить график?", isPresented: Binding(
            get: { personToDelete != nil },
            set: { if !$0 { personToDelete = nil } }
        ), presenting: personToDelete) { person in
            Button("Удалить", role: .destructive) { remove(person) }
        } message: { person in
            Text("График «\(person.name)», его задачи и пары будут удалены.")
        }
    }
    private var colorPicker: some View { Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text(PlannerPalette.label(for: $0)).tag($0) } }.frame(width: 130) }
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
    @Environment(\.rhythmPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Привычки").font(.largeTitle.bold())
                    Spacer()
                    Button { week = week.addingDays(-7) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("Предыдущая неделя")
                    Button("Сегодня") { week = .now.plannerDay }
                    Button { week = week.addingDays(7) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("Следующая неделя")
                }
                SectionCard("Новая привычка") {
                    HStack(spacing: 12) {
                        TextField("Название привычки", text: $name).textFieldStyle(.roundedBorder)
                        Stepper("Раз в день: \(target)", value: $target, in: 1...50)
                        Button("Добавить", systemImage: "plus", action: addHabit)
                            .buttonStyle(.borderedProminent)
                            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdays.isEmpty)
                    }
                    weekdayToggles(selection: $weekdays)
                }
                SectionCard(monday.formatted(.dateTime.day().month(.wide)) + " – " + monday.addingDays(6).formatted(.dateTime.day().month(.wide))) {
                    HStack(spacing: 4) {
                        Text("Привычка").frame(width: 164, alignment: .leading)
                        ForEach(0..<7, id: \.self) { offset in
                            let day = monday.addingDays(offset)
                            Text(day.formatted(.dateTime.weekday(.abbreviated).day()))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(day == .now.plannerDay ? palette.selected : .clear, in: RoundedRectangle(cornerRadius: palette.controlRadius))
                        }
                        Text("Серия").frame(width: 88)
                        Color.clear.frame(width: 32, height: 1).accessibilityHidden(true)
                    }.font(.caption.weight(.semibold)).foregroundStyle(palette.muted)
                    if habits.isEmpty {
                        ContentUnavailableView("Привычек пока нет", systemImage: "checkmark.circle", description: Text("Добавьте первую привычку выше."))
                            .frame(maxWidth: .infinity)
                    }
                    ForEach(habits) { habit in
                        Divider()
                        habitRow(habit)
                    }
                }
            }
            .padding(24)
        }
        .sheet(item: $editing) { HabitEditor(habit: $0) }
    }

    private func habitRow(_ habit: Habit) -> some View {
        HStack(spacing: 4) {
            Button { editing = habit } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.name).font(.headline).lineLimit(2)
                    Text("Цель: \(habit.dailyTarget) в день").font(.caption).foregroundStyle(palette.muted)
                }
                .frame(width: 164, alignment: .leading)
                .contentShape(Rectangle())
            }.buttonStyle(RhythmPressStyle()).help("Изменить привычку")
            ForEach(0..<7, id: \.self) { offset in
                habitCell(habit, day: monday.addingDays(offset))
            }
            VStack(spacing: 2) {
                Text("\(streak(for: habit)) · макс. \(bestStreak(for: habit))").font(.caption)
                Text("30 дней: \(completionRate(habit))%").font(.caption2).foregroundStyle(palette.muted)
            }.frame(width: 88)
            Menu {
                Button("Изменить") { editing = habit }
                Button("Удалить", role: .destructive) { remove(habit) }
            } label: { Image(systemName: "ellipsis.circle") }
            .menuIndicator(.hidden)
            .frame(width: 32)
            .accessibilityLabel("Действия: \(habit.name)")
        }
    }

    private func habitCell(_ habit: Habit, day: Date) -> some View {
        let mark = marks.first { $0.habitID == habit.id && $0.day == day }
        let count = mark?.count ?? 0
        let color = PlannerPalette.color(habit.color)
        return Group {
            if habit.weekdays.contains(day.plannerWeekday) {
                Button { toggle(habit, day: day, mark: mark) } label: {
                    ZStack {
                        Circle().strokeBorder(color.opacity(0.55), lineWidth: 1)
                        Circle().trim(from: 0, to: min(1, Double(count) / Double(max(1, habit.dailyTarget))))
                            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round)).rotationEffect(.degrees(-90))
                        if count >= habit.dailyTarget {
                            Image(systemName: "checkmark").font(.caption.bold())
                        } else if count > 0 {
                            Text("\(count)").font(.caption2.monospacedDigit())
                        }
                    }
                    .frame(width: 28, height: 28)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .disabled(day > .now.plannerDay)
                .accessibilityLabel("\(habit.name), \(day.formatted(.dateTime.day().month(.wide))): \(count) из \(habit.dailyTarget)")
            } else {
                Text("–").foregroundStyle(palette.muted).accessibilityLabel("Нет в расписании")
            }
        }.frame(maxWidth: .infinity)
    }

    private func toggle(_ habit: Habit, day: Date, mark: HabitMark?) {
        guard habit.weekdays.contains(day.plannerWeekday) else { return }
        if let mark { mark.count = mark.count >= habit.dailyTarget ? 0 : mark.count + 1 }
        else { context.insert(HabitMark(habitID: habit.id, day: day, count: 1)) }
        try? context.save()
    }
    private func addHabit() {
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !weekdays.isEmpty else { return }
        context.insert(Habit(name: title, weekdays: weekdays.sorted(), dailyTarget: target, position: habits.count))
        try? context.save()
        name = ""
    }
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
            Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text(PlannerPalette.label(for: $0)).tag($0) } }
            Stepper("Цель в день: \(target)", value: $target, in: 1...50)
            weekdayToggles(selection: $weekdays)
            HStack {
                Spacer()
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Сохранить") {
                    habit.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    habit.color = color
                    habit.weekdays = weekdays.sorted()
                    habit.dailyTarget = target
                    try? context.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdays.isEmpty)
            }
        }.rhythmEditor(width: 500)
    }
}

@MainActor
private func weekdayToggles(selection: Binding<Set<Int>>) -> some View {
    HStack(spacing: 8) {
        ForEach(1...7, id: \.self) { day in
            Toggle(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][day - 1], isOn: Binding(
                get: { selection.wrappedValue.contains(day) },
                set: { enabled in
                    if enabled { selection.wrappedValue.insert(day) }
                    else { selection.wrappedValue.remove(day) }
                }
            )).toggleStyle(.button)
        }
    }
}

struct StatisticsView: View {
    @Environment(\.rhythmPalette) private var palette
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
                SectionCard("Задачи по неделям") {
                    Chart(weeks, id: \.0) { week in
                        BarMark(x: .value("Неделя", week.0), y: .value("Выполнено", week.1)).foregroundStyle(by: .value("Тип", "Выполнено")).position(by: .value("Тип", "Выполнено"))
                        BarMark(x: .value("Неделя", week.0), y: .value("Осталось", max(0, week.2 - week.1))).foregroundStyle(by: .value("Тип", "Осталось")).position(by: .value("Тип", "Осталось"))
                    }
                    .chartForegroundStyleScale(["Выполнено": palette.accent, "Осталось": palette.accent.opacity(0.3)])
                    .chartLegend(position: .bottom, alignment: .leading)
                    .frame(height: 230)
                }
                SectionCard("По дням недели") {
                    let weekdayCounts = (1...7).map { weekday in (weekday, recent.filter { $0.day.plannerWeekday == weekday && $0.isDone }.count) }
                    Chart(weekdayCounts, id: \.0) { row in BarMark(x: .value("День", ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"][row.0 - 1]), y: .value("Выполнено", row.1)).foregroundStyle(palette.accent) }.frame(height: 160)
                }
                SectionCard("По тегам") { ForEach(tags) { tag in let rows = recent.filter { $0.tagIDs.contains(tag.id) }; HStack { Image(systemName: tag.icon ?? PlannerIcon.tagDefault).foregroundStyle(PlannerPalette.color(tag.color)); Text(tag.name); Spacer(); Text("\(rows.filter(\.isDone).count) / \(rows.count)").foregroundStyle(.secondary) } } }
            }.padding(24)
        }
    }
    private func metric(_ title: String, _ value: String, _ foot: String) -> some View { VStack(alignment: .leading, spacing: 8) { Text(title).foregroundStyle(.secondary); Text(value).font(.title.bold()); Text(foot).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, alignment: .leading).rhythmCard() }
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
    @AppStorage("planner.theme") private var theme = "custom"
    @AppStorage("planner.accent") private var accent = "blue"
    @AppStorage("planner.customBackground") private var customBackground = ""
    @State private var backgroundCode = ""
    @AppStorage("planner.surface") private var surface = "paper"
    @AppStorage("planner.font") private var font = "system"
    @AppStorage("planner.textSize") private var textSize = "m"
    @AppStorage("planner.width") private var width = "normal"
    @AppStorage("planner.lessonColor") private var lessonColor = "#7444c4"
    @AppStorage("planner.dayStart") private var dayStart = 7
    @AppStorage("planner.dayEnd") private var dayEnd = 23
    @AppStorage("planner.density") private var density = "comfortable"
    @AppStorage("planner.corner") private var corner = 12.0
    @Environment(\.rhythmPalette) private var palette

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Оформление").font(.largeTitle.bold())
                Text("Настройте тему, фон и акцент приложения.").foregroundStyle(.secondary)
                SectionCard("Тема") { Picker("Тема", selection: $theme) { Text("Светлая").tag("light"); Text("Тёмная").tag("dark"); Text("Кастомная").tag("custom") }.pickerStyle(.segmented).labelsHidden() }
                if theme == "custom" {
                    backgroundSettings
                }
                SectionCard("Основной цвет") { LazyVGrid(columns: [GridItem(.adaptive(minimum: 115))], spacing: 10) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Button { accent = key } label: { HStack { Circle().fill(RhythmPalette.accentColor(theme: theme, key: key, scheme: palette.colorScheme)).frame(width: 14, height: 14); Text(PlannerPalette.label(for: key)); if accent == key { Image(systemName: "checkmark") } }.frame(maxWidth: .infinity, alignment: .leading).padding(9).background(accent == key ? palette.selected : palette.background, in: RoundedRectangle(cornerRadius: palette.controlRadius)).contentShape(Rectangle()) }.buttonStyle(RhythmPressStyle()).accessibilityAddTraits(accent == key ? .isSelected : []) } } }
                SectionCard("Свой цвет акцента") { ColorPicker("Выбрать цвет", selection: Binding(get: { palette.accent }, set: { accent = $0.hexString }), supportsOpacity: false) }
                SectionCard("Фон карточек") { Picker("Палитра", selection: $surface) { Text("Бумага").tag("paper"); Text("Чистый").tag("white"); Text("Тёплый").tag("warm"); Text("Шалфей").tag("sage"); Text("Небо").tag("sky") }.pickerStyle(.segmented) }
                SectionCard("Шрифт и размеры") { VStack(alignment: .leading, spacing: 10) { Picker("Стиль текста", selection: Binding(get: { ["classic", "rounded", "mono"].contains(font) ? font : "system" }, set: { font = $0 })) { Text("Системный").tag("system"); Text("Книжный").tag("classic"); Text("Мягкий").tag("rounded"); Text("Моно").tag("mono") }; Picker("Размер", selection: $textSize) { Text("Меньше").tag("s"); Text("Обычный").tag("m"); Text("Крупнее").tag("l") }.pickerStyle(.segmented) } }
                SectionCard("Ширина страницы") { Picker("Макет", selection: $width) { Text("Узкий").tag("narrow"); Text("Обычный").tag("normal"); Text("Широкий").tag("wide") }.pickerStyle(.segmented) }
                SectionCard("Часы в расписании") { HStack { Picker("С", selection: $dayStart) { ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } }; Picker("До", selection: $dayEnd) { ForEach(min(max(dayStart, 0), 23)..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) } } } }
                SectionCard("Цвет пар") { ColorPicker("Выбрать цвет", selection: Binding(get: { PlannerPalette.color(lessonColor) }, set: { lessonColor = $0.hexString }), supportsOpacity: false) }
                SectionCard("Плотность и скругление") { VStack(alignment: .leading, spacing: 10) { Picker("Расположение", selection: $density) { Text("Компактно").tag("compact"); Text("Обычно").tag("comfortable"); Text("Просторно").tag("spacious") }.pickerStyle(.segmented); HStack { Text("Скругление карточек"); Slider(value: $corner, in: 6...22, step: 1); Text("\(Int(corner)) pt").monospacedDigit() } } }
            }.padding(24).frame(maxWidth: 760, alignment: .leading)
        }
        .onChange(of: customBackground, initial: true) { _, _ in
            updateBackgroundCode()
        }
        .onChange(of: theme) { _, _ in updateBackgroundCode() }
        .onChange(of: dayStart) { _, start in
            if dayEnd < start { dayEnd = start }
        }
    }

    private var backgroundSettings: some View {
        SectionCard("Фон приложения") {
            HStack(spacing: 10) {
                ColorPicker("Цвет фона", selection: Binding(
                    get: { palette.background },
                    set: { customBackground = $0.hexString }
                ), supportsOpacity: false)
                Spacer()
                TextField("HEX", text: $backgroundCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 94)
                    .help("Шесть символов HEX, например #234252")
                    .onSubmit(applyBackgroundCode)
                Button("Применить", action: applyBackgroundCode)
                    .disabled(validBackgroundCode == nil || validBackgroundCode == palette.background.hexString)
                Button("Сбросить фон") { customBackground = "" }
                    .disabled(customBackground.isEmpty)
            }
        }
    }

    private var validBackgroundCode: String? {
        let value = backgroundCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = value.hasPrefix("#") ? value.dropFirst() : value[...]
        guard digits.utf8.count == 6, UInt32(digits, radix: 16) != nil,
              digits.first != "+", digits.first != "-"
        else { return nil }
        return "#" + digits.uppercased()
    }

    private func updateBackgroundCode() {
        if theme == "custom" { backgroundCode = palette.background.hexString }
    }

    private func applyBackgroundCode() {
        guard let validBackgroundCode else { return }
        customBackground = validBackgroundCode
        backgroundCode = validBackgroundCode
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
                Picker("Цвет", selection: $color) { ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { Text(PlannerPalette.label(for: $0)).tag($0) } }.frame(width: 120)
                Button("Добавить") {
                    context.insert(PlannerTag(name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color, icon: icon))
                    try? context.save()
                    name = ""; icon = PlannerIcon.tagDefault
                }.buttonStyle(.borderedProminent).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    if tags.isEmpty {
                        ContentUnavailableView("Тегов пока нет", systemImage: "tag")
                            .frame(maxWidth: .infinity)
                            .rhythmCard()
                    }
                    ForEach(tags) { tag in
                        HStack(spacing: 10) {
                            PlannerIconPicker(selection: Binding(get: { tag.icon ?? PlannerIcon.tagDefault }, set: { tag.icon = $0; try? context.save() }), title: "Значок тега \(tag.name)")
                                .labelStyle(.iconOnly)
                            TextField("Тег", text: Binding(get: { tag.name }, set: { tag.name = $0; try? context.save() }))
                                .textFieldStyle(.roundedBorder)
                            Picker("Цвет", selection: Binding(get: { tag.color }, set: { tag.color = $0; try? context.save() })) {
                                ForEach(Array(PlannerPalette.colors.keys.sorted()), id: \.self) { key in Text(PlannerPalette.label(for: key)).tag(key) }
                            }.frame(width: 126)
                            Button(role: .destructive) {
                                tasks.forEach { $0.tagIDs.removeAll { $0 == tag.id } }
                                context.delete(tag)
                                try? context.save()
                            } label: { Image(systemName: "trash") }
                            .accessibilityLabel("Удалить тег \(tag.name)")
                            .help("Удалить тег")
                        }
                        .rhythmCard(padding: 10)
                    }
                }.padding(1)
            }.frame(height: 260)
        }.rhythmEditor(width: 560)
    }
}

private func iso(_ date: Date) -> String { let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
private func parityTitle(_ value: String) -> String { switch value { case "odd": "Нечётная"; case "even": "Чётная"; default: "Каждую неделю" } }
