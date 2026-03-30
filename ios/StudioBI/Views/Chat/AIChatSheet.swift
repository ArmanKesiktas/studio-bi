import SwiftUI

// MARK: - AI Chat Bottom Sheet (replaces tab)

struct AIChatSheet: View {
    let datasetId: String
    let segment: Int
    @StateObject private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool

    private var contextLabel: String {
        switch segment {
        case 0: return "Veri özeti hakkında"
        case 1: return "Tablo verileri hakkında"
        case 2: return "Dashboard hakkında"
        default: return "Veri hakkında"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text("Veriye Sor")
                    .font(DS.Font.title)
                Spacer()
                Text(contextLabel)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.surface, in: Capsule())
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.sm)

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: DS.Spacing.sm) {
                        if vm.messages.isEmpty {
                            suggestedQuestions
                        }

                        ForEach(vm.messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }

                        if vm.isLoading {
                            thinkingIndicator
                        }
                    }
                    .padding(DS.Spacing.md)
                }
                .onChange(of: vm.messages.count) { _, _ in
                    if let last = vm.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input
            inputBar
        }
        .task { vm.loadHistory(datasetId: datasetId) }
    }

    // MARK: - Suggested Questions

    private var suggestedQuestions: some View {
        VStack(spacing: DS.Spacing.sm) {
            Spacer().frame(height: DS.Spacing.md)

            Image(systemName: "sparkles")
                .font(.system(size: 28))
                .foregroundStyle(DS.Colors.accent.opacity(0.4))

            Text("Veriniz hakkında bir şey sorun")
                .font(DS.Font.body)
                .foregroundStyle(.secondary)

            Spacer().frame(height: DS.Spacing.sm)

            ForEach(vm.suggestedQuestions, id: \.self) { q in
                Button {
                    Task { await vm.sendSuggested(q, datasetId: datasetId) }
                } label: {
                    Text(q)
                        .font(DS.Font.caption)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(height: DS.Size.pillHeight)
                        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.small))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Thinking Indicator

    private var thinkingIndicator: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "sparkles")
                .foregroundStyle(DS.Colors.accent)
                .symbolEffect(.pulse)
            Text("Analiz ediliyor…")
                .font(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.sm + DS.Spacing.xs)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            TextField("Bir soru sorun…", text: $vm.inputText, axis: .vertical)
                .lineLimit(1...3)
                .font(DS.Font.body)
                .padding(DS.Spacing.sm + DS.Spacing.xs)
                .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .focused($inputFocused)
                .onSubmit {
                    Task { await vm.send(datasetId: datasetId) }
                }

            Button {
                inputFocused = false
                Task { await vm.send(datasetId: datasetId) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading
                        ? Color.gray.opacity(0.4) : DS.Colors.accent)
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
    }
}

// MARK: - Chat Bubble (premium)

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                    .frame(width: 24, height: 24)
                    .background(DS.Colors.accentSoft, in: Circle())
            }

            Text(message.text)
                .font(DS.Font.body)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
                .background(
                    message.role == .user
                        ? AnyShapeStyle(DS.Colors.accent)
                        : AnyShapeStyle(DS.Colors.surface),
                    in: RoundedRectangle(cornerRadius: DS.Radius.card)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
