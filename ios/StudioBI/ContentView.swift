import SwiftUI

struct ContentView: View {
    @State private var activeDatasetId: String?
    @State private var selectedTab = 0

    var body: some View {
        if let datasetId = activeDatasetId {
            datasetTabs(datasetId: datasetId)
        } else {
            UploadView(uploadedDatasetId: $activeDatasetId)
        }
    }

    private func datasetTabs(datasetId: String) -> some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                DatasetDetailView(datasetId: datasetId)
                    .navigationTitle("Veri Seti")
                    .toolbar { newDatasetButton }
            }
            .tabItem { Label("Özet", systemImage: "doc.text.magnifyingglass") }
            .tag(0)

            NavigationStack {
                TableView(datasetId: datasetId)
                    .navigationTitle("Tablo")
                    .toolbar { newDatasetButton }
            }
            .tabItem { Label("Tablo", systemImage: "tablecells") }
            .tag(1)

            NavigationStack {
                DashboardView(datasetId: datasetId)
                    .navigationTitle("Dashboard")
                    .toolbar { newDatasetButton }
            }
            .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }
            .tag(2)

            NavigationStack {
                ChatView(datasetId: datasetId)
                    .navigationTitle("AI Sohbet")
                    .toolbar { newDatasetButton }
            }
            .tabItem { Label("Sohbet", systemImage: "bubble.left.and.bubble.right") }
            .tag(3)

            NavigationStack {
                ExportView(datasetId: datasetId)
                    .navigationTitle("Dışa Aktar")
                    .toolbar { newDatasetButton }
            }
            .tabItem { Label("Aktar", systemImage: "square.and.arrow.up") }
            .tag(4)
        }
    }

    private var newDatasetButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeDatasetId = nil
                selectedTab = 0
            } label: {
                Image(systemName: "plus.circle")
            }
        }
    }
}

// Wrapper that loads dataset detail
struct DatasetDetailView: View {
    let datasetId: String
    @StateObject private var vm = DatasetViewModel()

    var body: some View {
        Group {
            if vm.isLoadingDataset {
                LoadingView(message: "Analiz yükleniyor…")
            } else if let error = vm.errorMessage, vm.dataset == nil {
                ErrorView(message: error) {
                    Task { await vm.load(datasetId: datasetId) }
                }
            } else if let dataset = vm.dataset {
                DatasetSummaryView(dataset: dataset)
            } else {
                ErrorView(message: "Veri seti yüklenemedi.") {
                    Task { await vm.load(datasetId: datasetId) }
                }
            }
        }
        .task { await vm.load(datasetId: datasetId) }
    }
}
