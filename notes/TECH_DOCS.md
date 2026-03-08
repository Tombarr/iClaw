# Technical Documentation: OpenClaw Local

## Architecture
### UI Layer
- **Interface:** SwiftUI 6.2+.
- **Window Management:** `NSStatusItem` + `HUDPanel` (subclass of `NSPanel`).
- **Styling:** Liquid Glass (ultraThinMaterial, MeshGradient).

### AI & Memory Layer
- **Engine:** Apple Foundation Models (MLX or native LLM API).
- **Context Management:** 4K window limit.
- **Memory Store:** SQLite (via GRDB) + `sqlite-vec` for semantic search. Schema includes `id`, `role`, `content`, `embedding`, `created_at`, and `is_important`.
- **Embedding Engine:** Dedicated lightweight CoreML model (e.g., all-MiniLM-L6-v2) for fast vector generation, offloading work from the main LLM.
- **Compaction Strategy:** Token-based trigger -> LLM Summarization -> Vector embedding.

### Tool & Skill Engine
- **Core Skills:** WebSearch, Fetch, ReadFile, Summarize, Calendar, Contacts, Reminders, SendMessage, SpotlightSearch, ClipboardManager, SystemControl, AppManager.
- **Loader:** Custom Markdown parser for `AgentSkills.io` spec.
- **Security Sandbox:** Externally loaded skills are restricted to HTTP operations via the built-in `Fetch` tool to prevent arbitrary local code execution.
- **Permissions:** Integrated with `PermissionsKit`.

### Heartbeat
- Periodic background task (default 15 mins) that analyzes context and system state to determine if proactive action is required.

## External Dependencies
- **GRDB.swift:** SQLite wrapper.
- **sqlite-vec:** SQLite extension for vector search.
- **PermissionsKit:** macOS permissions management.
- **SwiftSoup:** HTML parsing for web tools.