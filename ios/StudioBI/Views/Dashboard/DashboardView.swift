import SwiftUI

struct DashboardView: View {
    let datasetId: String
    @StateObject private var vm = DashboardViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                LoadingView(message: "Dashboard oluşturuluyor…")
            } else if let error = vm.errorMessage, vm.dashboard == nil {
                ErrorView(message: error) {
                    Task { await vm.reload(datasetId: datasetId) }
                }
            } else if let dash = vm.dashboard {
                dashboardContent(dash)
            } else {
                ErrorView(message: "Dashboard yüklenemedi.") {
                    Task { await vm.reload(datasetId: datasetId) }
                }
            }
        }
        .task { await vm.load(datasetId: datasetId) }
        .refreshable { await vm.reload(datasetId: datasetId) }
    }

    private func dashboardContent(_ dash: DashboardResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // KPI Cards
                if !dash.kpiCards.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Özet")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(dash.kpiCards) { card in
                                    KPICardView(card: card)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // Charts
                if !dash.charts.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Grafikler")
                            .font(.headline)
                            .padding(.horizontal, 16)

                        ForEach(dash.charts.sorted { $0.sortOrder < $1.sortOrder }) { chart in
                            ChartCardView(chart: chart)
                        }
                    }
                }

                if dash.kpiCards.isEmpty && dash.charts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Bu veri seti için otomatik dashboard oluşturulamadı.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
            .padding(.vertical, 16)
        }
    }
}
