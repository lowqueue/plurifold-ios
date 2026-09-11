import SwiftUI

/// Shared native chrome stays in place while library content scrolls.
struct AppMasthead: View {
    @EnvironmentObject private var session: NativeSession
    @EnvironmentObject private var studyScope: MobileStudyScope
    @State private var showingAccount = false

    var body: some View {
        HStack(spacing: 8) {
            Button { studyScope.isSidebarPresented = true } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Open navigation menu")
            Button { studyScope.showHome() } label: {
                PlurifoldLogo()
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Plurifold Home")
            Spacer(minLength: 8)
            Button { showingAccount = true } label: {
                Text(session.user?.email.first.map { String($0).uppercased() } ?? "?")
                    .font(StudyTypography.font(.body))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, height: 30)
                    .background(Palette.field, in: Circle())
                    .overlay(Circle().stroke(Palette.line, lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Account and appearance")
        }
        .buttonStyle(GardenPressStyle())
        .foregroundStyle(Palette.headerInk)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.header)
        .sheet(isPresented: $showingAccount) { AccountView(isSheet: true) }
    }
}

struct AppLanguageBar: View {
    @EnvironmentObject private var store: LiveLibraryStore
    @EnvironmentObject private var studyScope: MobileStudyScope

    private var languages: [MobileLanguageOption] {
        MobileStudyLanguageList(courses: store.courses, words: store.words, includeOffered: true).languages
    }

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Section("Your languages") {
                    ForEach(languages) { language in
                        Button {
                            studyScope.selectLanguage(language)
                        } label: {
                            let title = "\(language.flag) \(LanguageDisplay.nativeName(for: language.code, fallback: language.name))"
                            if MobileLanguageKey.normalized(language.code) == MobileLanguageKey.normalized(studyScope.language?.code) {
                                Label(title, systemImage: "checkmark")
                            } else { Text(title) }
                        }
                    }
                }
                Button("Choose on Home", systemImage: "globe") { studyScope.showLanguagePicker() }
            } label: {
                HStack(spacing: 10) {
                    if let language = studyScope.language {
                        Text(language.flag).accessibilityHidden(true)
                        Text(LanguageDisplay.nativeName(for: language.code, fallback: language.name))
                    } else { Text("Your languages") }
                    Image(systemName: "chevron.down").font(.caption)
                }
                .font(StudyTypography.font(.subheadline))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Change language")
            .accessibilityValue(studyScope.language?.name ?? "No language selected")
            Spacer(minLength: 4)
            Button { Task { await store.refresh() } } label: {
                Group {
                    if store.isLoading { ProgressView() }
                    else { Image(systemName: store.notice == nil ? "cloud" : "exclamationmark.icloud") }
                }
                .frame(width: 32, height: 32)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Palette.line, lineWidth: 1))
                .frame(width: 44, height: 44)
            }
            .disabled(store.isLoading || store.isSaving)
            .accessibilityLabel(store.isLoading ? "Refreshing library" : "Refresh library and saved words")
        }
        .buttonStyle(GardenPressStyle())
        .foregroundStyle(Palette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .background(Palette.surface)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
    }
}

struct AccountView: View {
    var isSheet = false
    @EnvironmentObject private var session: NativeSession
    @EnvironmentObject private var store: LiveLibraryStore
    @Environment(AppAppearance.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var appearance = appearance
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Your account")
                        Text("Account").font(StudyTypography.font(.largeTitle))
                        if let email = session.user?.email {
                            Text(email).font(StudyTypography.font(.subheadline)).textSelection(.enabled)
                        }
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Layout").font(StudyTypography.font(.headline))
                        Picker("Layout", selection: $appearance.workspaceLayout) {
                            ForEach(AppWorkspaceLayout.allCases) { layout in Text(layout.name).tag(layout) }
                        }
                        .pickerStyle(.segmented)
                        Text(appearance.workspaceLayout.detail).font(.caption).foregroundStyle(Palette.secondary)
                        Text("Colorway").font(StudyTypography.font(.headline))
                        ForEach(AppColorway.allCases) { colorway in
                            Button { appearance.colorway = colorway } label: {
                                HStack(spacing: 14) {
                                    HStack(spacing: 0) {
                                        ForEach(Array(colorway.swatches.enumerated()), id: \.offset) { _, color in
                                            Rectangle().fill(color)
                                        }
                                    }
                                    .frame(width: 66, height: 36)
                                    .overlay(Rectangle().stroke(Palette.line, lineWidth: 1))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(colorway.name).font(StudyTypography.font(.body))
                                        Text(colorway.detail).font(.caption).foregroundStyle(Palette.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: appearance.colorway == colorway ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(Palette.accent)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(appearance.colorway == colorway ? Palette.field : Palette.surface, in: RoundedRectangle(cornerRadius: Palette.controlRadius))
                                .overlay(RoundedRectangle(cornerRadius: Palette.controlRadius)
                                    .stroke(appearance.colorway == colorway ? Palette.accent : Palette.line, lineWidth: 1))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(GardenPressStyle())
                            .accessibilityLabel("\(colorway.name), \(colorway.detail)")
                            .accessibilityAddTraits(appearance.colorway == colorway ? .isSelected : [])
                        }
                        Text("Lighting").font(StudyTypography.font(.headline)).padding(.top, 8)
                        Picker("Lighting", selection: $appearance.lighting) {
                            ForEach(AppLighting.allCases) { lighting in
                                Text(lighting.name).tag(lighting)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Appearance is saved on this device.")
                            .font(.caption).foregroundStyle(Palette.secondary)
                    }
                    .studyCard()
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Library and account").font(StudyTypography.font(.headline))
                        Text("Saved vocabulary and reading places are shared with your Plurifold account.")
                            .font(.subheadline).foregroundStyle(Palette.secondary)
                        Button { Task { await store.refresh() } } label: {
                            Label("Refresh library", systemImage: "arrow.clockwise").frame(minHeight: 44)
                        }
                        .disabled(store.isLoading || store.isSaving)
                        Link(destination: NativeSession.baseURL) {
                            Label("Open Plurifold website", systemImage: "arrow.up.right.square").frame(minHeight: 44)
                        }
                        if let notice = store.notice {
                            Text(notice).font(.subheadline).foregroundStyle(Palette.secondary)
                        }
                        Button("Sign out", role: .destructive) { Task { await session.signOut() } }
                            .frame(minHeight: 44)
                            .disabled(session.isBusy || store.isSaving)
                        if store.isSaving { Text("Finishing your study changes…").font(.caption) }
                    }
                    .studyCard()
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .studyBackground()
            .toolbar(isSheet ? .visible : .hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isSheet {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                }
            }
        }
    }
}
