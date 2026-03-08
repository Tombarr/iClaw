import SwiftUI
import AppKit

@main
struct OpenClawLocalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    var statusItem: NSStatusItem?
    var hudWindow: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupHUDWindow()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "OpenClaw Local")
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }

    private func setupHUDWindow() {
        hudWindow = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.nonactivatingPanel, .hudWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        hudWindow?.isFloatingPanel = true
        hudWindow?.level = .floating
        hudWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hudWindow?.backgroundColor = .clear
        hudWindow?.contentView = NSHostingView(rootView: ChatView())
    }

    @objc func toggleWindow() {
        guard let hudWindow = hudWindow else { return }
        if hudWindow.isVisible {
            hudWindow.orderOut(nil)
        } else {
            // Position near the status item
            if let button = statusItem?.button, let window = button.window {
                let frame = window.frame
                hudWindow.setFrameOrigin(NSPoint(x: frame.minX - hudWindow.frame.width / 2 + frame.width / 2, y: frame.minY - hudWindow.frame.height - 5))
            }
            hudWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

struct ChatView: View {
    var body: some View {
        VStack {
            Text("OpenClaw Local")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text("Liquid Glass UI Coming Soon...")
                .foregroundStyle(.tertiary)
            
            Spacer()
            
            TextField("Message...", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectView(material: .ultraThinMaterial, blendingMode: .withinWindow).ignoresSafeArea())
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
