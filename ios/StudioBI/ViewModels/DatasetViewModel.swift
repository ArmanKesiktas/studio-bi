import SwiftUI

@MainActor
final class DatasetViewModel: ObservableObject {
    @Published var dataset: DatasetResponse?
    @Published var tablePage: TablePageResponse?
    @Published var isLoadingDataset = false
    @Published var isLoadingTable = false
    @Published var errorMessage: String?

    private var currentPage = 1

    func load(datasetId: String) async {
        guard dataset == nil else { return }
        isLoadingDataset = true
        errorMessage = nil
        do {
            dataset = try await APIClient.shared.getDataset(datasetId)
            await loadTable(datasetId: datasetId, page: 1)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingDataset = false
    }

    func loadTable(datasetId: String, page: Int) async {
        isLoadingTable = true
        do {
            tablePage = try await APIClient.shared.getTable(datasetId, page: page, pageSize: 50)
            currentPage = page
        } catch {
            errorMessage = error.localizedDescription
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
}
