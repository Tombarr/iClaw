import Foundation
import Contacts
import FoundationModels

@MainActor
class MeCardManager {
    static let shared = MeCardManager()
    
    var userName: String = NSFullUserName()
    var userEmail: String?
    var userPhone: String?
    
    private init() {
        fetchMeCard()
    }
    
    func fetchMeCard() {
        let store = CNContactStore()
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        
        do {
            let me = try store.unifiedMeContactWithKeys(toFetch: keys)
            self.userName = "\(me.givenName) \(me.familyName)".trimmingCharacters(in: .whitespaces)
            self.userEmail = me.emailAddresses.first?.value as String?
            self.userPhone = me.phoneNumbers.first?.value.stringValue
        } catch {
            // Silently fail if no access
        }
    }
}

@MainActor
class ModelManager {
    static let shared = ModelManager()
    
    private var soul: String = ""
    
    private init() {
        if let soulPath = Bundle.main.path(forResource: "SOUL", ofType: "md"),
           let content = try? String(contentsOfFile: soulPath, encoding: .utf8) {
            self.soul = content
        } else {
            // Fallback soul if not found in bundle
            self.soul = "You are a local macOS AI agent. Be terse, sassy, and direct."
        }
    }
    
    func generateSystemPrompt() -> String {
        let me = MeCardManager.shared
        let userInfo = """
        User Info:
        Name: \(me.userName)
        Email: \(me.userEmail ?? "Unknown")
        Phone: \(me.userPhone ?? "Unknown")
        """
        
        return soul + "\n\n" + userInfo
    }
    
    func generateResponse(prompt: String, history: [Memory]) async throws -> String {
        let systemPrompt = generateSystemPrompt()

        // Build conversation context from memory history
        var contextMessages = ""
        for memory in history.suffix(10) {
            contextMessages += "\(memory.role): \(memory.content)\n"
        }

        let fullPrompt: String
        if contextMessages.isEmpty {
            fullPrompt = prompt
        } else {
            fullPrompt = "Previous context:\n\(contextMessages)\nUser: \(prompt)"
        }

        let session = LanguageModelSession(instructions: systemPrompt)
        let response = try await session.respond(to: fullPrompt)
        return response.content
    }
}
