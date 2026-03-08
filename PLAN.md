# iClaw Local (macOS 26+)

A native macOS 26+ app that uses Apple Intelligence (Foundation Models, Neural Engine, etc.) to work as a local AI agent fully on-device and private.

## 1. App Foundation & Interface
*   **Platform:** macOS 26+, built in Xcode using Swift 6.2+ (Strict Concurrency).
*   **Architecture:** Persistent Menu Bar (`NSStatusItem`) app running continuously in the background.
*   **UI (Liquid Glass):** A floating, non-activatable SwiftUI `.hudWindow` utilizing `.ultraThinMaterial`, animated mesh gradients, and strict rounded corners. Hidden by default; summoned via Menu Bar click or global keyboard shortcut.
*   **Input Handling:**
    *   Standard text field.
    *   On-device, streaming Speech-to-Text via the `SpeechAnalyzer` API.
    *   `DropDelegate` on the window to support dragging and dropping `.md` Skill files directly into the agent.

## 2. AI Core, Context, & Memory
*   **Model:** Apple Foundation Models (Local, Private, 4K context window limit).
*   **Memory Engine (`GRDB` + `sqlite-vec`):** Stores embeddings of user inputs, agent responses, and tool outputs. The schema includes `id`, `role`, `content`, `embedding`, `created_at` (Timestamp), and `is_important` (Boolean).
*   **Embeddings Engine:** Bundles a lightweight CoreML model (e.g., all-MiniLM-L6-v2) specifically for generating vector embeddings quickly without taxing the main LLM.
*   **Auto-Compaction:** Before sending a prompt, a token counter checks the 4K limit. If nearing the limit, the internal `Summarize` tool compresses older context window messages into a dense summary, maintaining semantic vectors in SQLite while keeping the active prompt small.
*   **Personality (`SOUL.md`):** Terse, dry, highly actionable, zero sycophancy (no "I'd be happy to help!"). 
*   **Personalization:** Uses the `Contacts` framework to fetch the user's "Me" card. Injects the user's Name, Email, and Phone Number dynamically into the System Prompt.
*   **Proactive Heartbeat:** A background timer fires every 15 minutes, prompting the AI to review its recent memory and system state, and act proactively if necessary (or just output "IDLE").

## 3. Tool & Skill Engine
*   **Permissions Management:** Progressive disclosure using `PermissionsKit`. Tools request permission only upon first invocation. Denials return explicit failure strings to the agent so it can explain *why* it can't complete a task.
*   **Pre-packaged Core Skills:**
    *   `WebSearch` (Google/DDG fallback -> HTML parsing -> Auto-summarization).
    *   `Fetch` (Basic HTTP GET).
    *   `ReadFile` (File system access to Desktop, Downloads, Documents).
    *   `Summarize` (NaturalLanguage NER + Foundation Model chunking).
    *   `Calendar`, `Contacts`, `Reminders` (Native EventKit/Contacts frameworks).
    *   `SendMessage` (AppleScript via Messages.app).
    *   `SpotlightSearch` (NSMetadataQuery for local files).
    *   `ClipboardManager` (NSPasteboard read/write).
    *   `SystemControl` (Dark mode, volume, etc.).
    *   `AppManager` (Open/Quit applications).
*   **Dynamic Skill Loader:** Parses `AgentSkills.io` Markdown files. Extracts Name, Description, System Prompt additions, and tool schemas to dynamically expand the agent's capabilities at runtime. **Security Sandbox:** External skills are strictly limited to the built-in `Fetch` tool (HTTP requests only). Arbitrary local script execution is blocked.

## 4. Initialization & Lifecycle
*   **Launch:** App loads quietly to the menu bar.
*   **Boot sequence:** Initialize GRDB SQLite vector store, check basic required directory access. Load `SOUL.md` and attempt to load the local user's Contact card ("Me") to populate system context variables. Watch external skills folder (e.g. `~/Documents/AgentSkills`).
*   **Execution Loop:** Listen for user interaction (UI summon) or wait for the 15-minute heartbeat interval.