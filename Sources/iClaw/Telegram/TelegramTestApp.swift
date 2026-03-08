// TelegramTestApp.swift
// Barebone app entry point to test Telegram sign-in and last message display.
//
// SETUP:
//   1. Go to https://my.telegram.org → API development tools → create app
//   2. Replace YOUR_API_ID and YOUR_API_HASH below with your credentials
//   3. In Xcode: File → Add Package Dependencies → paste TDLibKit URL:
//      https://github.com/Swiftgram/TDLibKit
//   4. Add all .swift files from this folder to your Xcode target
//   5. Build & run on iOS 16+ or macOS 13+

import SwiftUI

// ── Fill these in before running ─────────────────────────────────────────────
private let kApiId:   Int32  = 0          // ← replace with your api_id integer
private let kApiHash: String = "YOUR_HASH" // ← replace with your api_hash string
// ─────────────────────────────────────────────────────────────────────────────

@main
struct TelegramTestApp: App {
    var body: some Scene {
        WindowGroup {
            LastMessageScreen(apiId: kApiId, apiHash: kApiHash)
        }
    }
}

// MARK: - Barebone "last message" screen

struct LastMessageScreen: View {

    @StateObject private var manager: TelegramManager

    init(apiId: Int32, apiHash: String) {
        _manager = StateObject(wrappedValue: TelegramManager(apiId: apiId, apiHash: apiHash))
    }

    var body: some View {
        Group {
            if manager.authState == .authenticated {
                lastMessageView
            } else {
                TelegramAuthView(manager: manager)
            }
        }
        .task { manager.start() }
    }

    // ── Simple "last message" card ────────────────────────────────────────────

    private var lastMessageView: some View {
        ZStack {
            Color(red: 0.05, green: 0.07, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 24) {

                // Header
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(manager.isConnected ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(manager.isConnected ? "Connected" : "Connecting…")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Text("Last Message")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }

                // Message card
                if let msg = manager.messages.first {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(msg.senderName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.16, green: 0.67, blue: 0.93))
                            Spacer()
                            Text(msg.date, style: .time)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.35))
                        }
                        if msg.chatTitle != msg.senderName {
                            Text("in \(msg.chatTitle)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.35))
                        }
                        Text(msg.text)
                            .font(.system(size: 17))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.07))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: msg.id)

                } else {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.15))
                        Text("Waiting for a message…")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.callout)
                    }
                    .padding(.top, 40)
                }

                Spacer()

                // Log out button
                Button {
                    manager.logout()
                } label: {
                    Text("Log out")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.bottom, 16)
            }
            .padding(.top, 60)
        }
    }
}
