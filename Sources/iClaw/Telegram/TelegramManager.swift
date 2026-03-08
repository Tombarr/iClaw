// TelegramManager.swift
// Core manager: wraps TDLib, drives the auth state machine,
// and publishes incoming messages to your SwiftUI views.

import Foundation
import Combine
import TDLibKit

// MARK: - Message model your app receives

public struct TelegramMessage: Identifiable, Equatable {
    public let id: Int64
    public let chatId: Int64
    public let chatTitle: String
    public let senderName: String
    public let text: String
    public let date: Date
}

// MARK: - Auth state (mirrors TDLib's own auth enum cleanly)

public enum TelegramAuthState: Equatable {
    case idle
    case waitingForPhone
    case waitingForCode
    case waitingForPassword          // 2FA
    case waitingForRegistration      // new accounts
    case authenticated
    case loggingOut
    case error(String)
}

// MARK: - Manager

@MainActor
public final class TelegramManager: ObservableObject {

    // ── Published state ──────────────────────────────────────────────
    @Published public var authState: TelegramAuthState = .idle
    @Published public var messages: [TelegramMessage] = []
    @Published public var isConnected = false

    // Combine passthrough so embedders can react to individual messages
    public let messageSubject = PassthroughSubject<TelegramMessage, Never>()

    // Optional filter: if set, only messages from this username are forwarded
    public var allowedUsername: String? = nil

    // ── Private ──────────────────────────────────────────────────────
    private var client: TdClient!
    private let apiId: Int32
    private let apiHash: String
    private let appVersion: String
    private let databaseDirectory: String

    // Cache chat titles so we can attach them to messages
    private var chatTitleCache: [Int64: String] = [:]

    // MARK: - Init

    /// - Parameters:
    ///   - apiId:   From https://my.telegram.org  (Apps tab)
    ///   - apiHash: From https://my.telegram.org
    ///   - databaseDirectory: Where TDLib stores its session files.
    ///                        Defaults to a "TelegramSession" folder in Application Support.
    public init(
        apiId: Int32,
        apiHash: String,
        appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
        databaseDirectory: String? = nil
    ) {
        self.apiId   = apiId
        self.apiHash = apiHash
        self.appVersion = appVersion

        if let dir = databaseDirectory {
            self.databaseDirectory = dir
        } else {
            let appSupport = FileManager.default
                .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first!
                .appendingPathComponent("TelegramListener", isDirectory: true)
                .path
            try? FileManager.default.createDirectory(
                atPath: appSupport, withIntermediateDirectories: true
            )
            self.databaseDirectory = appSupport
        }
    }

    // MARK: - Lifecycle

    /// Call once (e.g. in .task modifier or onAppear) to start TDLib.
    public func start() {
        guard client == nil else { return }

        client = TdClient(updateHandler: { [weak self] update in
            // TDLib calls this on a background thread — hop to MainActor
            Task { @MainActor [weak self] in
                await self?.handle(update: update)
            }
        })
        authState = .waitingForPhone
    }

    public func stop() {
        Task {
            try? await client.send(request: LogOut())
            authState = .loggingOut
        }
    }

    // MARK: - Auth actions (called from AuthView)

