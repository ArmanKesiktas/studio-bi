import SwiftUI

// MARK: - Export Bottom Sheet (replaces tab)

struct ExportSheet: View {
    let datasetId: String
    @State private var isDownloading = false
    @State private var showShareSheet = false
    @State private var downloadedURL: URL?
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header
            HStack {
                Text("Dışa Aktar")
                    .font(DS.Font.headline)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            // Export options
            exportOption(
                icon: "tablecells.fill",
                color: DS.Colors.success,
                title: "CSV İndir",
                subtitle: "Temizlenmiş veriyi CSV olarak indirin"
            ) {
                Task { await downloadCSV() }
            }

            exportOption(
                icon: "doc.text.fill",
                color: DS.Colors.accent,
                title: "Veriyi Paylaş",
                subtitle: "Dosyayı başka uygulamalara gönderin"
            ) {
                Task { await downloadCSV() }
            }

            if let error = errorMessage {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.md)
            }

            Spacer()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = downloadedURL {
                ShareSheet(items: [url])
            }
        }
    }

    private func exportOption(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DS.Font.title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isDownloading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.card))
            .padding(.horizontal, DS.Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
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
            errorMessage = "İndirme başarısız oldu. Tekrar deneyin."
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
