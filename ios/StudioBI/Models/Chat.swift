import Foundation

struct ChatRequest: Codable {
    let question: String
}

struct ChatResponse: Codable {
    let question: String
    let answer: String
    let operationUsed: String
    let resultData: AnyCodable?
    let isMocked: Bool
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: Role
    let text: String

    init(role: Role, text: String) {
        self.id = UUID()
        self.role = role
        self.text = text
    }

    enum Role: String, Codable { case user, assistant }
}
