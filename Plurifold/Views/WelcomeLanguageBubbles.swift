import SwiftUI

struct WelcomeLanguageBubbles: View {
    let selection: [String]
    let isPaused: Bool
    let onSelect: (NativeWelcomeLanguage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var bodies: [WelcomeBubbleBody] = []
    @State private var dragging: Int?
    @State private var dragOrigin: CGPoint?
    @GestureState private var gestureActive = false

    private var staticPresentation: Bool { voiceOver || typeSize.isAccessibilitySize }
    private var motionEnabled: Bool { !reduceMotion && !isPaused && scenePhase == .active }

    var body: some View {
        if staticPresentation {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 12)], spacing: 12) {
                ForEach(NativeWelcomeLanguages.offered) { language in
                    Button { onSelect(language) } label: {
                        bubbleLabel(language, size: nil)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(language.name), \(language.nativeName)")
                    .accessibilityValue(selection.contains(language.code) ? "Selected" : "Not selected")
                    .accessibilityHint("Double tap to change selection")
                }
            }
            .padding(.vertical, 8)
        } else {
            GeometryReader { proxy in
                let tileSize = min(92.0, max(68.0, (proxy.size.width - 42) / (proxy.size.width >= 400 ? 4 : 3)))
                ZStack {
                    ForEach(Array(NativeWelcomeLanguages.offered.enumerated()), id: \.element.id) { index, language in
                        if bodies.indices.contains(index) {
                            Button { onSelect(language) } label: {
                                bubbleLabel(language, size: tileSize)
                            }
                            .buttonStyle(.plain)
                            .rotationEffect(.degrees(reduceMotion ? 0 : bodies[index].angle))
                            .scaleEffect(dragging == index && !reduceMotion ? 1.055 : 1)
                            .position(x: bodies[index].x, y: bodies[index].y)
                            .zIndex(dragging == index ? 1 : 0)
                            .highPriorityGesture(dragGesture(index: index, size: proxy.size))
                            .accessibilityLabel("\(language.name), \(language.nativeName)")
                            .accessibilityValue(selection.contains(language.code) ? "Selected" : "Not selected")
                            .accessibilityHint("Activate to change selection, or drag to move")
                        }
                    }
                }
                .coordinateSpace(name: "welcome-language-field")
                .onAppear { reset(size: proxy.size, tileSize: tileSize) }
                .onChange(of: proxy.size) { _, size in reset(size: size, tileSize: tileSize) }
                .task(id: "\(motionEnabled)-\(proxy.size.width)-\(proxy.size.height)") {
                    guard motionEnabled else { return }
                    var previous = Date()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .milliseconds(16)) }
                        catch { return }
                        let now = Date()
                        WelcomeBubblePhysics.step(&bodies, width: proxy.size.width, height: proxy.size.height,
                                                  elapsed: now.timeIntervalSince(previous),
                                                  time: now.timeIntervalSinceReferenceDate, heldIndex: dragging)
                        previous = now
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { cancelDrag() }
                }
                .onChange(of: gestureActive) { _, active in
                    if !active { cancelDrag() }
                }
                .onChange(of: motionEnabled) { _, enabled in
                    if !enabled {
                        for index in bodies.indices { bodies[index].vx = 0; bodies[index].vy = 0 }
                    }
                }
                .onDisappear { cancelDrag() }
            }
            .frame(height: 326)
        }
    }

    private func bubbleLabel(_ language: NativeWelcomeLanguage, size: Double?) -> some View {
        let selected = selection.contains(language.code)
        let dimension: CGFloat? = size.map { CGFloat($0) }
        let labelFont: Font = size == nil ? StudyTypography.font(.subheadline, weight: .medium) : Font.system(size: 13, weight: .medium)
        return VStack(spacing: 7) {
            Text(LanguageFlag.symbol(for: language.code))
                .font(.system(size: 31))
                .accessibilityHidden(true)
            Text(language.nativeName)
                .font(labelFont)
                .foregroundStyle(Palette.ink)
                .lineLimit(size == nil ? nil : 1)
                .minimumScaleFactor(0.85)
        }
        .padding(size == nil ? 14 : 8)
        .frame(width: dimension, height: dimension)
        .frame(maxWidth: size == nil ? .infinity : nil)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(Palette.surface.opacity(reduceTransparency ? 1 : selected ? 0.94 : 0.5))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .strokeBorder(selected ? Palette.accent : Palette.surface.opacity(0.9), lineWidth: selected ? 2 : 1)
                }
                .shadow(color: Palette.accent.opacity(0.11), radius: 14, x: 0, y: 9)
        }
        .overlay(alignment: .topTrailing) {
            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Palette.accentInk, Palette.accent)
                    .offset(x: 3, y: -3)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
    }

    private func dragGesture(index: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("welcome-language-field"))
            .updating($gestureActive) { _, active, _ in active = true }
            .onChanged { value in
                guard bodies.indices.contains(index) else { return }
                if dragging != index {
                    dragging = index
                    dragOrigin = CGPoint(x: bodies[index].x, y: bodies[index].y)
                }
                guard let origin = dragOrigin else { return }
                bodies[index].x = origin.x + value.translation.width
                bodies[index].y = origin.y + value.translation.height
                bodies[index].vx = 0
                bodies[index].vy = 0
                WelcomeBubblePhysics.step(&bodies, width: size.width, height: size.height,
                                          elapsed: 1.0 / 60, time: Date().timeIntervalSinceReferenceDate,
                                          heldIndex: index, ambientMotion: motionEnabled)
            }
            .onEnded { value in
                guard bodies.indices.contains(index) else { cancelDrag(); return }
                if motionEnabled {
                    bodies[index].vx = WelcomeBubblePhysics.releaseVelocity(
                        predictedTranslation: value.predictedEndTranslation.width, translation: value.translation.width)
                    bodies[index].vy = WelcomeBubblePhysics.releaseVelocity(
                        predictedTranslation: value.predictedEndTranslation.height, translation: value.translation.height)
                }
                dragging = nil
                dragOrigin = nil
            }
    }

    private func reset(size: CGSize, tileSize: Double) {
        cancelDrag()
        bodies = WelcomeBubblePhysics.makeBodies(count: NativeWelcomeLanguages.offered.count,
                                                  width: size.width, height: size.height, tileSize: tileSize)
    }

    private func cancelDrag() {
        if let dragging, bodies.indices.contains(dragging) {
            bodies[dragging].vx = 0
            bodies[dragging].vy = 0
        }
        dragging = nil
        dragOrigin = nil
    }
}
