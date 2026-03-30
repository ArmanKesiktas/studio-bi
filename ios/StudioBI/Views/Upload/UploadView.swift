import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var vm = UploadViewModel()
    @State private var showFilePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    if vm.isLoading {
                        analysisAnimation
                    } else {
                        heroSection
                        uploadButton
                        formatBadges

                        if !appState.recentDatasets.isEmpty {
                            recentSection
                        }
                    }
                }
                .padding(.vertical, DS.Spacing.xl)
            }
            .navigationTitle("Studio BI")
            .navigationBarTitleDisplayMode(.large)
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: vm.supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await vm.upload(fileURL: url) }
                case .failure(let error):
                    vm.errorMessage = error.localizedDescription
                }
            }
            .onChange(of: vm.uploadedDataset) { _, dataset in
                if let dataset {
                    appState.setActive(dataset)
                }
            }
            .alert("Bir Sorun Oluştu", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.accentSoft)
                    .frame(width: 100, height: 100)
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(DS.Colors.accent)
            }

            VStack(spacing: DS.Spacing.sm) {
                Text("Verinizi Yükleyin")
                    .font(DS.Font.headline)
                Text("Dosyanızı seçin, yapay zeka anında analiz etsin.")
                    .font(DS.Font.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Upload Button

    private var uploadButton: some View {
        Button {
            showFilePicker = true
        } label: {
            Label("Dosya Seç", systemImage: "doc.badge.plus")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.buttonHeight)
        }
        .buttonStyle(.borderedProminent)
        .tint(DS.Colors.accent)
        .padding(.horizontal, DS.Spacing.xl)
    }

    // MARK: - Format Badges

    private var formatBadges: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(["CSV", "XLSX", "JSON"], id: \.self) { fmt in
                Text(fmt)
                    .font(DS.Font.captionBold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.small))
            }
        }
    }

    // MARK: - Sequential Analysis Animation

    private var analysisAnimation: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer().frame(height: DS.Spacing.xxl)

            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(DS.Colors.accent)
                .symbolEffect(.pulse, options: .repeating)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                AnalysisStepRow(text: "Dosya okunuyor…", done: vm.uploadProgress > 0.3)
                AnalysisStepRow(text: "Yapı analiz ediliyor…", done: vm.uploadProgress > 0.7)
                AnalysisStepRow(text: "AI içgörüler üretiliyor…", done: vm.uploadProgress >= 1.0, isActive: vm.uploadProgress > 0.7)
            }
            .padding(.horizontal, DS.Spacing.xxl)

            ProgressView(value: min(vm.uploadProgress, 1.0))
                .progressViewStyle(.linear)
                .tint(DS.Colors.accent)
                .padding(.horizontal, DS.Spacing.xxl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Recent Datasets

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Son Veriler")
                .font(DS.Font.title)
                .padding(.horizontal, DS.Spacing.md)

            ForEach(appState.recentDatasets, id: \.datasetId) { dataset in
                Button {
                    appState.openRecent(dataset)
                } label: {
                    HStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DS.Colors.accent)
                            .frame(width: 36)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(dataset.filename)
                                .font(DS.Font.captionBold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("\(dataset.rowCount) satır · \(dataset.colCount) sütun")
                                .font(DS.Font.micro)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(DS.Spacing.sm + DS.Spacing.xs)
                    .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, DS.Spacing.md)
            }
        }
        .padding(.top, DS.Spacing.sm)
    }
}

// MARK: - Analysis Step Row

private struct AnalysisStepRow: View {
    let text: String
    let done: Bool
    var isActive: Bool = false

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DS.Colors.success)
                    .font(.system(size: 18, weight: .medium))
            } else if isActive {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 18, height: 18)
            } else {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
            }
            Text(text)
                .font(DS.Font.body)
                .foregroundStyle(done ? .primary : .secondary)
        }
        .animation(.easeInOut(duration: 0.3), value: done)
    }
}
