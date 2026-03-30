import SwiftUI
import UniformTypeIdentifiers

struct UploadView: View {
    @StateObject private var vm = UploadViewModel()
    @State private var showFilePicker = false
    @Binding var uploadedDatasetId: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if vm.isLoading {
                    LoadingView(message: "Dosya yükleniyor ve analiz ediliyor…")
                } else {
                    dropZone
                }
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
                uploadedDatasetId = dataset?.datasetId
            }
            .alert("Hata", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("Tamam", role: .cancel) {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                }

                VStack(spacing: 8) {
                    Text("Verinizi Yükleyin")
                        .font(.title2.bold())
                    Text("CSV veya XLSX dosyanızı seçin.\nYapay zeka anında analiz eder.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Dosya Seç", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            HStack(spacing: 16) {
                formatBadge("CSV", icon: "tablecells")
                formatBadge("XLSX", icon: "tablecells.fill")
                formatBadge("XLS", icon: "doc.text")
            }

            Spacer()

            Text("Maksimum dosya boyutu: 50MB")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 32)
        }
    }

    private func formatBadge(_ name: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(name)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
