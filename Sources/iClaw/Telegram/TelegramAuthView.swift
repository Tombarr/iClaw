// TelegramAuthView.swift
// Drop-in auth flow: phone → OTP code → (optional) 2FA password → done.
// Works on iOS and macOS (SwiftUI shared code).

import SwiftUI

public struct TelegramAuthView: View {

    @ObservedObject var manager: TelegramManager

    @State private var phone    = ""
    @State private var code     = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field { case phone, code, password }

    public init(manager: TelegramManager) {
        self.manager = manager
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(hex: "#1a1f3a"), Color(hex: "#0d1117")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()
                    headerSection
                    Spacer().frame(height: 48)
                    inputCard
                    Spacer()
                    footerNote
                }
                .padding(.horizontal, 24)
            }
        }
        .tint(Color(hex: "#2AABEE"))
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Telegram plane icon (SF Symbols fallback)
            ZStack {
                Circle()
                    .fill(Color(hex: "#2AABEE").opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Color(hex: "#2AABEE"))
            }

            Text("Telegram Listener")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: String {
        switch manager.authState {
        case .waitingForPhone:    return "Enter your phone number to sign in"
        case .waitingForCode:     return "Enter the code sent to your Telegram"
        case .waitingForPassword: return "Enter your Two-Step Verification password"
        default:                  return ""
        }
    }

    private var inputCard: some View {
        VStack(spacing: 20) {
            switch manager.authState {
            case .waitingForPhone:
                phoneInput

            case .waitingForCode:
                codeInput

            case .waitingForPassword:
                passwordInput

            case .error(let msg):
                errorView(msg)

            default:
                ProgressView()
                    .tint(Color(hex: "#2AABEE"))
                    .scaleEffect(1.4)
            }
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Phone input

    private var phoneInput: some View {
        VStack(spacing: 16) {
            TGTextField(
                placeholder: "+1 555 000 0000",
                text: $phone,
                keyboardType: .phonePad,
                focused: $focusedField,
                field: .phone,
                icon: "phone.fill"
            )
            .onAppear { focusedField = .phone }

            TGPrimaryButton(
                title: "Send Code",
                isLoading: isLoading,
                action: sendPhone
            )
        }
    }

    // MARK: - Code input

    private var codeInput: some View {
        VStack(spacing: 16) {
            // OTP boxes
            OTPField(code: $code)
                .onAppear { focusedField = .code }

            TGPrimaryButton(
                title: "Verify",
                isLoading: isLoading,
                action: sendCode
            )

            Button {
                manager.resendCode()
            } label: {
                Text("Resend code")
                    .font(.footnote)
                    .foregroundColor(Color(hex: "#2AABEE"))
            }
        }
    }

    // MARK: - Password input

    private var passwordInput: some View {
        VStack(spacing: 16) {
            TGSecureField(
                placeholder: "2FA Password",
                text: $password,
                focused: $focusedField,
                field: .password,
                icon: "lock.fill"
            )
            .onAppear { focusedField = .password }

            TGPrimaryButton(
                title: "Confirm",
                isLoading: isLoading,
                action: sendPassword
            )
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red.opacity(0.9))
                .font(.callout)
                .multilineTextAlignment(.center)

            TGPrimaryButton(title: "Try Again", isLoading: false) {
                manager.authState = .waitingForPhone
                phone = ""; code = ""; password = ""
            }
        }
    }

    private var footerNote: some View {
        Text("Your session is stored locally. We never store your credentials.")
            .font(.caption2)
            .foregroundColor(.white.opacity(0.3))
            .multilineTextAlignment(.center)
            .padding(.bottom, 24)
    }

    // MARK: - Actions

    private func sendPhone() {
        guard !phone.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isLoading = true
        manager.submitPhone(phone)
        // TDLib will callback → authState changes → loading resolves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isLoading = false }
    }

    private func sendCode() {
        guard code.count >= 4 else { return }
        isLoading = true
        manager.submitCode(code)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isLoading = false }
    }

    private func sendPassword() {
        guard !password.isEmpty else { return }
        isLoading = true
        manager.submitPassword(password)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isLoading = false }
    }
}

// MARK: - Reusable sub-components

private struct TGTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    @FocusState.Binding var focused: TelegramAuthView.Field?
    let field: TelegramAuthView.Field
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#2AABEE"))
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .foregroundColor(.white)
                .focused($focused, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focused == field
                                ? Color(hex: "#2AABEE")
                                : Color.white.opacity(0.12),
                            lineWidth: 1.5
                        )
                )
        )
    }
}

private struct TGSecureField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState.Binding var focused: TelegramAuthView.Field?
    let field: TelegramAuthView.Field
    let icon: String
    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "#2AABEE"))
                .frame(width: 20)

            if isRevealed {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundColor(.white)
                    .focused($focused, equals: field)
            } else {
                SecureField(placeholder, text: $text)
                    .foregroundColor(.white)
                    .focused($focused, equals: field)
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            focused == field
                                ? Color(hex: "#2AABEE")
                                : Color.white.opacity(0.12),
                            lineWidth: 1.5
                        )
                )
        )
    }
}

private struct TGPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#2AABEE"), Color(hex: "#1a8fd1")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isLoading)
    }
}

// MARK: - OTP field (6 boxes)

private struct OTPField: View {
    @Binding var code: String
    private let length = 6

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<length, id: \.self) { i in
                let char = character(at: i)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(char == nil ? 0.06 : 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    char != nil
                                        ? Color(hex: "#2AABEE")
                                        : Color.white.opacity(0.15),
                                    lineWidth: 1.5
                                )
                        )
                        .frame(height: 52)

                    Text(char.map(String.init) ?? "")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .overlay(
            // Hidden text field driving the input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .opacity(0.001)
                .onChange(of: code) { _, new in
                    code = String(new.prefix(length).filter(\.isNumber))
                }
        )
    }

    private func character(at index: Int) -> Character? {
        guard index < code.count else { return nil }
        return code[code.index(code.startIndex, offsetBy: index)]
    }
}

// MARK: - Color hex helper

extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
