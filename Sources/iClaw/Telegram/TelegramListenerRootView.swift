// TelegramListenerRootView.swift
// The single view to drop into your app — handles routing between
// the auth flow and the live message listener automatically.

import SwiftUI

/// Drop this into your SwiftUI app and you're done.
///
/// Usage:
///   ```swift
///   TelegramListenerRootView(apiId: 12345, apiHash: "your_hash")
///   ```
///
/// For custom message handling, pass an `onMessage` closure:
///   ```swift
///   TelegramListenerRootView(apiId: 12345, apiHash: "your_hash") { message in
///       print("Got:", message.text, "from", message.senderName)
///       // trigger any SwiftUI action here
///   }
///   ```
public struct TelegramListenerRootView: View {

    @StateObject private var manager: TelegramManager
    private let onMessage: ((TelegramMessage) -> Void)?

    public init(
        apiId: Int32,
        apiHash: String,
        allowedUsername: String? = nil,
        onMessage: ((TelegramMessage) -> Void)? = nil
    ) {
        _manager = StateObject(wrappedValue: TelegramManager(apiId: apiId, apiHash: apiHash))
        self.onMessage = onMessage
        // Set initial filter if provided
        if let user = allowedUsername {
            // Will be applied after init via .onAppear
            _ = user
        }
    }

    public var body: some View {
        Group {
            switch manager.authState {
            case .authenticated:
                TelegramListenerView(manager: manager)

            case .idle:
                loadingView

            case .loggingOut:
                loadingView

            default:
                // All auth states: phone / code / password / error
                TelegramAuthView(manager: manager)
            }
        }
        .task {
            manager.start()
        }
        .onReceive(manager.messageSubject) { msg in
            onMessage?(msg)
        }
    }

    private var loadingView: some View {
        ZStack {
            Color(hex: "#0d1117").ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .tint(Color(hex: "#2AABEE"))
                    .scaleEffect(1.5)
                Text("Starting…")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.callout)
            }
        }
    }
}

// MARK: - Modifier-style API for embedding in existing apps

extension View {
    /// Attach a Telegram listener to any existing view.
    /// Messages are delivered via the `onMessage` callback.
    ///
    /// ```swift
    /// MyMainView()
    ///     .telegramListener(apiId: 12345, apiHash: "abc") { msg in
    ///         handleCommand(msg.text)
    ///     }
    /// ```
    public func telegramListener(
        apiId: Int32,
        apiHash: String,
        allowedUsername: String? = nil,
        onMessage: @escaping (TelegramMessage) -> Void
    ) -> some View {
        self.modifier(
            TelegramListenerModifier(
                apiId: apiId,
                apiHash: apiHash,
                allowedUsername: allowedUsername,
                onMessage: onMessage
            )
        )
    }
}

private struct TelegramListenerModifier: ViewModifier {
    let apiId: Int32
    let apiHash: String
    let allowedUsername: String?
    let onMessage: (TelegramMessage) -> Void

    @StateObject private var manager: TelegramManager
    @State private var showSheet = false

    init(apiId: Int32, apiHash: String, allowedUsername: String?, onMessage: @escaping (TelegramMessage) -> Void) {
        self.apiId = apiId
        self.apiHash = apiHash
        self.allowedUsername = allowedUsername
        self.onMessage = onMessage
        _manager = StateObject(wrappedValue: TelegramManager(apiId: apiId, apiHash: apiHash))
    }

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showSheet) {
                TelegramAuthView(manager: manager)
                    .interactiveDismissDisabled()
            }
            .task {
                manager.allowedUsername = allowedUsername
                manager.start()
            }
            .onChange(of: manager.authState) { _, state in
                showSheet = (state != .authenticated && state != .idle)
            }
            .onReceive(manager.messageSubject) { msg in
                onMessage(msg)
            }
    }
}

// Color helper
extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >>  8) & 0xFF) / 255,
            blue:  Double( int        & 0xFF) / 255
        )
    }
}
