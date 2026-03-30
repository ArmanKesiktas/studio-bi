import SwiftUI

struct ChatView: View {
    let datasetId: String
    @StateObject private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if vm.messages.isEmpty {
                            suggestedQuestions
                        }
                        ForEach(vm.messages) { msg in
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                        if vm.isLoading {
                            thinkingIndicator
                        }
                    }
                    .padding(16)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
        .task { vm.loadHistory(datasetId: datasetId) }
        .toolbar {
            if !vm.messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        vm.clearHistory()
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
    }

    private var suggestedQuestions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Örnek sorular", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(vm.suggestedQuestions, id: \.self) { q in
                Button {
                    Task { await vm.sendSuggested(q, datasetId: datasetId) }
                } label: {
                    Text(q)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 16)
    }

    private var thinkingIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(.blue)
            Text("Analiz ediliyor…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView()
                .scaleEffect(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Veriniz hakkında bir şey sorun…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...4)
                .font(.subheadline)
                .padding(10)
                .background(Color(.systemFill), in: RoundedRectangle(cornerRadius: 12))
                .focused($inputFocused)
                .onSubmit {
                    Task { await vm.send(datasetId: datasetId) }
                }

            Button {
                Task { await vm.send(datasetId: datasetId) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(vm.inputText.isEmpty || vm.isLoading ? .gray : .blue)
            }
            .disabled(vm.inputText.isEmpty || vm.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .frame(width: 24, height: 24)
                    .background(.blue.opacity(0.1), in: Circle())
            }

            Text(message.text)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                        ? Color.blue
                        : Color(.systemFill),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.blue.opacity(0.5))
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
