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

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String

    enum Role { case user, assistant }
}
