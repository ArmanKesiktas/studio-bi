import Foundation

@MainActor
final class AppStateManager: ObservableObject {
    @Published var activeDatasetId: String?
    @Published var selectedTab: Int = 0
    @Published var recentDatasets: [UploadResponse] = []

    private let defaults = UserDefaults.standard
    private let recentKey = "recentDatasets"
    private let activeKey = "activeDatasetId"
    private let tabKey = "selectedTab"

    init() {
        load()
    }

    func setActive(_ dataset: UploadResponse) {
        activeDatasetId = dataset.datasetId
        addToRecent(dataset)
        save()
    }

    func clearActive() {
        activeDatasetId = nil
        selectedTab = 0
        save()
    }

    func removeRecent(_ dataset: UploadResponse) {
        recentDatasets.removeAll { $0.datasetId == dataset.datasetId }
        save()
    }

    func openRecent(_ dataset: UploadResponse) {
        activeDatasetId = dataset.datasetId
        selectedTab = 0
        save()
    }

    private func addToRecent(_ dataset: UploadResponse) {
        recentDatasets.removeAll { $0.datasetId == dataset.datasetId }
        recentDatasets.insert(dataset, at: 0)
        if recentDatasets.count > 10 {
            recentDatasets = Array(recentDatasets.prefix(10))
        }
    }

    private func load() {
        if let id = defaults.string(forKey: activeKey), !id.isEmpty {
            activeDatasetId = id
        }
        selectedTab = defaults.integer(forKey: tabKey)

        if let data = defaults.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([UploadResponse].self, from: data) {
            recentDatasets = decoded
        }
    }

    private func save() {
        defaults.set(activeDatasetId ?? "", forKey: activeKey)
        defaults.set(selectedTab, forKey: tabKey)

        if let encoded = try? JSONEncoder().encode(recentDatasets) {
            defaults.set(encoded, forKey: recentKey)
        }
    }
}
