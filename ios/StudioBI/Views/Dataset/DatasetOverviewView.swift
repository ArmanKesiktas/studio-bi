import SwiftUI
import Charts

// MARK: - Dataset Overview (premium summary screen)

struct DatasetOverviewView: View {
    @ObservedObject var datasetVM: DatasetViewModel
    @ObservedObject var dashboardVM: DashboardViewModel

    var body: some View {
        Group {
            if datasetVM.isLoadingDataset {
                SkeletonLoadingView()
            } else if let error = datasetVM.errorMessage, datasetVM.dataset == nil {
                PremiumErrorView(message: error) {
                    datasetVM.forceReload()
                }
            } else if let dataset = datasetVM.dataset {
                overviewContent(dataset)
            }
        }
    }

    private func overviewContent(_ dataset: DatasetResponse) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 1. AI Insight card
                aiInsightCard(dataset.aiSummary)

                // 2. KPI strip
                if let dash = dashboardVM.dashboard, !dash.kpiCards.isEmpty {
                    kpiStrip(dash.kpiCards)
                }

                // 3. Top chart preview
                if let dash = dashboardVM.dashboard,
                   let chart = dash.charts.sorted(by: { $0.sortOrder < $1.sortOrder }).first {
                    chartPreview(chart)
                }

                // 4. Insight cards
                insightCards(dataset)

                // 5. Column summary (compact)
                columnSummary(dataset)
            }
            .padding(.vertical, DS.Spacing.md)
        }
    }

    // MARK: - AI Insight Card

    private func aiInsightCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.accent)
                Text("AI Analizi")
                    .font(DS.Font.captionBold)
                    .foregroundStyle(DS.Colors.accent)
            }

            Text(summary)
                .font(DS.Font.body)
                .foregroundStyle(.primary)
                .lineSpacing(3)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(DS.Colors.accentSoft)
        )
        .padding(.horizontal, DS.Spacing.md)
    }

    // MARK: - KPI Strip

    private func kpiStrip(_ cards: [KPICard]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(cards) { card in
                    KPICardView(card: card)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
        }
    }

    // MARK: - Chart Preview

    private func chartPreview(_ chart: ChartConfig) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(chart.title)
                .font(DS.Font.title)
                .padding(.horizontal, DS.Spacing.md)

            ChartCardView(chart: chart, isFullScreen: false)
                .frame(height: 200)
                .padding(.horizontal, DS.Spacing.md)

            if !chart.aiExplanation.isEmpty {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                    Text(chart.aiExplanation)
                        .font(DS.Font.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.md)
                .lineLimit(2)
            }
        }
    }

    // MARK: - Insight Cards

    private func insightCards(_ dataset: DatasetResponse) -> some View {
        let insights = generateInsights(dataset)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if !insights.isEmpty {
                Text("İçgörüler")
                    .font(DS.Font.title)
                    .padding(.horizontal, DS.Spacing.md)

                ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { _, insight in
                    InsightCardView(insight: insight)
                }
            }
        }
    }

    // MARK: - Column Summary

    private func columnSummary(_ dataset: DatasetResponse) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Sütunlar (\(dataset.columns.count))")
                .font(DS.Font.title)
                .padding(.horizontal, DS.Spacing.md)

            // Grouped by type
            let grouped = Dictionary(grouping: dataset.columns) { $0.colType }
            let order = ["METRIC", "DIMENSION", "DATE", "IDENTIFIER", "FREE_TEXT"]

            ForEach(order, id: \.self) { type in
                if let cols = grouped[type] {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: DS.columnTypeIcon(type))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(DS.columnTypeColor(type))
                            Text(DS.humanColumnType(type))
                                .font(DS.Font.captionBold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)

                        ForEach(cols) { col in
                            CompactColumnRow(column: col)
                        }
                    }
                    .padding(.bottom, DS.Spacing.xs)
                }
            }
        }
    }
}

// MARK: - Insight Generation

struct InsightItem {
    let icon: String
    let color: Color
    let title: String
    let body: String
}

