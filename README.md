# OpenClaw Local (for macOS 26+)

**OpenClaw Local** is a lightning-fast, fully-local, native macOS AI agent. Built explicitly for macOS 26+ utilizing Swift 6.2 Strict Concurrency, it leverages Apple's on-device Foundation Models and Neural Engine to provide a private, highly capable assistant that lives completely on your machine.

## ✨ Features

- **Liquid Glass UI:** A gorgeous, unobtrusive floating HUD that utilizes SwiftUI's `.ultraThinMaterial` and dynamic mesh gradients, living quietly in your Menu Bar.
- **100% Local & Private:** No cloud processing. Everything from Speech-to-Text inference to LLM generation runs locally on Apple Silicon.
- **Auto-Compacting Memory:** Utilizes GRDB and `sqlite-vec` to maintain a massive local memory bank, seamlessly auto-compacting and summarizing past context so it never exceeds the model's 4K token limit.
- **Lightning Fast Vector Search:** Bundles a lightweight, dedicated CoreML embedding model to instantly query past memories and context without taxing the main LLM.
- **Progressive Permissions:** Uses `PermissionsKit` to only ask for what it needs, when it needs it. The agent natively understands when it is denied access and adapts.
- **Proactive Heartbeat:** The agent periodically wakes up in the background to review your current context, read its memory, and take proactive actions on your behalf.
- **Secure Extensibility:** Drag-and-drop support for `AgentSkills.io` Markdown files to instantly teach your agent new capabilities (safely sandboxed to HTTP `Fetch` operations).

## 🛠️ Built-In Toolbelt

OpenClaw comes pre-packaged with a deep integration into the macOS ecosystem:
- Web Search & HTTP Fetch
- File System Read (Desktop, Downloads, Documents)
- Semantic Summarization (NaturalLanguage NER)
- Native Calendar, Contacts, and Reminders integration
- Local Spotlight Search
- Messages/AppleScript integration
- System controls (Dark mode, Volume, App Launching)

## 🚀 Getting Started

*(Instructions for building via Xcode and required macOS 26+ SDKs will be added as the project develops.)*