    public func submitPhone(_ phone: String) {
        Task {
            do {
                _ = try await client.send(request: SetAuthenticationPhoneNumber(
                    phoneNumber: phone,
                    settings: .init(
                        allowFlashCall: false,
                        allowMissedCall: false,
                        allowSmsRetrieverApi: false,
                        authenticationTokens: nil,
                        firebaseAuthenticationSettings: nil,
                        hasUnknownPhoneNumber: false,
                        isCurrentPhoneNumber: false
                    )
                ))
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    public func submitCode(_ code: String) {
        Task {
            do {
                _ = try await client.send(request: CheckAuthenticationCode(code: code))
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    public func submitPassword(_ password: String) {
        Task {
            do {
                _ = try await client.send(request: CheckAuthenticationPassword(password: password))
            } catch {
                authState = .error(error.localizedDescription)
            }
        }
    }

    public func resendCode() {
        Task {
            try? await client.send(request: ResendAuthenticationCode(reason: nil))
        }
    }

    public func logout() {
        Task {
            try? await client.send(request: LogOut())
        }
    }

    // MARK: - Filtering

    /// Restrict listening to a specific username (without @)
    public func setAllowedUser(_ username: String?) {
        allowedUsername = username
    }

    // MARK: - Update handler

    private func handle(update: Update) async {
        switch update {

        // ── Auth state machine ───────────────────────────────────────
        case .updateAuthorizationState(let u):
            await handleAuthState(u.authorizationState)

        // ── Connection ───────────────────────────────────────────────
        case .updateConnectionState(let u):
            isConnected = u.state == .connectionStateReady(ConnectionStateReady())

        // ── New messages ─────────────────────────────────────────────
        case .updateNewMessage(let u):
            await handleNewMessage(u.message)

        // ── Chat metadata (cache titles) ─────────────────────────────
        case .updateNewChat(let u):
            if let title = u.chat.title {
                chatTitleCache[u.chat.id] = title.isEmpty ? "Chat \(u.chat.id)" : title
            }

        default:
            break
        }
    }

    // MARK: - Auth state machine

    private func handleAuthState(_ state: AuthorizationState) async {
        switch state {
        case .authorizationStateWaitTdlibParameters:
            await sendTdlibParams()

        case .authorizationStateWaitPhoneNumber:
            authState = .waitingForPhone

        case .authorizationStateWaitCode:
            authState = .waitingForCode

        case .authorizationStateWaitPassword:
            authState = .waitingForPassword

        case .authorizationStateWaitRegistration:
            authState = .waitingForRegistration

        case .authorizationStateReady:
            authState = .authenticated
            // Load recent chats so TDLib populates its chat cache
            try? await client.send(request: LoadChats(chatList: nil, limit: 50))

        case .authorizationStateLoggingOut, .authorizationStateClosing:
            authState = .loggingOut

        case .authorizationStateClosed:
            authState = .idle
            client = nil

        default:
            break
        }
    }

    private func sendTdlibParams() async {
        let params = SetTdlibParameters(
            apiHash: apiHash,
            apiId: apiId,
            applicationVersion: appVersion,
            databaseDirectory: databaseDirectory,
            databaseEncryptionKey: Data(),
            deviceModel: "Mac",
            filesDirectory: databaseDirectory + "/files",
            systemLanguageCode: Locale.current.language.languageCode?.identifier ?? "en",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            useChatInfoDatabase: true,
            useFileDatabase: true,
            useMessageDatabase: true,
            useSecretChats: false,
            useTestDc: false
        )
        try? await client.send(request: params)
    }

    // MARK: - Message handling

    private func handleNewMessage(_ message: Message) async {
        // Only text messages for now
        guard case .messageText(let textContent) = message.content,
              let text = textContent.text?.text,
              !text.isEmpty else { return }

        // Resolve sender name
        let senderName = await resolveSenderName(message.senderId)

        // Apply username filter
        if let allowed = allowedUsername {
            guard senderName.lowercased() == allowed.lowercased() ||
                  senderName.lowercased() == "@\(allowed.lowercased())" else { return }
        }

        // Resolve chat title
        let chatTitle: String
        if let cached = chatTitleCache[message.chatId] {
            chatTitle = cached
        } else {
            // Try to fetch it
            if let chat = try? await client.send(request: GetChat(chatId: message.chatId)) {
                chatTitle = chat.title ?? "Chat \(message.chatId)"
                chatTitleCache[message.chatId] = chatTitle
            } else {
                chatTitle = "Chat \(message.chatId)"
            }
        }

        let tgMessage = TelegramMessage(
            id: message.id,
            chatId: message.chatId,
            chatTitle: chatTitle,
            senderName: senderName,
            text: text,
            date: Date(timeIntervalSince1970: TimeInterval(message.date))
        )

        messages.insert(tgMessage, at: 0)
        messageSubject.send(tgMessage)
    }

    private func resolveSenderName(_ senderId: MessageSender?) async -> String {
        switch senderId {
        case .messageSenderUser(let s):
            if let user = try? await client.send(request: GetUser(userId: s.userId)) {
                let first = user.firstName ?? ""
                let last  = user.lastName  ?? ""
                let name  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")
                if let username = user.usernames?.activeUsernames?.first {
                    return "@\(username)"
                }
                return name.isEmpty ? "User \(s.userId)" : name
            }
            return "User \(s.userId)"

        case .messageSenderChat(let s):
            return chatTitleCache[s.chatId] ?? "Chat \(s.chatId)"

        default:
            return "Unknown"
        }
    }
}
