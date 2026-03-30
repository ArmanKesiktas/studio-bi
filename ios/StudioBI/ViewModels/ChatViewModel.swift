import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false

    let suggestedQuestions = [
        "Toplam satış ne kadar?",
        "En yüksek değer hangi satırda?",
        "Kaç benzersiz kategori var?",
        "Ortalama değer nedir?",
    ]

    func send(datasetId: String) async {
        let question = inputText.trimmingCharacters(in: .whitespaces)
        guard !question.isEmpty, !isLoading else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: question))
        isLoading = true

        do {
            let response = try await APIClient.shared.chat(datasetId, question: question)
            messages.append(ChatMessage(role: .assistant, text: response.answer))
        } catch {
            messages.append(ChatMessage(role: .assistant, text: "Hata: \(error.localizedDescription)"))
        }

        isLoading = false
    }

    func sendSuggested(_ question: String, datasetId: String) async {
        inputText = question
        await send(datasetId: datasetId)
    }
}
