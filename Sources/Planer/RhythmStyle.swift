import SwiftUI

private struct RhythmPaletteKey: EnvironmentKey {
    static var defaultValue: RhythmPalette { RhythmPalette(theme: "custom", accent: "blue", surface: "paper") }
}

extension EnvironmentValues {
    var rhythmPalette: RhythmPalette {
        get { self[RhythmPaletteKey.self] }
        set { self[RhythmPaletteKey.self] = newValue }
    }
}

struct RhythmPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private struct RhythmCard: ViewModifier {
    @Environment(\.rhythmPalette) private var palette
    let inset: CGFloat
    let compact: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: compact ? palette.controlRadius : palette.radius)
        content.padding(inset)
            .background(palette.card, in: shape)
            .overlay { shape.strokeBorder(palette.line).allowsHitTesting(false) }
    }
}

private struct RhythmEditor: ViewModifier {
    @Environment(\.rhythmPalette) private var palette
    let width: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(24)
            .frame(width: width)
            .background(palette.background)
    }
}

extension View {
    func rhythmCard(padding: CGFloat = 16, compact: Bool = false) -> some View {
        modifier(RhythmCard(inset: padding, compact: compact))
    }

    func rhythmEditor(width: CGFloat) -> some View {
        modifier(RhythmEditor(width: width))
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .rhythmCard()
    }
}

struct TaskDrag: ViewModifier {
    let id: UUID
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.draggable(id.uuidString)
        } else {
            content
        }
    }
}
