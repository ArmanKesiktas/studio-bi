import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var dashboard: DashboardResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let defaults = UserDefaults.standard

    func load(datasetId: String) async {
        guard dashboard == nil else { return }

        // 1. Load from cache instantly
        if let cached = loadCache(datasetId) {
            dashboard = cached
        }

        // 2. Fetch from API in background
        let showSpinner = dashboard == nil
        if showSpinner { isLoading = true }
        errorMessage = nil

        do {
            let fresh = try await APIClient.shared.getDashboard(datasetId)
            dashboard = fresh
            saveCache(fresh, datasetId: datasetId)
        } catch {
            if dashboard == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func reload(datasetId: String) async {
        dashboard = nil
        clearCache(datasetId)
        await load(datasetId: datasetId)
    }

    // MARK: - Cache

    private func cacheKey(_ datasetId: String) -> String { "dashboardCache_\(datasetId)" }

    private func saveCache(_ dashboard: DashboardResponse, datasetId: String) {
        if let data = try? JSONEncoder().encode(dashboard) {
            defaults.set(data, forKey: cacheKey(datasetId))
        }
    }

    private func loadCache(_ datasetId: String) -> DashboardResponse? {
        guard let data = defaults.data(forKey: cacheKey(datasetId)) else { return nil }
        return try? JSONDecoder().decode(DashboardResponse.self, from: data)
    }

    private func clearCache(_ datasetId: String) {
        defaults.removeObject(forKey: cacheKey(datasetId))
    }
}
