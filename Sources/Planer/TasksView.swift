import SwiftData
import SwiftUI

struct TasksView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.rhythmPalette) private var palette
    @Query(sort: \PlannerTask.createdAt, order: .reverse) private var tasks: [PlannerTask]
    @Query(sort: \PlannerPerson.position) private var people: [PlannerPerson]
    @Query private var allItems: [ChecklistItem]
    @Query private var settings: [PlannerSetting]
    @State private var owner: UUID?
    @State private var expandedTasks: Set<UUID> = []
    @State private var showsCompleted = true
    @State private var composerPosition: ComposerPosition?
    @State private var deletedTasks: [PlannerTask] = []
    @State private var newTitle = ""
    @State private var renamingTask: PlannerTask?
    @State private var renameTitle = ""
    @State private var subtaskFocus: (taskID: UUID, request: UUID)?
    @FocusState private var focusedField: Field?
    @State private var dropTarget: UUID?
    @State private var saveError = false

    private enum ComposerPosition {
        case top, bottom
    }

    private enum Field: Hashable {
        case newTask
        case title(UUID)
    }

    private var orderKey: String { "tasks.order." + (owner?.uuidString ?? "me") }
    private var orderSetting: PlannerSetting? { settings.first { $0.key == orderKey } }
    private static let dragPrefix = "ritm-dnya-task-order:"

    var body: some View {
        let ordered = orderedTasks
        let active = ordered.filter { !$0.isDone }
        let completed = ordered.filter(\.isDone)
        let itemsByTask = Dictionary(grouping: allItems, by: \.taskID)

        VStack(alignment: .leading, spacing: 18) {
            header
            if composerPosition == .top { composer }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    Text("Активные · \(active.count)")
                        .font(.headline).accessibilityAddTraits(.isHeader)
                    if active.isEmpty {
                        Text("Активных задач нет").foregroundStyle(palette.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .rhythmCard()
                    }
                    ForEach(Array(active.enumerated()), id: \.element.id) { index, task in
                        taskCard(task, items: itemsByTask[task.id, default: []], active: active, index: index, completed: false)
                            .dropDestination(for: String.self) { values, _ in
                                guard let value = values.first, value.hasPrefix(Self.dragPrefix),
                                      let id = UUID(uuidString: String(value.dropFirst(Self.dragPrefix.count)))
                                else { return false }
                                return move(id, onto: task.id)
                            } isTargeted: { targeted in
                                if targeted { dropTarget = task.id }
                                else if dropTarget == task.id { dropTarget = nil }
                            }
                            .id("active-\(task.id)")
                    }

                    Button {
                        showsCompleted.toggle()
                    } label: {
                        Label("Выполнено · \(completed.count)", systemImage: showsCompleted ? "chevron.down" : "chevron.right")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(RhythmPressStyle())
                    .accessibilityValue(showsCompleted ? "Развёрнуто" : "Свёрнуто")
                    .padding(.top, 10)

                    if showsCompleted {
                        if completed.isEmpty {
                            Text("Выполненных задач пока нет").foregroundStyle(palette.muted)
                        }
                        ForEach(completed) { task in
                            taskCard(task, items: itemsByTask[task.id, default: []], active: [], index: nil, completed: true)
                                .id("completed-\(task.id)")
                        }
                    }
                }
                .padding(.bottom, 4)
                .padding(.horizontal, 1)
            }
            .defaultScrollAnchor(.top)
            footer
        }
        .padding([.top, .horizontal], 24)
        .padding(.bottom, 16)
        .frame(maxWidth: 1000)
        .onChange(of: focusedField) { previous, current in
            if let task = renamingTask, previous == .title(task.id), current != previous {
                finishRename()
            }
        }
        .alert("Не удалось сохранить изменения", isPresented: $saveError) {
            Button("Хорошо") {}
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Задачи").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            if !people.isEmpty {
                Picker("График", selection: $owner) {
                    Text("Мои задачи").tag(Optional<UUID>.none)
                    ForEach(people) { person in
                        Text(person.name).tag(Optional(person.id))
                    }
                }
                .frame(width: 196)
            }
            Button("Добавить задачу", systemImage: "plus") { openComposer(at: .top) }
                .buttonStyle(.borderedProminent)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if let task = deletedTasks.last {
                HStack(spacing: 8) {
                    Text("Удалена задача «\(task.title)»")
                        .foregroundStyle(palette.muted)
                        .lineLimit(1)
                    Button("Вернуть", action: restoreDeletedTask)
                }
            }
            if composerPosition == .bottom {
                composer
            } else {
                Button("Добавить задачу", systemImage: "plus") { openComposer(at: .bottom) }
                    .accessibilityLabel("Добавить задачу внизу списка")
                    .buttonStyle(.bordered)
            }
        }
    }

    private func openComposer(at position: ComposerPosition) {
        finishRename()
        composerPosition = position
        focusedField = .newTask
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Новая задача", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .newTask)
                .onSubmit(addTask)
                .onExitCommand(perform: leaveComposer)
            Button("Добавить", action: addTask)
                .buttonStyle(.borderedProminent)
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Закрыть", systemImage: "xmark", action: leaveComposer)
                .labelStyle(.iconOnly)
        }
        .rhythmCard(padding: 12)
    }

    private func addTask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        context.insert(PlannerTask(title: title, personID: owner))
        if save() {
            newTitle = ""
            focusedField = .newTask
        }
    }

    private func leaveComposer() {
        composerPosition = nil
        newTitle = ""
        if focusedField == .newTask { focusedField = nil }
    }

    private func beginRename(_ task: PlannerTask) {
        guard renamingTask?.id != task.id else { return }
        finishRename()
        renameTitle = task.title
        renamingTask = task
        focusedField = .title(task.id)
    }

    private func finishRename() {
        guard let task = renamingTask else { return }
        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelRename()
        if !title.isEmpty && title != task.title {
            task.title = title
            save()
        }
    }

    private func cancelRename() {
        if let task = renamingTask, focusedField == .title(task.id) {
            focusedField = nil
        }
        renamingTask = nil
    }

    private func beginSubtask(_ task: PlannerTask) {
        finishRename()
        expandedTasks.insert(task.id)
        subtaskFocus = (task.id, UUID())
    }

    @ViewBuilder
    private func titleControl(_ task: PlannerTask, completed: Bool) -> some View {
        if renamingTask?.id == task.id {
            TextField("Название задачи", text: $renameTitle)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .title(task.id))
                .onSubmit(finishRename)
                .onExitCommand(perform: cancelRename)
        } else {
            Text(task.title)
                .font(.headline)
                .strikethrough(completed)
                .foregroundStyle(completed ? palette.muted : palette.foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    TapGesture(count: 2)
                        .exclusively(before: TapGesture())
                        .onEnded { gesture in
                            switch gesture {
                            case .first: beginSubtask(task)
                            case .second: beginRename(task)
                            }
                        }
                )
                .help("Один клик — изменить название, двойной — добавить подзадачу")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { beginRename(task) }
                .accessibilityAction(named: Text("Добавить подзадачу")) { beginSubtask(task) }
        }
    }

    private func taskCard(_ task: PlannerTask, items: [ChecklistItem], active: [PlannerTask], index: Int?, completed: Bool) -> some View {
        let expanded = expandedTasks.contains(task.id)
        let checked = items.filter(\.isDone).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if index != nil, active.count > 1 {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(palette.muted)
                        .frame(width: 26, height: 32)
                        .contentShape(Rectangle())
                        .draggable(Self.dragPrefix + task.id.uuidString)
                        .help("Перетащить задачу")
                        .accessibilityHidden(true)
                }

                Button {
                    finishRename()
                    if subtaskFocus?.taskID == task.id { subtaskFocus = nil }
                    task.isDone.toggle()
                    save()
                } label: {
                    Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(completed ? palette.accent : palette.foreground)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .accessibilityLabel(completed ? "Вернуть в активные: \(task.title)" : "Выполнить: \(task.title)")

                titleControl(task, completed: completed)

                Button {
                    if subtaskFocus?.taskID == task.id { subtaskFocus = nil }
                    if expanded { expandedTasks.remove(task.id) }
                    else { expandedTasks.insert(task.id) }
                } label: {
                    HStack(spacing: 6) {
                        if !items.isEmpty {
                            Text("\(checked)/\(items.count)").monospacedDigit()
                        }
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .fontWeight(.semibold)
                    }
                    .font(.caption)
                    .foregroundStyle(palette.muted)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 30, minHeight: 30)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .help(expanded ? "Свернуть подзадачи" : "Показать подзадачи")
                .accessibilityLabel(expanded ? "Свернуть подзадачи" : "Показать подзадачи")
                .accessibilityValue("\(checked) из \(items.count) выполнено")

                Button(role: .destructive) {
                    delete(task)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(palette.muted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RhythmPressStyle())
                .help("Удалить задачу")
                .accessibilityLabel("Удалить задачу: \(task.title)")

                Menu {
                    Button("Изменить название", systemImage: "pencil") { beginRename(task) }
                    Button("Добавить подзадачу", systemImage: "plus") { beginSubtask(task) }
                    if let index, active.count > 1 {
                        Divider()
                        Button("Переместить выше", systemImage: "arrow.up") {
                            if index > 0 { _ = move(task.id, onto: active[index - 1].id) }
                        }.disabled(index == 0)
                        Button("Переместить ниже", systemImage: "arrow.down") {
                            if index + 1 < active.count { _ = move(task.id, onto: active[index + 1].id) }
                        }.disabled(index + 1 == active.count)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.title3)
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Действия: \(task.title)")
            }

            if expanded {
                Divider()
                TaskChecklist(
                    taskID: task.id,
                    focusRequest: subtaskFocus?.taskID == task.id ? subtaskFocus?.request : nil
                )
                .padding(.leading, 4)
            }
        }
        .rhythmCard(padding: 12)
        .overlay {
            if dropTarget == task.id {
                RoundedRectangle(cornerRadius: palette.radius)
                    .strokeBorder(palette.accent, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private func delete(_ task: PlannerTask) {
        if renamingTask?.id == task.id { cancelRename() }
        task.deletedAt = .now
        if save() {
            expandedTasks.remove(task.id)
            if subtaskFocus?.taskID == task.id { subtaskFocus = nil }
            deletedTasks.append(task)
        }
    }

    private func restoreDeletedTask() {
        guard let task = deletedTasks.last else { return }
        task.deletedAt = nil
        if save() { deletedTasks.removeLast() }
    }

    private var orderedTasks: [PlannerTask] {
        let owned = tasks.filter { $0.personID == owner && $0.deletedAt == nil }
        let ids = (orderSetting?.value ?? "").split(separator: ",").compactMap { UUID(uuidString: String($0)) }
        var remaining = Dictionary(uniqueKeysWithValues: owned.map { ($0.id, $0) })
        let manual = ids.compactMap { remaining.removeValue(forKey: $0) }
        return manual + owned.filter { remaining[$0.id] != nil }
    }

    @discardableResult
    private func move(_ source: UUID, onto target: UUID) -> Bool {
        guard source != target else { return false }
        let ordered = orderedTasks
        guard let from = ordered.firstIndex(where: { $0.id == source && !$0.isDone }),
              let to = ordered.firstIndex(where: { $0.id == target && !$0.isDone })
        else { return false }

        var ids = ordered.map(\.id)
        ids.remove(at: from)
        ids.insert(source, at: to)
        let value = ids.map(\.uuidString).joined(separator: ",")
        if let orderSetting {
            orderSetting.value = value
        } else {
            context.insert(PlannerSetting(key: orderKey, value: value))
        }
        return save()
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            saveError = true
            return false
        }
    }
}

struct TaskChecklist: View {
    @Environment(\.modelContext) private var context
    @Environment(\.rhythmPalette) private var palette
    @Query private var items: [ChecklistItem]
    @State private var draft = ""
    @State private var saveError = false
    @FocusState private var draftFocused: Bool
    let taskID: UUID
    let focusRequest: UUID?

    init(taskID: UUID, focusRequest: UUID? = nil) {
        self.taskID = taskID
        self.focusRequest = focusRequest
        _items = Query(filter: #Predicate<ChecklistItem> { $0.taskID == taskID }, sort: \ChecklistItem.position)
    }

    var body: some View {
        let completed = items.filter(\.isDone)
        VStack(alignment: .leading, spacing: 8) {
            Text("Подзадачи").font(.subheadline.weight(.semibold))
            ForEach(items.filter { !$0.isDone }) { item in
                itemRow(item)
            }
            HStack(spacing: 8) {
                TextField("Новая подзадача", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($draftFocused)
                    .onSubmit(add)
                Button("Добавить подзадачу", systemImage: "plus", action: add)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if !completed.isEmpty {
                Text("Выполнено · \(completed.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.muted)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.top, 4)
                ForEach(completed) { item in
                    itemRow(item)
                }
            }
        }
        .onChange(of: focusRequest, initial: true) { _, request in
            if request != nil { draftFocused = true }
        }
        .alert("Не удалось сохранить подзадачу", isPresented: $saveError) {
            Button("Хорошо") {}
        }
    }

    private func itemRow(_ item: ChecklistItem) -> some View {
        Toggle(isOn: Binding(
            get: { item.isDone },
            set: { item.isDone = $0; _ = save() }
        )) {
            Text(item.title)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? palette.muted : palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .toggleStyle(.checkbox)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func add() {
        let title = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let position = (items.last?.position ?? -1) + 1
        context.insert(ChecklistItem(taskID: taskID, title: title, position: position))
        if save() { draft = "" }
    }

    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            saveError = true
            return false
        }
    }
}