private func generateInsights(_ dataset: DatasetResponse) -> [InsightItem] {
    var result: [InsightItem] = []

    let highNullCols = dataset.columns.filter { $0.nullPercent > 20 }
    if !highNullCols.isEmpty {
        let names = highNullCols.prefix(2).map { $0.name }.joined(separator: ", ")
        result.append(InsightItem(icon: "exclamationmark.triangle.fill", color: .orange,
            title: "Veri Kalitesi", body: "\(highNullCols.count) sütunda yüksek boş değer: \(names)"))
    }

    if dataset.duplicateRowCount > 0 {
        result.append(InsightItem(icon: "doc.on.doc.fill", color: .red,
            title: "Yinelenen Satırlar",
            body: "\(dataset.duplicateRowCount) yinelenen satır (%\(String(format: "%.1f", dataset.duplicateRowPercent)))"))
    }

    let kpiCols = dataset.columns.filter { $0.isKpiCandidate }
    if !kpiCols.isEmpty {
        result.append(InsightItem(icon: "chart.line.uptrend.xyaxis", color: .green,
            title: "Önerilen Metrikler",
            body: kpiCols.prefix(3).map { $0.name }.joined(separator: ", ")))
    }

    if let dateCol = dataset.columns.first(where: { $0.colType == "DATE" }),
       let dMin = dateCol.dateMin, let dMax = dateCol.dateMax {
        result.append(InsightItem(icon: "calendar", color: .blue,
            title: "Zaman Aralığı", body: "\(dateCol.name): \(dMin) – \(dMax)"))
    }

    return result
}

// MARK: - Insight Card

struct InsightCardView: View {
    let insight: InsightItem

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.sm) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(insight.color)
                .frame(width: 4)

            Image(systemName: insight.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(insight.color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(DS.Font.captionBold)
                Text(insight.body)
                    .font(DS.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .padding(.horizontal, DS.Spacing.md)
    }
}

// MARK: - Compact Column Row

struct CompactColumnRow: View {
    let column: ColumnProfileResponse
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Text(column.name)
                        .font(DS.Font.captionBold)
                        .foregroundStyle(.primary)

                    Spacer()

                    if column.nullPercent > 0 {
                        Text("\(Int(column.nullPercent))% boş")
                            .font(DS.Font.micro)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1), in: Capsule())
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if let min = column.minValue, let max = column.maxValue {
                        detailRow("Aralık", "\(formatNum(min)) – \(formatNum(max))")
                    }
                    if let mean = column.meanValue {
                        detailRow("Ortalama", formatNum(mean))
                    }
                    detailRow("Benzersiz", "\(column.uniqueCount)")
                    if !column.topValues.isEmpty {
                        detailRow("En Sık", column.topValues.prefix(3).map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.small))
        .padding(.horizontal, DS.Spacing.md)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(DS.Font.micro)
                .foregroundStyle(.tertiary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatNum(_ v: Double) -> String {
        if v == v.rounded() && abs(v) < 1_000_000 { return String(Int(v)) }
        if abs(v) >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if abs(v) >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        return String(format: "%.2f", v)
    }
}

// MARK: - Skeleton Loading

struct SkeletonLoadingView: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // AI summary skeleton
            skeletonRect(height: 100)

            // KPI skeleton
            HStack(spacing: DS.Spacing.sm) {
                skeletonRect(height: DS.Size.kpiHeight)
                skeletonRect(height: DS.Size.kpiHeight)
                skeletonRect(height: DS.Size.kpiHeight)
            }
            .padding(.horizontal, DS.Spacing.md)

            // Chart skeleton
            skeletonRect(height: 200)

            Spacer()
        }
        .padding(.top, DS.Spacing.md)
        .onAppear { shimmer = true }
    }

    private func skeletonRect(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: DS.Radius.medium)
            .fill(DS.Colors.muted)
            .frame(height: height)
            .padding(.horizontal, DS.Spacing.md)
            .opacity(shimmer ? 0.4 : 0.8)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: shimmer)
    }
}

// MARK: - Premium Error View

struct PremiumErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DS.Size.iconLarge))
                .foregroundStyle(.orange)
            Text("Bir sorun oluştu")
                .font(DS.Font.headline)
            Text(message)
                .font(DS.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Button("Tekrar Dene", action: retry)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.buttonHeight)
                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
    }
}
