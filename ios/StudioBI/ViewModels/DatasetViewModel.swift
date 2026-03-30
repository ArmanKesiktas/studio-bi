import SwiftUI

@MainActor
final class DatasetViewModel: ObservableObject {
    @Published var dataset: DatasetResponse?
    @Published var tablePage: TablePageResponse?
    @Published var isLoadingDataset = false
    @Published var isLoadingTable = false
    @Published var errorMessage: String?

    private var currentPage = 1
    private let defaults = UserDefaults.standard

    func load(datasetId: String) async {
        guard dataset == nil else { return }

        // 1. Load from local cache instantly (no loading state)
        if let cached = loadCache(datasetId) {
            dataset = cached
            // Also load cached table page
            if let cachedPage = loadTableCache(datasetId, page: 1) {
                tablePage = cachedPage
                currentPage = 1
            }
        }

        // 2. Fetch from API in background (refresh silently)
        let showSpinner = dataset == nil
        if showSpinner { isLoadingDataset = true }
        errorMessage = nil

        do {
            let fresh = try await APIClient.shared.getDataset(datasetId)
            dataset = fresh
            saveCache(fresh, datasetId: datasetId)
            await loadTable(datasetId: datasetId, page: 1)
        } catch {
            // Only show error if we have no cached data
            if dataset == nil {
                errorMessage = error.localizedDescription
            }
        }

        isLoadingDataset = false
    }

    func loadTable(datasetId: String, page: Int) async {
        isLoadingTable = true
        do {
            let page = try await APIClient.shared.getTable(datasetId, page: page, pageSize: 50)
            tablePage = page
            currentPage = page.page
            saveTableCache(page, datasetId: datasetId)
        } catch {
            if tablePage == nil {
                errorMessage = error.localizedDescription
            }
        }
        isLoadingTable = false
    }

    func loadNextPage(datasetId: String) async {
        guard let tp = tablePage, currentPage < tp.totalPages else { return }
        await loadTable(datasetId: datasetId, page: currentPage + 1)
    }

    func loadPrevPage(datasetId: String) async {
        guard currentPage > 1 else { return }
        await loadTable(datasetId: datasetId, page: currentPage - 1)
    }

    func forceReload() {
        guard let id = dataset?.datasetId ?? tablePage?.datasetId else { return }
        dataset = nil
        tablePage = nil
        Task { await load(datasetId: id) }
    }

    // MARK: - Cache

    private func cacheKey(_ datasetId: String) -> String { "datasetCache_\(datasetId)" }
    private func tableCacheKey(_ datasetId: String, page: Int) -> String { "tableCache_\(datasetId)_p\(page)" }

    private func saveCache(_ dataset: DatasetResponse, datasetId: String) {
        if let data = try? JSONEncoder().encode(dataset) {
            defaults.set(data, forKey: cacheKey(datasetId))
        }
    }

    private func loadCache(_ datasetId: String) -> DatasetResponse? {
        guard let data = defaults.data(forKey: cacheKey(datasetId)) else { return nil }
        return try? JSONDecoder().decode(DatasetResponse.self, from: data)
    }

    private func saveTableCache(_ page: TablePageResponse, datasetId: String) {
        if let data = try? JSONEncoder().encode(page) {
            defaults.set(data, forKey: tableCacheKey(datasetId, page: page.page))
        }
    }

    private func loadTableCache(_ datasetId: String, page: Int) -> TablePageResponse? {
        guard let data = defaults.data(forKey: tableCacheKey(datasetId, page: page)) else { return nil }
        return try? JSONDecoder().decode(TablePageResponse.self, from: data)
    }
}
