import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class UploadViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var uploadedDataset: UploadResponse?
    @Published var showFilePicker = false

    let supportedTypes: [UTType] = [
        UTType(filenameExtension: "csv") ?? .data,
        UTType(filenameExtension: "xlsx") ?? .data,
        UTType(filenameExtension: "xls") ?? .data,
        UTType(filenameExtension: "json") ?? .json,
    ]

    func upload(fileURL: URL) async {
        isLoading = true
        uploadProgress = 0
        errorMessage = nil

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        do {
            let response = try await APIClient.shared.upload(fileURL: fileURL) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.uploadProgress = progress
                }
            }
            uploadedDataset = response
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
