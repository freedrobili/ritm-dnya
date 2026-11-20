import AppKit
import Charts
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("planner.theme") private var theme = "custom"
    @AppStorage("planner.accent") private var accent = "blue"
    @AppStorage("planner.textSize") private var textSize = "m"
    @AppStorage("planner.font") private var fontName = "system"
    @AppStorage("planner.width") private var pageWidth = "normal"
    @State private var section: PlannerSection = .planner
    @State private var plannerDate = Date.now.plannerDay
    @AppStorage("planner.surface") private var surface = "paper"
    @AppStorage("planner.customBackground") private var customBackground = ""
    @AppStorage("planner.corner") private var corner = 12.0
    @State private var showingImport = false
    @State private var message: String?
    @AppStorage("planner.weekMode") private var weekMode = false
    private var palette: RhythmPalette {
        RhythmPalette(theme: theme, accent: accent, surface: surface, radius: corner, customBackground: customBackground)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ПЛАНЕР").font(.caption.weight(.medium)).foregroundStyle(palette.muted).padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 8)
                sidebarButton("Сегодня", symbol: "calendar", section: .planner)
                sidebarButton("Неделя", symbol: "calendar.day.timeline.left", section: .planner, showsWeek: true)
                sidebarButton("Задачи", symbol: PlannerSection.tasks.symbol, section: .tasks)
                sidebarButton("Пары", symbol: PlannerIcon.lesson, section: .classes)
                sidebarButton("Привычки", symbol: "checkmark.circle", section: .habits)
                sidebarButton("Люди", symbol: "person.2", section: .people)
                sidebarButton("Статистика", symbol: "chart.bar", section: .statistics)
                Spacer()
                sidebarButton("Оформление", symbol: "gearshape", section: .appearance)
                Button { showingImport = true } label: { Label("Перенести данные", systemImage: "square.and.arrow.down").font(.caption) }
                    .buttonStyle(.plain).foregroundStyle(palette.muted).padding(.horizontal, 24).padding(.bottom, 20)
            }
            .frame(width: 220)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(palette.sidebar)
            Rectangle().fill(palette.line).frame(width: 1)
            Group {
                switch section {
                case .planner: PlannerView(date: $plannerDate, weekMode: $weekMode)
                case .tasks: TasksView()
                case .classes: ClassesView()
                case .people: PeopleView()
                case .habits: HabitsView()
                case .statistics: StatisticsView()
                case .appearance: AppearanceView()
                }
            }
            .frame(maxWidth: pageWidth == "narrow" ? 1250 : (pageWidth == "wide" ? 1900 : 1580), maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(palette.background)
        .foregroundStyle(palette.foreground)
        .environment(\.rhythmPalette, palette)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        .onAppear { if theme == "system" { theme = "custom" } }
        .fileImporter(isPresented: $showingImport, allowedContentTypes: [.data, .item], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                let summary = try LegacyImporter.importDatabase(at: url, into: context)
                message = "Перенесено: задач — \(summary.tasks), пар — \(summary.classes), людей — \(summary.people), привычек — \(summary.habits), тегов — \(summary.tags)."
            } catch { message = error.localizedDescription }
        }
        .tint(palette.accent)
        .environment(\.dynamicTypeSize, textSize == "s" ? .small : (textSize == "l" ? .large : .medium))
        .environment(\.font, .system(.body, design: fontName == "classic" ? .serif : (fontName == "rounded" ? .rounded : (fontName == "mono" ? .monospaced : .default))))
        .preferredColorScheme(palette.colorScheme)
        .alert("Перенос данных", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Хорошо") { message = nil }
        } message: { Text(message ?? "") }
    }

    private func sidebarButton(_ title: String, symbol: String, section target: PlannerSection, showsWeek: Bool = false) -> some View {
        let selected = section == target && (target != .planner || weekMode == showsWeek)
        return Button {
            section = target
            if target == .planner {
                weekMode = showsWeek
                if !showsWeek { plannerDate = .now.plannerDay }
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 16, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(selected ? palette.selected : .clear, in: RoundedRectangle(cornerRadius: palette.controlRadius))
                .contentShape(Rectangle())
        }
        .buttonStyle(RhythmPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
        .padding(.horizontal, 12)
    }
}

struct RhythmPalette {
    let background: Color
    let sidebar: Color
    let card: Color
    let selected: Color
    let accent: Color
    let muted: Color
    let line: Color
    let foreground: Color
    let onAccent: Color
    let colorScheme: ColorScheme

    let radius: Double
    var controlRadius: Double { min(radius, 10) }

    init(theme: String, accent: String, surface: String, radius: Double = 12, customBackground: String = "") {
        self.radius = radius
        let isCustom = theme == "custom" || theme == "system"
        let backgroundOverride = isCustom && !customBackground.isEmpty
            ? NSColor(Color(hex: customBackground)).usingColorSpace(.sRGB)
            : nil
        let backgroundLuminance = backgroundOverride.map(Self.luminance)
        let isLight = backgroundLuminance.map { $0 >= 0.179 } ?? (theme == "light")
        colorScheme = isLight ? .light : .dark

        if let backgroundOverride {
            background = Color(nsColor: backgroundOverride)
            let contrastBase: NSColor = isLight ? .white : .black
            let textBase: NSColor = isLight ? .black : .white
            sidebar = Color(nsColor: backgroundOverride.blended(withFraction: 0.12, of: contrastBase) ?? backgroundOverride)
            let highlighted = backgroundOverride.blended(withFraction: 0.18, of: textBase) ?? backgroundOverride
            let readable = isLight ? Self.luminance(highlighted) >= 0.175 : Self.luminance(highlighted) <= 0.183
            let fallback = backgroundOverride.blended(withFraction: 0.27, of: contrastBase) ?? backgroundOverride
            selected = Color(nsColor: readable ? highlighted : fallback)
            foreground = Color(nsColor: textBase)
        } else {
            background = isLight ? Color(hex: "F7F5F8") : (isCustom ? Color(hex: "1B181F") : Color(hex: "17191E"))
            sidebar = isLight ? Color(hex: "EFEBF2") : (isCustom ? Color(hex: "242029") : Color(hex: "20232A"))
            selected = isLight ? Color(hex: "E4D8EE") : (isCustom ? Color(hex: "594A68") : Color(hex: "3B4150"))
            foreground = isLight ? Color(hex: "25212B") : .white
        }

        let baseCard = isLight ? Color.white : (isCustom ? Color(hex: "312D36") : Color(hex: "2A2D35"))
        card = switch surface {
        case "warm": isLight ? Color(hex: "FBF3EB") : Color(hex: "3A302F")
        case "sage": isLight ? Color(hex: "EDF5EF") : Color(hex: "2C3833")
        case "sky": isLight ? Color(hex: "EDF3FA") : Color(hex: "2B3440")
        case "white": isLight ? Color.white : Color(hex: "303239")
        default: baseCard
        }
        self.accent = Self.accentColor(theme: theme, key: accent, scheme: colorScheme)
        let mutedColor = isLight ? Color(hex: "615B68") : Color(hex: "BBB4C0")
        if let backgroundLuminance, let mutedRGB = NSColor(mutedColor).usingColorSpace(.sRGB) {
            let mutedLuminance = Self.luminance(mutedRGB)
            let ratio = (max(backgroundLuminance, mutedLuminance) + 0.05)
                / (min(backgroundLuminance, mutedLuminance) + 0.05)
            muted = ratio >= 4.5 ? mutedColor : foreground
        } else {
            muted = mutedColor
        }
        line = isLight ? Color.black.opacity(0.13) : Color.white.opacity(0.16)
        let accentRGB = NSColor(self.accent).usingColorSpace(.sRGB) ?? .systemBlue
        onAccent = Self.luminance(accentRGB) < 0.179 ? .white : .black
    }

    static func accentColor(theme: String, key: String, scheme: ColorScheme) -> Color {
        if scheme == .dark {
            if key == "blue", theme == "custom" || theme == "system" { return Color(hex: "CFACEF") }
            if key == "amber" { return Color(hex: "D9A960") }
        }
        return PlannerPalette.color(key)
    }

    private static func luminance(_ color: NSColor) -> CGFloat {
        guard let rgb = color.usingColorSpace(.sRGB) else { return 0 }
        func linear(_ value: CGFloat) -> CGFloat {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.redComponent)
            + 0.7152 * linear(rgb.greenComponent)
            + 0.0722 * linear(rgb.blueComponent)
    }
}


struct PlannerView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannerTask.day) private var allTasks: [PlannerTask]
    @Query(sort: \PlannerTag.name) private var tags: [PlannerTag]
    @Query(sort: \ClassMeeting.startsAt) private var classes: [ClassMeeting]
    @Query(sort: \PlannerPerson.position) private var people: [PlannerPerson]
    @Query private var settings: [PlannerSetting]
    @Binding var date: Date
    @Binding var weekMode: Bool
    @State private var selectedPersonID: UUID?
    @State private var overlayPersonID: UUID?
    @State private var selectedTagID: UUID?
    @State private var quickText = ""
    @State private var composerTitle = ""
    @State private var composerDetails = ""
    @State private var composerIcon = PlannerIcon.taskDefault
    @State private var composerHasTime = true
    @State private var composerStart = Date.now
    @State private var composerEnd = Date.now.addingTimeInterval(3600)
    @State private var composerTagIDs: Set<UUID> = []
    @State private var editingTask: PlannerTask?
    @State private var editingLesson: ClassMeeting?
    @State private var showingTagEditor = false
    @AppStorage("planner.density") private var density = "comfortable"
    @AppStorage("planner.lessonColor") private var lessonColor = "#7444c4"
    @AppStorage("planner.dayStart") private var dayStart = 7
    @AppStorage("planner.dayEnd") private var dayEnd = 23
    @State private var toast: String?
    @State private var undoSnapshot: TaskSnapshot?
    @FocusState private var isComposerTitleFocused: Bool

    private var visibleTasks: [PlannerTask] { allTasks.filter { $0.deletedAt == nil && $0.personID == selectedPersonID && (selectedTagID == nil || $0.tagIDs.contains(selectedTagID!)) } }
    private var overlayTasks: [PlannerTask] { guard let overlayPersonID else { return [] }; return allTasks.filter { $0.deletedAt == nil && $0.personID == overlayPersonID && (selectedTagID == nil || $0.tagIDs.contains(selectedTagID!)) } }
    private var selectedPersonName: String { selectedPersonID.flatMap { id in people.first { $0.id == id }?.name } ?? "Я" }
    private var overlayPerson: PlannerPerson? { people.first { $0.id == overlayPersonID } }
    @Environment(\.rhythmPalette) private var palette
    private var hasInvalidComposerTime: Bool { composerHasTime && clockText(composerEnd) <= clockText(composerStart) }

    var body: some View {
        VStack(spacing: 0) {
            header
            if weekMode { weekGrid } else { dayContent }
        }
        .sheet(item: $editingTask) { task in TaskEditor(task: task, date: task.day, personID: task.personID, tags: tags) }
        .sheet(isPresented: $showingTagEditor) { TagManagerView() }
        .sheet(item: $editingLesson) { lesson in
            ClassEditor(lesson: lesson, people: people, personID: lesson.personID)
        }
        .overlay(alignment: .bottom) {
            if let toast {
                HStack(spacing: 12) {
                    Text(toast)
                    Button("Вернуть", action: undoDelete)
                        .buttonStyle(.bordered)
                }
                .rhythmCard(padding: 10)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                .padding(.bottom, 16)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                Text(weekMode ? "Неделя" : (date == .now.plannerDay ? "Сегодня" : date.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.wide)).capitalized))
                    .font(.system(size: 40, weight: .bold))
                Rectangle().fill(palette.line).frame(width: 1, height: 30)
                Text(weekMode ? weekTitle : date.russianDay)
                    .font(.title3).foregroundStyle(palette.muted)
                Spacer()
                let displayedDays = weekMode ? monday...monday.addingDays(6) : date.plannerDay...date.plannerDay
                let current = visibleTasks.filter { displayedDays.contains($0.day) }
                Text("\(current.filter(\.isDone).count) из \(current.count) выполнено")
                    .font(.subheadline).foregroundStyle(palette.muted)
            }
            HStack(spacing: 12) {
                Menu {
                    Button("Я") { selectedPersonID = nil; overlayPersonID = nil }
                    ForEach(people) { person in
                        Button(person.name) { selectedPersonID = person.id; overlayPersonID = nil }
                    }
                } label: {
                    Label(selectedPersonName, systemImage: "person.crop.circle").font(.subheadline).lineLimit(1)
                }
                if !people.isEmpty {
                    Menu {
                        Button("Без наложения") { overlayPersonID = nil }
                        ForEach(people.filter { $0.id != selectedPersonID }) { person in
                            Button(person.name) { overlayPersonID = person.id }
                        }
                    } label: {
                        Label(overlayPerson.map { "Вместе с \($0.name)" } ?? "Сравнить графики", systemImage: "square.3.layers.3d")
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button { date = date.addingDays(-7) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Предыдущая неделя")
                Button("Сегодня") { date = .now.plannerDay; weekMode = false }
                Button { date = date.addingDays(7) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Следующая неделя")
                Button(action: exportSchedule) {
                    Label("Экспорт", systemImage: "square.and.arrow.up")
                }
                .help("Сохранить план в HTML или SVG")
            }
            if !weekMode { weekStrip }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 30)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }

    private var weekStrip: some View {
        HStack(spacing: 8) {
            ForEach(0..<7, id: \.self) { offset in
                let day = monday.addingDays(offset)
                Button { date = day; weekMode = false } label: {
                    VStack(spacing: 5) {
                        Text(day.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.abbreviated))).font(.caption)
                        Text(day.formatted(.dateTime.day())).font(.title2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .foregroundStyle(day == date.plannerDay ? palette.onAccent : palette.muted)
                    .background(day == date.plannerDay ? palette.accent : palette.card, in: RoundedRectangle(cornerRadius: palette.controlRadius))
                    .contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .accessibilityAddTraits(day == date.plannerDay ? .isSelected : [])
            }
        }
    }

    private var dayContent: some View {
        let dayTasks = visibleTasks.filter { $0.day == date.plannerDay }
        let dayOverlayTasks = overlayTasks.filter { $0.day == date.plannerDay }
        let dayClasses = lessons(on: date)
        let entries = dayClasses.map { PlannerCalendarEntry(lesson: $0, isOverlay: $0.personID != selectedPersonID) } + (dayTasks + dayOverlayTasks).compactMap { task in task.startsAt.map { _ in PlannerCalendarEntry(task: task, isOverlay: task.personID != selectedPersonID) } }
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    taskComposer
                    HStack {
                        Text(date == .now.plannerDay ? "Задачи на сегодня" : "Задачи на день").font(.title2.bold())
                        Spacer()
                        Menu {
                            Button("Все") { selectedTagID = nil }
                            ForEach(tags) { tag in Button(tag.name) { selectedTagID = tag.id } }
                            Divider()
                            Button("Управлять тегами") { showingTagEditor = true }
                        } label: { Text(selectedTagID.flatMap { id in tags.first { $0.id == id }?.name } ?? "Все").font(.subheadline) }
                    }
                    if dayTasks.isEmpty && dayOverlayTasks.isEmpty {
                        Text("Задач пока нет. Добавьте первую выше.").foregroundStyle(palette.muted)
                    }
                    ForEach((dayTasks + dayOverlayTasks).sorted { ($0.isDone ? 1 : 0, $0.startsAt ?? "99:99") < ($1.isDone ? 1 : 0, $1.startsAt ?? "99:99") }) { task in
                        taskRow(task, isOverlay: task.personID != selectedPersonID)
                        Rectangle().fill(palette.line).frame(height: 1)
                    }
                }
                .padding(.horizontal, 30).padding(.bottom, 30)
            }
            .frame(minWidth: 430, maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(palette.line).frame(width: 1)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Ритм дня").font(.title2.bold())
                    Spacer()
                }
                Text(date.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.wide)).capitalized).foregroundStyle(palette.muted)
                if overlayPersonID != nil {
                    Text("Свободно вместе: \(commonFreeSlots(on: date).joined(separator: " · "))").font(.caption).foregroundStyle(palette.muted)
                }
                timeline(entries: entries).padding(.top, 20)
            }
            .padding(.horizontal, 28).padding(.top, 26)
            .frame(minWidth: 340, maxWidth: 440, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func timeline(entries: [PlannerCalendarEntry]) -> some View {
        let start = min(max(dayStart, 0), 23)
        let end = min(max(dayEnd, start), 23)
        let firstHour = max(0, min(start, entries.map { clockMinutes($0.time) / 60 }.min() ?? start))
        let lastHour = min(23, max(end, entries.map { clockMinutes($0.time) / 60 }.max() ?? end))
        return ScrollView {
            VStack(spacing: 0) {
                ForEach(firstHour...lastHour, id: \.self) { hour in
                    HStack(alignment: .top, spacing: 18) {
                        Text(String(format: "%02d:00", hour))
                            .font(.subheadline).foregroundStyle(palette.muted)
                            .frame(width: 54, alignment: .trailing)
                        Rectangle().fill(palette.line).frame(width: 1)
                        VStack(spacing: 6) {
                            ForEach(entries.filter { clockMinutes($0.time) / 60 == hour }) { entry in
                                if let task = entry.task, !entry.isOverlay {
                                    Button { editingTask = task } label: { timelineEvent(entry).contentShape(Rectangle()) }
                                        .buttonStyle(RhythmPressStyle())
                                        .help("Изменить задачу")
                                } else if let lesson = entry.lesson, !entry.isOverlay {
                                    Button { editingLesson = lesson } label: { timelineEvent(entry).contentShape(Rectangle()) }
                                        .buttonStyle(RhythmPressStyle())
                                        .help("Изменить пару")
                                } else {
                                    timelineEvent(entry)
                                }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }.frame(minHeight: 76, alignment: .top)
                }
            }
        }
    }

    private func timelineEvent(_ entry: PlannerCalendarEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.lesson == nil ? (entry.task?.icon ?? PlannerIcon.taskDefault) : PlannerIcon.lesson)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.task?.title ?? entry.lesson?.subject ?? "").font(.subheadline.weight(.medium)).lineLimit(2)
                Text(entry.time + ((entry.task?.endsAt ?? entry.lesson?.endsAt).map { "–\($0)" } ?? ""))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(palette.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .rhythmCard(padding: 0)
    }

    private var taskComposer: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Новая задача").font(.headline)
            TextField("Что нужно сделать?", text: $composerTitle)
                .font(.title3).textFieldStyle(.plain).focused($isComposerTitleFocused)
                .rhythmCard(padding: 12, compact: true)
                .overlay {
                    RoundedRectangle(cornerRadius: palette.controlRadius)
                        .strokeBorder(palette.accent.opacity(isComposerTitleFocused ? 1 : 0.25))
                        .allowsHitTesting(false)
                }
                .onSubmit(addComposedTask)
            HStack(spacing: 10) {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(tags.prefix(4)) { tag in
                            let selected = composerTagIDs.contains(tag.id)
                            Button {
                                if !composerTagIDs.insert(tag.id).inserted { composerTagIDs.remove(tag.id) }
                            } label: {
                                Label(tag.name, systemImage: selected ? "checkmark" : (tag.icon ?? PlannerIcon.tagDefault))
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selected ? palette.selected : palette.background, in: RoundedRectangle(cornerRadius: palette.controlRadius))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(RhythmPressStyle())
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
                Menu {
                    ForEach(tags) { tag in
                        Toggle(tag.name, isOn: Binding(
                            get: { composerTagIDs.contains(tag.id) },
                            set: { selected in
                                if selected { composerTagIDs.insert(tag.id) }
                                else { composerTagIDs.remove(tag.id) }
                            }
                        ))
                    }
                    if !tags.isEmpty { Divider() }
                    Button("Управлять тегами") { showingTagEditor = true }
                } label: {
                    Label("Теги", systemImage: "tag").font(.subheadline)
                }
                .fixedSize()
            }
            Rectangle().fill(palette.line).frame(height: 1)
            HStack {
                Toggle("По времени", isOn: $composerHasTime).toggleStyle(.checkbox)
                if composerHasTime {
                    DatePicker("С", selection: $composerStart, displayedComponents: .hourAndMinute).labelsHidden()
                    DatePicker("До", selection: $composerEnd, displayedComponents: .hourAndMinute).labelsHidden()
                } else { Text("Без времени").foregroundStyle(palette.muted) }
                Spacer()
                Button("Добавить ↵", action: addComposedTask)
                    .buttonStyle(.borderedProminent).tint(palette.accent).foregroundStyle(palette.onAccent)
                    .disabled(composerTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasInvalidComposerTime)
            }
            if hasInvalidComposerTime { Text("Конец должен быть позже начала").font(.caption).foregroundStyle(.red) }
            DisclosureGroup("Дополнительно") {
                VStack(alignment: .leading, spacing: 8) {
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                    PlannerIconPicker(selection: $composerIcon, title: "Значок задачи")
                    TextField("Заметка", text: $composerDetails).textFieldStyle(.roundedBorder)
                    HStack {
                        TextField("Быстрый ввод", text: $quickText).onSubmit(addQuickTask)
                        Button("Добавить", action: addQuickTask)
                            .disabled(quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.padding(.top, 8)
            }.font(.caption).foregroundStyle(palette.muted)
        }
        .rhythmCard(padding: 20)
        .onAppear(perform: setCurrentComposerTime)
    }

    private var monday: Date {
        Calendar(identifier: .iso8601).dateInterval(of: .weekOfYear, for: date)?.start.plannerDay ?? date
    }

    private var weekGrid: some View {
        GeometryReader { geometry in
            let width = (geometry.size.width - 80) / 7
            ScrollView {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        weekColumn(for: monday.addingDays(offset), width: width)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .frame(minHeight: geometry.size.height, alignment: .top)
            }
        }
    }

    private func weekColumn(for day: Date, width: CGFloat) -> some View {
        let tasks = (visibleTasks + overlayTasks).filter { $0.day == day }
        let entries = tasks.map { PlannerCalendarEntry(task: $0, isOverlay: $0.personID != selectedPersonID) }
            + lessons(on: day).map { PlannerCalendarEntry(lesson: $0, isOverlay: $0.personID != selectedPersonID) }
        return VStack(alignment: .leading, spacing: 8) {
            Button {
                date = day
                weekMode = false
            } label: {
                Text(day.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(RhythmPressStyle())
            if overlayPersonID != nil {
                Text("Свободно вместе: \(commonFreeSlots(on: day).joined(separator: " · "))")
                    .font(.caption2).foregroundStyle(palette.muted)
            }
            ForEach(entries.sorted { $0.time < $1.time }) { entry in
                if let lesson = entry.lesson {
                    if entry.isOverlay {
                        compactLesson(lesson)
                    } else {
                        Button { editingLesson = lesson } label: { compactLesson(lesson).contentShape(Rectangle()) }
                            .buttonStyle(RhythmPressStyle())
                            .help("Изменить пару")
                    }
                } else if let task = entry.task {
                    taskRow(task, isOverlay: entry.isOverlay, compact: true)
                }
            }
            if entries.isEmpty {
                Text("Нет событий").font(.caption).foregroundStyle(palette.muted)
            }
        }
        .frame(width: width - 16, alignment: .leading)
        .rhythmCard(padding: 8)
        .dropDestination(for: String.self) { ids, _ in move(ids, to: day, hour: nil) }
    }

    private var weekTitle: String {
        let format = Date.FormatStyle().day().month(.abbreviated).locale(Locale(identifier: "ru_RU"))
        return "\(monday.formatted(format)) – \(monday.addingDays(6).formatted(format))"
    }

    private func taskRow(_ task: PlannerTask, isOverlay: Bool = false, compact: Bool = false) -> some View {
        HStack(alignment: compact ? .top : .center, spacing: compact ? 4 : 10) {
            Button { task.isDone.toggle(); save() } label: { Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(compact ? .subheadline : .title2)
                    .foregroundStyle(task.isDone ? palette.accent : palette.foreground)
                    .frame(width: compact ? 20 : 32, height: compact ? 24 : 32)
                    .contentShape(Rectangle())
            }
                .buttonStyle(RhythmPressStyle())
                .disabled(isOverlay)
                .accessibilityLabel(task.isDone ? "Отметить невыполненной: \(task.title)" : "Отметить выполненной: \(task.title)")
            Button { editingTask = task } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(compact ? .caption.weight(.medium) : .body).strikethrough(task.isDone).foregroundStyle(task.isDone ? palette.muted : palette.foreground).lineLimit(2)
                    HStack(spacing: 5) {
                        if let time = task.startsAt {
                            Text(time + (task.endsAt.map { "–\($0)" } ?? "") + (compact ? "" : " · " + duration(task)))
                                .monospacedDigit()
                        }
                        if isConflicting(task) { Label("Конфликт", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                        if isOverlay { Text(overlayPerson?.name ?? "Другой график") }
                        ForEach(compact ? [] : task.tagIDs, id: \.self) { tagID in
                            if let tag = tags.first(where: { $0.id == tagID }) {
                                Label(tag.name, systemImage: tag.icon ?? PlannerIcon.tagDefault)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(PlannerPalette.color(tag.color).opacity(0.14), in: Capsule())
                            }
                        }
                    }.font(.caption).foregroundStyle(palette.muted).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(RhythmPressStyle())
            .help(task.title)
            .contextMenu {
                if !isOverlay {
                    Button("Изменить") { editingTask = task }
                    Button("Удалить", role: .destructive) { delete(task) }
                }
            }
            if !isOverlay && !compact {
                Button { delete(task) } label: {
                    Image(systemName: "trash").frame(width: 30, height: 30).contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .accessibilityLabel("Удалить задачу: \(task.title)")
                .help("Удалить задачу")
            }
        }
        .padding(.vertical, compact ? 2 : (density == "compact" ? 6 : (density == "spacious" ? 16 : 11)))
        .modifier(TaskDrag(id: task.id, enabled: !isOverlay))
        .disabled(isOverlay)
    }

    private func compactLesson(_ lesson: ClassMeeting) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(lesson.startsAt)–\(lesson.endsAt)")
                .font(.caption2.monospacedDigit()).foregroundStyle(palette.muted)
            Label(lesson.subject, systemImage: PlannerIcon.lesson)
                .font(.caption.weight(.medium)).lineLimit(3)
            if lesson.personID != selectedPersonID, let person = people.first(where: { $0.id == lesson.personID }) { Text(person.name).font(.caption2).foregroundStyle(.secondary) }
        }
            .padding(7).frame(maxWidth: .infinity, alignment: .leading).background(PlannerPalette.color(lesson.personID.flatMap { id in people.first(where: { $0.id == id })?.color } ?? lessonColor).opacity(0.13), in: RoundedRectangle(cornerRadius: 7))
    }

    private func lessons(on day: Date) -> [ClassMeeting] {
        let semesterStart = settingDate("semester_start"), semesterEnd = settingDate("semester_end")
        guard (semesterStart == nil || day >= semesterStart!) && (semesterEnd == nil || day <= semesterEnd!) else { return [] }
        let isoCalendar = Calendar(identifier: .iso8601)
        let start = semesterStart.map { isoCalendar.dateInterval(of: .weekOfYear, for: $0)!.start } ?? isoCalendar.dateInterval(of: .weekOfYear, for: day)!.start
        let currentMonday = isoCalendar.dateInterval(of: .weekOfYear, for: day)!.start
        let week = semesterStart.map { _ in max(1, (isoCalendar.dateComponents([.day], from: start, to: currentMonday).day ?? 0) / 7 + 1) } ?? isoCalendar.component(.weekOfYear, from: day)
        let isOdd = week % 2 != 0
        return classes.filter { $0.weekday == day.plannerWeekday && ($0.personID == selectedPersonID || (overlayPersonID != nil && $0.personID == overlayPersonID)) && ($0.weekParity == "all" || ($0.weekParity == "odd") == isOdd) }.sorted { $0.startsAt < $1.startsAt }
    }
    private func settingDate(_ key: String) -> Date? { settings.first(where: { $0.key == key }).flatMap { parsePlannerDate($0.value) } }
    private func addComposedTask() {
        let title = composerTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !hasInvalidComposerTime else { return }
        let start = composerHasTime ? clockText(composerStart) : nil
        let end = composerHasTime ? clockText(composerEnd) : nil
        let task = PlannerTask(title: title, details: composerDetails.trimmingCharacters(in: .whitespacesAndNewlines), day: date, startsAt: start, endsAt: end, personID: selectedPersonID, tagIDs: Array(composerTagIDs), icon: composerIcon)
        context.insert(task); save()
        composerTitle = ""; composerDetails = ""; composerTagIDs = []; composerIcon = PlannerIcon.taskDefault
        setCurrentComposerTime()
    }
    private func setCurrentComposerTime() {
        let now = Date.now
        composerStart = now
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: now) ?? now
        composerEnd = min(now.addingTimeInterval(3600), endOfDay)
    }
    private func clockText(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    private func addQuickTask() {
        guard !quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let parsed = QuickTaskParser.parse(quickText, reference: date, tags: tags)
        let task = PlannerTask(title: parsed.title, day: parsed.day, startsAt: parsed.time, endsAt: parsed.end, personID: selectedPersonID, tagIDs: parsed.tagIDs)
        context.insert(task); save(); quickText = ""
    }
    private func move(_ ids: [String], to target: Date, hour: Int?) -> Bool {
        guard let value = ids.first, let id = UUID(uuidString: value),
              let task = allTasks.first(where: { $0.id == id && $0.deletedAt == nil && $0.personID == selectedPersonID })
        else { return false }
        task.day = target.plannerDay
        if let hour { task.startsAt = String(format: "%02d:00", hour); if task.endsAt == nil { task.endsAt = hour == 23 ? "23:59" : String(format: "%02d:00", hour + 1) } }
        save(); return true
    }
    private func delete(_ task: PlannerTask) { undoSnapshot = TaskSnapshot(task); task.deletedAt = .now; save(); toast = "Задача удалена"; DispatchQueue.main.asyncAfter(deadline: .now() + 5) { if undoSnapshot?.id == task.id { toast = nil; undoSnapshot = nil } } }
    private func undoDelete() { guard let snapshot = undoSnapshot, let task = allTasks.first(where: { $0.id == snapshot.id }) else { return }; task.deletedAt = nil; save(); undoSnapshot = nil; toast = nil }
    private func commonFreeSlots(on day: Date) -> [String] {
        guard let overlayPersonID else { return [] }
        let owners: [UUID?] = [selectedPersonID, overlayPersonID]
        var busy: [(Int, Int)] = []
        for owner in owners {
            for task in allTasks where task.personID == owner && task.deletedAt == nil && task.day == day.plannerDay {
                guard let start = task.startsAt else { continue }; let from = clockMinutes(start); let to = task.endsAt.map(clockMinutes) ?? from + 60; busy.append((from, min(to, 23 * 60)))
            }
            for lesson in classes where lesson.personID == owner && lesson.weekday == day.plannerWeekday && lessons(on: day).contains(where: { $0.id == lesson.id }) { busy.append((clockMinutes(lesson.startsAt), clockMinutes(lesson.endsAt))) }
        }
        var cursor = 8 * 60; let closing = 22 * 60; var gaps: [String] = []
        for interval in busy.sorted(by: { $0.0 < $1.0 }) { if interval.0 - cursor >= 30 { gaps.append("\(clockText(cursor))–\(clockText(min(interval.0, closing)))") }; cursor = max(cursor, interval.1); if cursor >= closing { break } }
        if closing - cursor >= 30 { gaps.append("\(clockText(cursor))–22:00") }
        return gaps.filter { $0.contains("–") && clockMinutes(String($0.split(separator: "–").last ?? "00:00")) > clockMinutes(String($0.split(separator: "–").first ?? "00:00")) }
    }
    private func clockText(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    private func save() { try? context.save() }
    private func duration(_ task: PlannerTask) -> String {
        guard let start = task.startsAt, let end = task.endsAt else { return "1 ч" }
        let minutes = max(0, clockMinutes(end) - clockMinutes(start)); return minutes >= 60 ? "\(minutes / 60) ч\(minutes % 60 == 0 ? "" : " \(minutes % 60) мин")" : "\(minutes) мин"
    }
    private func isConflicting(_ task: PlannerTask) -> Bool {
        guard let start = task.startsAt else { return false }
        let startMinute = clockMinutes(start)
        let endMinute = task.endsAt.map(clockMinutes) ?? min(startMinute + 60, 24 * 60)
        return lessons(on: task.day).contains { lesson in
            lesson.personID == task.personID && clockMinutes(lesson.startsAt) < endMinute && clockMinutes(lesson.endsAt) > startMinute
        }
    }
    private func exportSchedule() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "План-\(date.formatted(.iso8601.year().month().day())).html"; panel.allowedContentTypes = [.html, .svg]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let days = weekMode ? (0..<7).map { monday.addingDays($0) } : [date]
        let htmlDays = days.map { day in
            let tasks = (visibleTasks + overlayTasks).filter { $0.day == day }.sorted { ($0.startsAt ?? "99:99") < ($1.startsAt ?? "99:99") }
            let taskRows = tasks.map { task in "<li><time>\(escape(task.startsAt ?? ""))\(task.endsAt.map { "–\(escape($0))" } ?? "")</time> <b>\(escape(task.title))</b> \(task.isDone ? "✓" : "")</li>" }.joined()
            let lessonRows = lessons(on: day).map { lesson in "<li class='class'><time>\(escape(lesson.startsAt))–\(escape(lesson.endsAt))</time> <b>\(escape(lesson.subject))</b> <small>\(escape([lesson.room, lesson.groupName].filter { !$0.isEmpty }.joined(separator: " · ")))</small></li>" }.joined()
            return "<section><h2>\(escape(day.russianDay.capitalized))</h2><ul>\(lessonRows)\(taskRows)</ul></section>"
        }.joined()
        let pageTitle = weekMode ? weekTitle : date.russianDay
        if url.pathExtension.lowercased() == "svg" {
            let lines = days.enumerated().flatMap { index, day -> [String] in
                let entries = (visibleTasks + overlayTasks).filter { $0.day == day }.map { "\($0.startsAt ?? "") \($0.title)" } + lessons(on: day).map { "\($0.startsAt) \($0.subject)" }
                return ["<text x='30' y='\(44 + index * 250)' class='head'>\(escape(day.formatted(.dateTime.locale(Locale(identifier: "ru_RU")).weekday(.wide).day().month(.wide))))</text>"] + entries.enumerated().map { row, text in "<text x='36' y='\(78 + index * 250 + row * 27)' class='row'>\(escape(text))</text>" }
            }.joined()
            let svg = "<svg xmlns='http://www.w3.org/2000/svg' width='900' height='\(max(260, days.count * 250))' viewBox='0 0 900 \(max(260, days.count * 250))'><style>text{font:16px -apple-system, sans-serif;fill:#252932}.head{font-size:22px;font-weight:700}.row{font-size:15px}</style><rect width='100%' height='100%' rx='24' fill='#faf9f6'/><text x='30' y='30' class='head'>\(escape(pageTitle)) · \(escape(selectedPersonName))</text>\(lines)</svg>"
            try? svg.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let html = "<!doctype html><meta charset='utf-8'><meta name='viewport' content='width=device-width'><title>\(escape(pageTitle))</title><style>body{font:16px system-ui;max-width:800px;margin:36px auto;padding:0 18px;color:#252932;background:#faf9f6}h1{font-size:28px}section{margin:20px 0;padding:16px;background:white;border-radius:16px}li{padding:10px 4px;border-bottom:1px solid #eee;list-style:none}ul{padding:0}time{font-variant-numeric:tabular-nums;color:#777;margin-right:12px}.class{color:#654c91}small{color:#777}</style><h1>\(escape(pageTitle))</h1><p>\(escape(selectedPersonName))\(overlayPerson.map { " · наложено: \(escape($0.name))" } ?? "")</p>\(htmlDays)"
            try? html.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    private func clockMinutes(_ value: String) -> Int { let parts = value.split(separator: ":").compactMap { Int($0) }; return parts.count == 2 ? parts[0] * 60 + parts[1] : 0 }
    private func escape(_ value: String) -> String { value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;") }
}

private struct PlannerCalendarEntry: Identifiable {
    let id: String
    let time: String
    let task: PlannerTask?
    let lesson: ClassMeeting?
    let isOverlay: Bool
    init(task: PlannerTask, isOverlay: Bool) { id = "task-\(task.id)"; time = task.startsAt ?? "99:99"; self.task = task; lesson = nil; self.isOverlay = isOverlay }
    init(lesson: ClassMeeting, isOverlay: Bool) { id = "class-\(lesson.id)"; time = lesson.startsAt; task = nil; self.lesson = lesson; self.isOverlay = isOverlay }
}

private struct TaskSnapshot { let id: UUID; init(_ task: PlannerTask) { id = task.id } }

struct TaskEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: PlannerTask?
    let date: Date
    let personID: UUID?
    let tags: [PlannerTag]
    @State private var title = ""
    @State private var details = ""
    @State private var day = Date.now
    @State private var startsAt = ""
    @State private var endsAt = ""
    @State private var selectedTags: Set<UUID> = []
    @State private var icon = PlannerIcon.taskDefault
    init(task: PlannerTask?, date: Date, personID: UUID?, tags: [PlannerTag]) {
        self.task = task; self.date = date; self.personID = personID; self.tags = tags
        _title = State(initialValue: task?.title ?? ""); _details = State(initialValue: task?.details ?? ""); _day = State(initialValue: task?.day ?? date); _startsAt = State(initialValue: task?.startsAt ?? ""); _endsAt = State(initialValue: task?.endsAt ?? ""); _selectedTags = State(initialValue: Set(task?.tagIDs ?? [])); _icon = State(initialValue: task?.icon ?? PlannerIcon.taskDefault)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(task == nil ? "Новая задача" : "Задача").font(.title2.weight(.semibold))
            TextField("Название", text: $title).textFieldStyle(.roundedBorder)
            PlannerIconPicker(selection: $icon, title: "Значок задачи")
            TextField("Описание", text: $details, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
            DatePicker("Дата", selection: $day, displayedComponents: .date)
            HStack { TextField("Начало", text: $startsAt).textFieldStyle(.roundedBorder); TextField("Конец", text: $endsAt).textFieldStyle(.roundedBorder) }
            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags) { tag in
                        Button {
                            if !selectedTags.insert(tag.id).inserted { selectedTags.remove(tag.id) }
                        } label: {
                            HStack(spacing: 4) {
                                Label(tag.name, systemImage: tag.icon ?? PlannerIcon.tagDefault)
                                if selectedTags.contains(tag.id) { Image(systemName: "checkmark") }
                            }
                            .foregroundStyle(PlannerPalette.color(tag.color))
                        }.buttonStyle(.plain)
                    }
                }
            }
            if let task {
                Divider()
                ScrollView {
                    TaskChecklist(taskID: task.id)
                        .padding(.trailing, 4)
                }
                .frame(maxHeight: 176)
            }
            HStack { Spacer(); Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction); Button("Сохранить") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty) }
        }.rhythmEditor(width: 540)
    }
    private func save() {
        let start = startsAt.trimmingCharacters(in: .whitespaces); let end = endsAt.trimmingCharacters(in: .whitespaces)
        if let task { task.title = title; task.details = details; task.day = day.plannerDay; task.startsAt = start.isEmpty ? nil : start; task.endsAt = end.isEmpty ? nil : end; task.tagIDs = Array(selectedTags); task.icon = icon }
        else { context.insert(PlannerTask(title: title, details: details, day: day, startsAt: start.isEmpty ? nil : start, endsAt: end.isEmpty ? nil : end, personID: personID, tagIDs: Array(selectedTags), icon: icon)) }
        try? context.save(); dismiss()
    }
}

struct PlannerIconPicker: View {
    @Binding var selection: String
    let title: String

    var body: some View {
        Menu {
            ForEach(PlannerIcon.options) { option in
                Button {
                    selection = option.symbol
                } label: {
                    HStack {
                        Label(option.title, systemImage: option.symbol)
                        if selection == option.symbol { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            Label(title, systemImage: selection)
        }
        .accessibilityLabel(title)
    }
}

struct FlowLayout<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .leading)], alignment: .leading, spacing: 8) { content } }
}

struct QuickTaskParser {
    struct Parsed { var title: String; var day: Date; var time: String?; var end: String?; var tagIDs: [UUID] }
    static func parse(_ input: String, reference: Date, tags: [PlannerTag]) -> Parsed {
        var text = input
        var day = reference.plannerDay
        let relativeDays = [("послезавтра", 2), ("завтра", 1), ("сегодня", 0)]
        for (word, offset) in relativeDays where text.localizedCaseInsensitiveContains(word) {
            day = day.addingDays(offset)
            text = text.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
            break
        }
        let weekdays: [(String, Int)] = [("понедельник", 1), ("пн", 1), ("вторник", 2), ("вт", 2), ("среда", 3), ("среду", 3), ("ср", 3), ("четверг", 4), ("чт", 4), ("пятница", 5), ("пятницу", 5), ("пт", 5), ("суббота", 6), ("субботу", 6), ("сб", 6), ("воскресенье", 7), ("вс", 7)]
        if let (word, target) = weekdays.sorted(by: { $0.0.count > $1.0.count }).first(where: { text.localizedCaseInsensitiveContains($0.0) }) {
            day = day.addingDays((target - day.plannerWeekday + 7) % 7)
            text = text.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        if let match = firstMatch(#"(?<![\d.:])(\d{1,2})\.(\d{1,2})(?:\.(\d{2}|\d{4}))?(?![\d.:])"#, in: text) {
            let components = match
            let month = Int(components[2]) ?? 0
            let hasYear = components.count > 3 && !components[3].isEmpty
            let rawYear = hasYear ? (Int(components[3]) ?? Calendar.current.component(.year, from: day)) : Calendar.current.component(.year, from: day)
            let dateYear = hasYear && rawYear < 100 ? 2000 + rawYear : rawYear
            if let date = makeDate(year: dateYear, month: month, day: Int(components[1]) ?? 0) {
                day = hasYear ? date : (date < day.plannerDay ? makeDate(year: dateYear + 1, month: month, day: Int(components[1]) ?? 0) ?? date : date)
                text = text.replacingOccurrences(of: match[0], with: "")
            }
        }
        let rangePattern = #"(?<!\d)(?:с\s*)?(\d{1,2})(?::([0-5]\d))?\s*(?:-|–|—|до\s+)\s*(\d{1,2})(?::([0-5]\d))?(?!\d)"#
        var time: String?, end: String?
        if let match = firstMatch(rangePattern, in: text), match.count >= 5 {
            let startHour = Int(match[1]) ?? 0; let startMinute = match[2].isEmpty ? 0 : Int(match[2]) ?? 0
            let endHour = Int(match[3]) ?? 0; let endMinute = match[4].isEmpty ? 0 : Int(match[4]) ?? 0
            if startHour < 24 && endHour < 24 && endHour * 60 + endMinute > startHour * 60 + startMinute {
                time = String(format: "%02d:%02d", startHour, startMinute); end = String(format: "%02d:%02d", endHour, endMinute)
                text = text.replacingOccurrences(of: match[0], with: "")
            }
        }
        if time == nil, let match = firstMatch(#"(?<!\d)(?:в\s*)?(\d{1,2}):([0-5]\d)(?!\d)"#, in: text) {
            let hour = Int(match[1]) ?? 0
            if hour < 24 { time = String(format: "%02d:%@", hour, match[2]); text = text.replacingOccurrences(of: match[0], with: "") }
        } else if time == nil, let match = firstMatch(#"(?<!\d)в\s+(\d{1,2})(?!\d)"#, in: text) {
            let hour = Int(match[1]) ?? 0
            if hour < 24 { time = String(format: "%02d:00", hour); text = text.replacingOccurrences(of: match[0], with: "") }
        }
        var selected: [UUID] = []
        for tag in tags where text.localizedCaseInsensitiveContains("#" + tag.name) { selected.append(tag.id); text = text.replacingOccurrences(of: "#" + tag.name, with: "", options: .caseInsensitive) }
        return Parsed(title: text.split(whereSeparator: \.isWhitespace).joined(separator: " "), day: day, time: time, end: end, tagIDs: selected)
    }
    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]), let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (0..<match.numberOfRanges).map { index in guard let range = Range(match.range(at: index), in: text) else { return "" }; return String(text[range]) }
    }
    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents(); components.calendar = Calendar.current; components.timeZone = TimeZone(identifier: "Europe/Moscow"); components.year = year; components.month = month; components.day = day
        return Calendar.current.date(from: components)?.plannerDay
    }
}
