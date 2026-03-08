// TelegramListenerView.swift
// Live message feed shown after successful login.
// Embed this OR use TelegramManager directly in your own views.

import SwiftUI

public struct TelegramListenerView: View {

    @ObservedObject var manager: TelegramManager
    @State private var filterText = ""
    @State private var showingSettings = false
    @State private var allowedUser = ""

    public init(manager: TelegramManager) {
        self.manager = manager
    }

    private var filteredMessages: [TelegramMessage] {
        if filterText.isEmpty { return manager.messages }
        return manager.messages.filter {
            $0.text.localizedCaseInsensitiveContains(filterText) ||
            $0.senderName.localizedCaseInsensitiveContains(filterText) ||
            $0.chatTitle.localizedCaseInsensitiveContains(filterText)
        }
    }

    public var body: some View {
        ZStack {
            Color(hex: "#0d1117").ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                searchBar
                Divider().overlay(Color.white.opacity(0.08))
                messageList
            }
        }
        .sheet(isPresented: $showingSettings) {
            settingsSheet
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Telegram Listener")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Circle()
                        .fill(manager.isConnected ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(manager.isConnected ? "Connected" : "Connecting…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            Button { showingSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.4))

            TextField("Search messages…", text: $filterText)
                .foregroundColor(.white)
                .tint(Color(hex: "#2AABEE"))

            if !filterText.isEmpty {
                Button { filterText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Message list

    private var messageList: some View {
        Group {
            if filteredMessages.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredMessages) { msg in
                            MessageRow(message: msg)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredMessages.count)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: manager.isConnected ? "tray" : "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.2))

            Text(manager.isConnected
                 ? "No messages yet\nListening for new messages…"
                 : "Connecting to Telegram…")
                .font(.callout)
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }

    // MARK: - Settings sheet

    private var settingsSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0d1117").ignoresSafeArea()

                Form {
                    Section {
                        HStack {
                            Image(systemName: "at")
                                .foregroundColor(Color(hex: "#2AABEE"))
                            TextField("username (without @)", text: $allowedUser)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                    } header: {
                        Text("Filter messages from")
                    } footer: {
                        Text("Leave empty to receive messages from everyone.")
                    }

                    Section {
                        Button(role: .destructive) {
                            showingSettings = false
                            manager.logout()
                        } label: {
                            Label("Logout", systemImage: "arrow.right.square")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let trimmed = allowedUser.trimmingCharacters(in: .whitespacesAndNewlines)
                        manager.setAllowedUser(trimmed.isEmpty ? nil : trimmed)
                        showingSettings = false
                    }
                }
            }
            .onAppear {
                allowedUser = manager.allowedUsername ?? ""
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Message row

private struct MessageRow: View {
    let message: TelegramMessage
    @State private var isCopied = false

    private var timeString: String {
        let fmt = DateFormatter()
        let now = Date()
        if Calendar.current.isDateInToday(message.date) {
            fmt.dateFormat = "HH:mm"
        } else {
            fmt.dateFormat = "MMM d, HH:mm"
        }
        return fmt.string(from: message.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(avatarColor(for: message.senderName))
                        .frame(width: 42, height: 42)
                    Text(initials(for: message.senderName))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(message.senderName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#2AABEE"))

                        Spacer()

                        Text(timeString)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                    }

                    if message.chatTitle != message.senderName {
                        Label(message.chatTitle, systemImage: "bubble.left.and.bubble.right")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                    }

                    Text(message.text)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Divider()
                .overlay(Color.white.opacity(0.06))
                .padding(.leading, 74)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.string = message.text
                isCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { isCopied = false }
            } label: {
                Label(isCopied ? "Copied!" : "Copy Text", systemImage: isCopied ? "checkmark" : "doc.on.doc")
            }

            Button {
                UIPasteboard.general.string = message.senderName
            } label: {
                Label("Copy Sender", systemImage: "person")
            }
        }
    }

    private func initials(for name: String) -> String {
        let cleaned = name.hasPrefix("@") ? String(name.dropFirst()) : name
        let parts = cleaned.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(cleaned.prefix(2)).uppercased()
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(hex: "#2AABEE"), Color(hex: "#E74C3C"), Color(hex: "#2ECC71"),
            Color(hex: "#9B59B6"), Color(hex: "#F39C12"), Color(hex: "#1ABC9C"),
            Color(hex: "#E67E22"), Color(hex: "#3498DB")
        ]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Color helper (same as AuthView)
extension Color {
    fileprivate init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
