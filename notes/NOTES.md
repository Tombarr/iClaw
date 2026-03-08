# Project Notes: iClaw Local

## Project Overview
iClaw Local is a native macOS 26+ AI agent utilizing Apple Intelligence for private, on-device operations. It features a "Liquid Glass" UI, persistent menu bar presence, and a complex memory system with auto-compaction to fit within a 4K context window.

## Current Status
- Plan finalized and milestones established.
- Documentation infrastructure initialized.

## Key Build Commands & Environments
- **Target Platform:** macOS 26.0+
- **Language:** Swift 6.2 (Strict Concurrency)
- **Frameworks:** SwiftUI, EventKit, Contacts, NaturalLanguage, Speech, GRDB, sqlite-vec, PermissionsKit.

## Capabilities
- Persistence via Menu Bar (`NSStatusItem`).
- On-device LLM inference (Apple Foundation Models).
- Vector-based memory with auto-compaction.
- Progressive permissions via PermissionsKit.
- Extensible via AgentSkills.io Markdown format.
