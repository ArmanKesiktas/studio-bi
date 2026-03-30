import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load(datasetId: String) async {
        guard dashboard == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            dashboard = try await APIClient.shared.getDashboard(datasetId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reload(datasetId: String) async {
        dashboard = nil
        await load(datasetId: datasetId)
    }
}
