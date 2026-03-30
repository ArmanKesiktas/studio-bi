import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var uploadedDataset: UploadResponse?
    @Published var showFilePicker = false

    let supportedTypes: [UTType] = [
        UTType(filenameExtension: "csv") ?? .data,
        UTType(filenameExtension: "xlsx") ?? .data,
        UTType(filenameExtension: "xls") ?? .data,
    ]

    func upload(fileURL: URL) async {
        isLoading = true
        errorMessage = nil

        // Start security-scoped access for Files app URLs
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        do {
            let response = try await APIClient.shared.upload(fileURL: fileURL)
            uploadedDataset = response
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
