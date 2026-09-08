import SwiftUI

enum AppSidebarDestination: Hashable {
    case home, library, words, review, account
}

/// The signed-in root owns presentation and navigation. This panel only offers
/// destinations and the appearance preferences already available in Account.
struct AppSidebar: View {
    let onSelect: (AppSidebarDestination) -> Void
    let onClose: () -> Void

    @EnvironmentObject private var session: NativeSession
    @EnvironmentObject private var studyScope: MobileStudyScope
    @Environment(AppAppearance.self) private var appearance
    @AccessibilityFocusState private var closeFocused: Bool

    private var selectedDestination: AppSidebarDestination {
        switch studyScope.tab {
        case .home: studyScope.homePath.isEmpty ? .home : .library
        case .words: .words
        case .review: .review
        case .account: .account
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                PlurifoldLogo()
                    // The decorative wordmark must leave room for Close even
                    // when the rest of the drawer uses accessibility text sizes.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close navigation")
                .accessibilityFocused($closeFocused)
            }
            .foregroundStyle(Palette.headerInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.header)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    languageSummary

                    VStack(spacing: 4) {
                        navigationRow(.home, title: "Home", icon: "house")
                        navigationRow(.library, title: "Library", icon: "books.vertical")
                        navigationRow(.words, title: "Words", icon: "bookmark")
                        navigationRow(.review, title: "Review", icon: "rectangle.on.rectangle")
                        navigationRow(.account, title: "Account", icon: "person.crop.circle")
                    }

                    if let language = studyScope.language {
                        Text("Words and review follow \(language.name).")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }

                    Rectangle().fill(Palette.line).frame(height: 1)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Appearance")
                            .font(.subheadline.monospaced().weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        colorwayMenu
                        lightingMenu
                    }

                    if let email = session.user?.email {
                        Text(email)
                            .font(.caption.monospaced())
                            .foregroundStyle(Palette.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .accessibilityLabel("Signed in as \(email)")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Palette.ink)
        .background(Palette.surface)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Palette.line).frame(width: 1)
        }
        .task {
            await Task.yield()
            closeFocused = true
        }
    }

    private var languageSummary: some View {
        Button { onSelect(.home) } label: {
            HStack(alignment: .center, spacing: 12) {
                if let language = studyScope.language {
                    Text(language.flag).font(.title2).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                            .font(.headline.monospaced())
                        Text("Change language")
                            .font(.caption)
                            .foregroundStyle(Palette.secondary)
                    }
                } else {
                    Image(systemName: "globe").font(.title2).accessibilityHidden(true)
                    Text("Choose a language").font(.headline.monospaced())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(12)
            .background(Palette.field)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .accessibilityLabel(studyScope.language.map { "\($0.name), change language" } ?? "Choose a language")
    }

    private func navigationRow(_ destination: AppSidebarDestination, title: String, icon: String) -> some View {
        let selected = selectedDestination == destination
        return Button { onSelect(destination) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                Text(title).font(.body.monospaced())
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(selected ? Palette.field : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 3)
                .stroke(selected ? Palette.accent : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var colorwayMenu: some View {
        Menu {
            ForEach(AppColorway.allCases) { colorway in
                Button { appearance.colorway = colorway } label: {
                    if appearance.colorway == colorway {
                        Label(colorway.name, systemImage: "checkmark")
                    } else { Text(colorway.name) }
                }
            }
        } label: {
            preferenceLabel(title: "Colorway", value: appearance.colorway.name, icon: "paintpalette")
        }
        .accessibilityLabel("Colorway")
        .accessibilityValue(appearance.colorway.name)
    }

    private var lightingMenu: some View {
        Menu {
            ForEach(AppLighting.allCases) { lighting in
                Button { appearance.lighting = lighting } label: {
                    if appearance.lighting == lighting {
                        Label(lighting.name, systemImage: "checkmark")
                    } else { Text(lighting.name) }
                }
            }
        } label: {
            preferenceLabel(title: "Lighting", value: appearance.lighting.name, icon: "circle.lefthalf.filled")
        }
        .accessibilityLabel("Lighting")
        .accessibilityValue(appearance.lighting.name)
    }

    private func preferenceLabel(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline)
                Text(value).font(.caption.monospaced()).foregroundStyle(Palette.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(10)
        .background(Palette.background)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}
