import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: NativeSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var mode: Mode = .languages
    @State private var selectedCodes = NativeWelcomeLanguages.selection()
    @State private var search = ""
    @State private var email = ""
    @State private var password = ""
    @State private var motionPaused = false
    @FocusState private var focusedField: Field?

    private enum Field { case search, email, password }
    private enum Mode { case languages, signIn, signUp, recovery }

    private var selectedLanguages: [NativeWelcomeLanguage] {
        selectedCodes.compactMap { code in NativeWelcomeLanguages.offered.first { $0.code == code } }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    if mode == .languages { introduction }
                    else { accountPanel }
                }
                .frame(maxWidth: 580)
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background { welcomeBackground }
            .foregroundStyle(Palette.welcomeInk)
            .tint(Palette.accent)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if session.errorMessage != nil || session.canRestoreSession { mode = .signIn }
            }
            .onDisappear { password = "" }
            .sensoryFeedback(.selection, trigger: selectedCodes)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Wordmark()
            Spacer(minLength: 12)
            Button(mode == .signIn ? "Create account" : "Sign in") {
                changeMode(mode == .signIn ? .signUp : .signIn)
            }
            .font(.subheadline.weight(.medium))
            .padding(.vertical, 12)
            .disabled(session.isBusy)
        }
    }

    private var introduction: some View {
        VStack(spacing: 22) {
            VStack(spacing: 14) {
                Text("A PLACE FOR LANGUAGE")
                    .font(.caption2.monospaced().weight(.medium))
                    .tracking(3)
                    .foregroundStyle(Palette.welcomeMuted)
                VStack(spacing: -4) {
                    Text("Find your").foregroundStyle(Palette.welcomeInk)
                    Text("languages")
                        .foregroundStyle(LinearGradient(colors: [Palette.accent, Palette.welcomeMuted],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .font(typeSize.isAccessibilitySize ? .system(.largeTitle, design: .rounded).weight(.semibold) :
                        .system(size: 54, weight: .semibold, design: .rounded))
                .tracking(-2.4)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                Text("One language, or a few. Your choice.")
                    .font(.body)
                    .foregroundStyle(Palette.welcomeMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 28)

            searchField

            if !selectedLanguages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedLanguages) { language in
                            Button { toggle(language) } label: {
                                HStack(spacing: 6) {
                                    Text(LanguageFlag.symbol(for: language.code)).accessibilityHidden(true)
                                    Text(language.nativeName)
                                    Image(systemName: "xmark").font(.caption2.weight(.bold))
                                }
                                .font(.subheadline)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .background(Palette.surface.opacity(0.75), in: Capsule())
                                .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(language.name)")
                        }
                    }
                }
            }

            if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                WelcomeLanguageBubbles(selection: selectedCodes, isPaused: motionPaused, onSelect: toggle)
                HStack(spacing: 12) {
                    Text(voiceOver || typeSize.isAccessibilitySize ? "Choose the languages you want to study." : "Drag the tiles. Tap to select.")
                        .font(.caption)
                        .foregroundStyle(Palette.welcomeMuted)
                    Spacer(minLength: 0)
                    if !reduceMotion && !voiceOver && !typeSize.isAccessibilitySize {
                        Button { motionPaused.toggle() } label: {
                            Image(systemName: motionPaused ? "play.fill" : "pause.fill")
                                .font(.caption)
                                .frame(width: 44, height: 44)
                                .background(Palette.surface.opacity(0.6), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(motionPaused ? "Resume language tile motion" : "Pause language tile motion")
                    }
                }
            } else { searchResults }

            Button { changeMode(.signUp) } label: {
                HStack(spacing: 14) {
                    Text("Continue")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(WelcomePrimaryButtonStyle())
            .disabled(selectedCodes.isEmpty)
            Text(selectedCodes.isEmpty ? "Choose a language to get started." : "\(selectedCodes.count) \(selectedCodes.count == 1 ? "language" : "languages") selected")
                .font(.caption)
                .foregroundStyle(Palette.welcomeMuted)
        }
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").font(.title3).accessibilityHidden(true)
            TextField("Find your languages", text: $search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .search)
                .submitLabel(.search)
                .accessibilityLabel("Find your languages")
            if !search.isEmpty {
                Button { search = ""; focusedField = nil } label: {
                    Image(systemName: "xmark.circle.fill").frame(width: 34, height: 44)
                }
                .accessibilityLabel("Clear language search")
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 62)
        .background(Palette.surface.opacity(reduceTransparency ? 1 : 0.55), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.surface.opacity(0.9), lineWidth: 1.5))
        .shadow(color: Palette.accent.opacity(0.1), radius: 16, x: 0, y: 10)
    }

    private var searchResults: some View {
        let matches = NativeWelcomeLanguages.offered.filter { $0.matches(search) }
        return VStack(spacing: 6) {
            if matches.isEmpty {
                Text("That language is not offered yet. Choose from the eight languages currently available.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.welcomeMuted)
                    .padding(18)
            } else {
                ForEach(matches) { language in
                    Button { toggle(language) } label: {
                        HStack(spacing: 13) {
                            Text(LanguageFlag.symbol(for: language.code)).font(.title2).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(language.nativeName).font(.body.weight(.medium))
                                Text(language.name).font(.caption).foregroundStyle(Palette.welcomeMuted)
                            }
                            Spacer()
                            Image(systemName: selectedCodes.contains(language.code) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Palette.accent)
                        }
                        .padding(14)
                        .background(Palette.surface.opacity(0.58), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.name)
                    .accessibilityValue(selectedCodes.contains(language.code) ? "Selected" : "Not selected")
                }
            }
        }
    }

    private var accountPanel: some View {
        VStack(alignment: .leading, spacing: 22) {
            Button { changeMode(.languages) } label: {
                Label("Choose languages", systemImage: "arrow.left")
                    .font(.subheadline)
                    .padding(.vertical, 10)
            }
            .disabled(session.isBusy)
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: mode == .recovery ? "key" : "book.closed")
                    .font(.title2)
                    .foregroundStyle(Palette.accent)
                    .frame(width: 54, height: 54)
                    .background(Palette.accentSoft, in: RoundedRectangle(cornerRadius: 17))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 9) {
                    Text(mode == .signUp ? "Create your account" : mode == .recovery ? "Reset your password" : "Sign in")
                        .font(.largeTitle.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(mode == .signUp ? "Save your vocabulary and keep your progress across devices." :
                            mode == .recovery ? "Use Plurifold’s secure website to choose a new password, then return to the app." :
                            "Continue where you left off.")
                        .foregroundStyle(Palette.welcomeMuted)
                        .font(.subheadline)
                }
                if mode == .recovery { recoveryActions }
                else { accountFields }
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Palette.surface.opacity(reduceTransparency ? 1 : 0.88))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.surface.opacity(0.95), lineWidth: 1))
                    .shadow(color: Palette.accent.opacity(0.09), radius: 28, x: 0, y: 16)
            }
            if !selectedLanguages.isEmpty {
                Text(selectedLanguages.map(\.nativeName).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(Palette.welcomeMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("Selected languages: \(selectedLanguages.map(\.name).joined(separator: ", "))")
            }
        }
    }

    private var accountFields: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Email address").font(.subheadline.weight(.medium))
                TextField("you@example.com", text: $email)
                    .textContentType(.username)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .onSubmit { focusedField = .password }
                    .accessibilityLabel("Email address")
                    .welcomeAccountField()
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Password").font(.subheadline.weight(.medium))
                SecureField(mode == .signUp ? "At least 8 characters" : "Password", text: $password)
                    .textContentType(mode == .signUp ? .newPassword : .password)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .onSubmit(submitAccount)
                    .welcomeAccountField()
            }
            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                    .accessibilityLabel("Account message: \(error)")
            }
            if let notice = session.noticeMessage {
                Label(notice, systemImage: "envelope")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
                Button("Continue to sign in") { changeMode(.signIn) }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 8)
            }
            Button(action: submitAccount) {
                HStack(spacing: 10) {
                    if session.isBusy { ProgressView().tint(Palette.accentInk) }
                    Text(session.isBusy ? "Please wait…" : mode == .signUp ? "Create account" : "Sign in")
                    if !session.isBusy { Image(systemName: "arrow.right") }
                }
            }
            .buttonStyle(WelcomePrimaryButtonStyle())
            .disabled(session.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      password.isEmpty || (mode == .signUp && password.count < 8))
            if mode == .signIn {
                Button("Forgot your password?") { changeMode(.recovery) }
                    .font(.subheadline)
                    .padding(.vertical, 10)
                    .disabled(session.isBusy)
                if session.canRestoreSession {
                    Button("Retry saved sign-in") { Task { await session.restore() } }
                        .font(.subheadline)
                        .padding(.vertical, 10)
                        .disabled(session.isBusy)
                }
            }
        }
    }

    private var recoveryActions: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("On the website, choose Sign in, then Forgot password. Follow the email link to set your new password.")
                .font(.subheadline)
                .foregroundStyle(Palette.welcomeMuted)
            Link(destination: NativeSession.baseURL) {
                Label("Reset on the website", systemImage: "arrow.up.right")
            }
            .buttonStyle(WelcomePrimaryButtonStyle())
            Button("Back to sign in") { changeMode(.signIn) }
                .font(.subheadline.weight(.medium))
                .padding(.vertical, 10)
        }
    }

    private var welcomeBackground: some View {
        GeometryReader { proxy in
            ZStack {
                Palette.welcomeBackground
                RadialGradient(colors: [Palette.welcomeGlow.opacity(0.65), .clear],
                               center: .center, startRadius: 30, endRadius: max(proxy.size.width, 450))
                Circle()
                    .fill(Palette.accent.opacity(0.06))
                    .overlay(Circle().stroke(Palette.surface.opacity(0.6), lineWidth: 1.5))
                    .frame(width: 440, height: 440)
                    .offset(x: proxy.size.width * 0.55, y: -proxy.size.height * 0.45)
                Circle()
                    .fill(Palette.surface.opacity(0.2))
                    .overlay(Circle().stroke(Palette.surface.opacity(0.7), lineWidth: 1.5))
                    .frame(width: 520, height: 520)
                    .offset(x: -proxy.size.width * 0.65, y: proxy.size.height * 0.42)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func toggle(_ language: NativeWelcomeLanguage) {
        if selectedCodes.contains(language.code) { selectedCodes.removeAll { $0 == language.code } }
        else { selectedCodes.append(language.code) }
        NativeWelcomeLanguages.saveSelection(selectedCodes)
    }

    private func changeMode(_ next: Mode) {
        guard !session.isBusy else { return }
        focusedField = nil
        password = ""
        session.clearAccountMessages()
        mode = next
    }

    private func submitAccount() {
        guard !session.isBusy, mode == .signIn || mode == .signUp else { return }
        focusedField = nil
        NativeWelcomeLanguages.saveSelection(selectedCodes)
        let signingUp = mode == .signUp
        Task {
            if signingUp { await session.signUp(email: email, password: password) }
            else { await session.signIn(email: email, password: password) }
            password = ""
        }
    }
}

private struct WelcomePrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .padding(.horizontal, 16)
            .foregroundStyle(Palette.accentInk)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .shadow(color: Palette.accent.opacity(0.14), radius: 13, x: 0, y: 7)
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.55)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private extension View {
    func welcomeAccountField() -> some View {
        padding(15)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Palette.line.opacity(0.45), lineWidth: 1))
            .font(.body)
    }
}
