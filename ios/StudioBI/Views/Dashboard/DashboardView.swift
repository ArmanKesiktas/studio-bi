import SwiftUI

// MARK: - Dashboard View (single chart, full-screen, swipe)

struct DashboardView: View {
    let datasetId: String
    @ObservedObject var vm: DashboardViewModel
    @State private var currentChart = 0

    var body: some View {
        Group {
            if vm.isLoading && vm.dashboard == nil {
                SkeletonLoadingView()
            } else if let error = vm.errorMessage, vm.dashboard == nil {
                PremiumErrorView(message: error) {
                    Task { await vm.reload(datasetId: datasetId) }
                }
            } else if let dash = vm.dashboard {
                dashboardContent(dash)
            } else {
                emptyDashboard
            }
        }
        .refreshable { await vm.reload(datasetId: datasetId) }
    }

    private func dashboardContent(_ dash: DashboardResponse) -> some View {
        let sortedCharts = dash.charts.sorted { $0.sortOrder < $1.sortOrder }

        return VStack(spacing: 0) {
            // Pinned KPI strip
            if !dash.kpiCards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(dash.kpiCards) { card in
                            KPICardView(card: card)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .background(.regularMaterial)
            }

            if sortedCharts.isEmpty {
                emptyDashboard
            } else {
                // Full-screen chart swipe
                TabView(selection: $currentChart) {
                    ForEach(Array(sortedCharts.enumerated()), id: \.element.id) { idx, chart in
                        singleChartPage(chart)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
    }

    private func singleChartPage(_ chart: ChartConfig) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Spacer().frame(height: DS.Spacing.sm)

            // Chart title
            Text(chart.title)
                .font(DS.Font.headline)
                .padding(.horizontal, DS.Spacing.md)

            // Full-width chart
            ChartCardView(chart: chart, isFullScreen: true)
                .frame(height: DS.Size.chartHeight)
                .padding(.horizontal, DS.Spacing.md)

            // AI caption
            if !chart.aiExplanation.isEmpty {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(DS.Colors.accent)
                    Text(chart.aiExplanation)
                        .font(DS.Font.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
                .padding(DS.Spacing.md)
                .background(DS.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .padding(.horizontal, DS.Spacing.md)
            }

            // Data preview
            dataPreview(chart)

            Spacer()
        }
    }

    private func dataPreview(_ chart: ChartConfig) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Veri")
                .font(DS.Font.captionBold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.md)

            ForEach(Array(chart.data.prefix(5).enumerated()), id: \.offset) { _, point in
                HStack {
                    Text(point.xString)
                        .font(DS.Font.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(formatValue(point.yDouble))
                        .font(DS.Font.mono)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private var emptyDashboard: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: DS.Size.iconLarge))
                .foregroundStyle(.secondary)
            Text("Dashboard henüz oluşturulamadı")
                .font(DS.Font.title)
            Text("Verinizde yeterli sayısal veya tarihsel sütun bulunamadı.")
                .font(DS.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
    }

    private func formatValue(_ v: Double) -> String {
        if abs(v) >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if abs(v) >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.2f", v)
    }
}
