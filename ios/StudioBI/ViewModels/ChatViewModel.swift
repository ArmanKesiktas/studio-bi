import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false

    private var datasetId: String?
    private let defaults = UserDefaults.standard

    let suggestedQuestions = [
        "Toplam satış ne kadar?",
        "En yüksek değer hangi satırda?",
        "Kaç benzersiz kategori var?",
        "Ortalama değer nedir?",
    ]

    func loadHistory(datasetId: String) {
        self.datasetId = datasetId
        let key = historyKey(datasetId)
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = saved
        }
    }

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
        saveHistory()
    }

    func sendSuggested(_ question: String, datasetId: String) async {
        inputText = question
        await send(datasetId: datasetId)
    }

    func clearHistory() {
        messages = []
        if let id = datasetId {
            defaults.removeObject(forKey: historyKey(id))
        }
    }

    private func saveHistory() {
        guard let id = datasetId,
              let data = try? JSONEncoder().encode(messages) else { return }
        defaults.set(data, forKey: historyKey(id))
    }

    private func historyKey(_ datasetId: String) -> String {
        "chatHistory_\(datasetId)"
    }
}
