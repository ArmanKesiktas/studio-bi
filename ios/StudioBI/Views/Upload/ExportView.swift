import SwiftUI

struct ExportView: View {
    let datasetId: String
    @State private var showShareSheet = false
    @State private var isDownloading = false
    @State private var downloadedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)

                exportCard(
                    title: "Temizlenmiş CSV",
                    subtitle: "Yüklediğiniz verinin işlenmiş halini indirin.",
                    icon: "tablecells",
                    color: .green
                ) {
                    Task { await downloadCSV() }
                }

                if let error = errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .padding(16)
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportCard(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: action) {
                if isDownloading {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("İndiriliyor…")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    Label("İndir & Paylaş", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .disabled(isDownloading)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func downloadCSV() async {
        isDownloading = true
        errorMessage = nil
        do {
            let url = APIClient.shared.exportCSVURL(datasetId)
            let (localURL, _) = try await URLSession.shared.download(from: url)
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(datasetId).csv")
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: localURL, to: dest)
            downloadedURL = dest
            showShareSheet = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isDownloading = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
