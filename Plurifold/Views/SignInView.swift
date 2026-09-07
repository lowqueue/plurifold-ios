import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var session: NativeSession
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Wordmark().padding(.top, 36)
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Your Plurifold account")
                        Text("Welcome back.")
                            .font(.largeTitle.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
                        Text("Your languages. Your library. A little more each day.")
                            .foregroundStyle(Palette.secondary)
                    }

                    VStack(alignment: .leading, spacing: 20) {
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
                                .signInField()
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password").font(.subheadline.weight(.medium))
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .password)
                                .onSubmit(signIn)
                                .signInField()
                        }
                        if let error = session.errorMessage {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Palette.ink)
                                .accessibilityLabel("Sign-in message: \(error)")
                        }
                        Button(action: signIn) {
                            HStack(spacing: 10) {
                                if session.isBusy { ProgressView().tint(Palette.background) }
                                Text(session.isBusy ? "Signing in…" : "Sign in")
                            }
                        }
                        .buttonStyle(StudyButtonStyle())
                        .disabled(session.isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                        if session.canRestoreSession {
                            Button("Retry saved sign-in") {
                                Task { await session.restore() }
                            }
                            .frame(maxWidth: .infinity)
                            .disabled(session.isBusy)
                        }
                    }
                    .studyCard()

                    VStack(alignment: .leading, spacing: 8) {
                        Link("Create an account or reset your password ↗", destination: NativeSession.baseURL)
                            .font(.subheadline.weight(.medium))
                        Text("On the website, choose your languages to create an account, or choose Sign in, then Forgot password. Return here when you’re ready.")
                            .font(.footnote)
                            .foregroundStyle(Palette.secondary)
                    }
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: 480)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .studyBackground()
            .tint(Palette.ink)
            .onDisappear { password = "" }
        }
    }

    private func signIn() {
        guard !session.isBusy else { return }
        focusedField = nil
        Task { await session.signIn(email: email, password: password) }
    }
}

private extension View {
    func signInField() -> some View {
        padding(14)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
            .font(.body)
    }
}
