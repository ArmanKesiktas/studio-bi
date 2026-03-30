import SwiftUI

struct DatasetSummaryView: View {
    let dataset: DatasetResponse

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // AI Summary card
                summaryCard

                // Stats row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatBadge(label: "Satır", value: "\(dataset.rowCount.formatted())", icon: "list.bullet", color: .blue)
                        StatBadge(label: "Sütun", value: "\(dataset.colCount)", icon: "sidebar.squares.right", color: .green)
                        StatBadge(label: "Yinelenen", value: "\(dataset.duplicateRowCount)", icon: "doc.on.doc", color: dataset.duplicateRowCount > 0 ? .orange : .gray)
                        StatBadge(label: "Dosya", value: dataset.fileType.uppercased(), icon: "doc", color: .purple)
                    }
                    .padding(.horizontal, 16)
                }

                // Insight Cards
                InsightCardsView(dataset: dataset)

                // Columns
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sütunlar (\(dataset.columns.count))")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    ForEach(dataset.columns) { col in
                        ColumnCard(column: col)
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("AI Analizi", systemImage: "sparkles")
                .font(.caption.bold())
                .foregroundStyle(.blue)

            Text(dataset.aiSummary)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }
}

// MARK: - Insight Cards

struct InsightCardsView: View {
    let dataset: DatasetResponse

    struct Insight {
        let icon: String
        let color: Color
        let title: String
        let body: String
    }

    var insights: [Insight] {
        var result: [Insight] = []

        // Veri kalitesi: yüksek null %
        let highNullCols = dataset.columns.filter { $0.nullPercent > 20 }
        if !highNullCols.isEmpty {
            let names = highNullCols.prefix(2).map { $0.name }.joined(separator: ", ")
            result.append(Insight(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                title: "Veri Kalitesi",
                body: "\(highNullCols.count) sütunda yüksek boş değer oranı: \(names)"
            ))
        }

        // Yinelenen satırlar
        if dataset.duplicateRowCount > 0 {
            result.append(Insight(
                icon: "doc.on.doc.fill",
                color: .red,
                title: "Yinelenen Satırlar",
                body: "\(dataset.duplicateRowCount) yinelenen satır tespit edildi (%\(String(format: "%.1f", dataset.duplicateRowPercent)))"
            ))
        }

        // Önerilen metrikler (KPI adayları)
        let kpiCols = dataset.columns.filter { $0.isKpiCandidate }
        if !kpiCols.isEmpty {
            result.append(Insight(
                icon: "chart.line.uptrend.xyaxis",
                color: .green,
                title: "Önerilen Metrikler",
                body: kpiCols.prefix(3).map { $0.name }.joined(separator: ", ")
            ))
        }

        // Zaman aralığı
        if let dateCol = dataset.columns.first(where: { $0.colType == "DATE" }),
           let dMin = dateCol.dateMin, let dMax = dateCol.dateMax {
            result.append(Insight(
                icon: "calendar",
                color: .blue,
                title: "Zaman Aralığı",
                body: "\(dateCol.name): \(dMin) – \(dMax)"
            ))
        }

        // Veri iyi görünüyorsa pozitif mesaj
        if result.isEmpty {
            result.append(Insight(
                icon: "checkmark.seal.fill",
                color: .green,
                title: "Veri Sağlıklı",
                body: "\(dataset.rowCount.formatted()) satır, \(dataset.colCount) sütun — belirgin bir sorun tespit edilmedi."
            ))
        }

        return Array(result.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hızlı İçgörüler")
                .font(.headline)
                .padding(.horizontal, 16)

            ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(insight.color)
                        .frame(width: 32, height: 32)
                        .background(insight.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(insight.title)
                            .font(.subheadline.weight(.semibold))
                        Text(insight.body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Column Card

struct ColumnCard: View {
    let column: ColumnProfileResponse
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.25)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: column.typeIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(typeColor)
                        .frame(width: 28, height: 28)
                        .background(typeColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(column.name)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text(column.colType)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if column.nullPercent > 0 {
                        Text("\(Int(column.nullPercent))% null")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 14)
                columnDetail
                    .padding(14)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var columnDetail: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Benzersiz Değer", "\(column.uniqueCount)")
            detailRow("Boş Değer", "\(column.nullCount) (\(String(format: "%.1f", column.nullPercent))%)")

            if let min = column.minValue, let max = column.maxValue {
                detailRow("Min / Max", "\(formatNum(min)) / \(formatNum(max))")
            }
            if let mean = column.meanValue {
                detailRow("Ortalama", formatNum(mean))
            }
            if let dMin = column.dateMin, let dMax = column.dateMax {
                detailRow("Tarih Aralığı", "\(dMin) → \(dMax)")
            }
            if !column.topValues.isEmpty {
                detailRow("En Sık Değerler", column.topValues.prefix(3).map { "\($0.value) (\($0.count))" }.joined(separator: ", "))
            }
            if !column.sampleValues.isEmpty {
                detailRow("Örnekler", column.sampleValues.prefix(3).map { $0.displayString }.joined(separator: ", "))
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func formatNum(_ v: Double) -> String {
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.2f", v)
    }

    private var typeColor: Color {
        switch column.colType {
        case "DATE": return .blue
        case "METRIC": return .green
        case "DIMENSION": return .orange
        case "IDENTIFIER": return .gray
        default: return .purple
        }
    }
}
