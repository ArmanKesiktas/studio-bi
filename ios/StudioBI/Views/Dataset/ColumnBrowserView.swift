import SwiftUI

// MARK: - Column-First Browser (replaces spreadsheet table)

struct ColumnBrowserView: View {
    let datasetId: String
    @ObservedObject var datasetVM: DatasetViewModel
    @State private var selectedColumnIndex = 0
    @State private var showColumnPicker = false

    var body: some View {
        Group {
            if datasetVM.isLoadingDataset && datasetVM.tablePage == nil {
                SkeletonLoadingView()
            } else if let page = datasetVM.tablePage {
                columnContent(page)
            } else if let error = datasetVM.errorMessage {
                PremiumErrorView(message: error) {
                    datasetVM.forceReload()
                }
            }
        }
    }

    private func columnContent(_ page: TablePageResponse) -> some View {
        VStack(spacing: 0) {
            // Column selector pill
            columnSelector(page)

            // Column header info
            if selectedColumnIndex < page.columns.count {
                columnHeader(page, columnName: page.columns[selectedColumnIndex])
            }

            // Column data list
            columnList(page)

            // Pagination
            paginationBar(page)
        }
    }

    // MARK: - Column Selector

    private func columnSelector(_ page: TablePageResponse) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(page.columns.enumerated()), id: \.offset) { idx, col in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColumnIndex = idx
                        }
                    } label: {
                        Text(col)
                            .font(DS.Font.captionBold)
                            .foregroundStyle(idx == selectedColumnIndex ? .white : .primary)
                            .padding(.horizontal, DS.Spacing.md)
                            .frame(height: DS.Size.pillHeight)
                            .background(
                                idx == selectedColumnIndex
                                    ? AnyShapeStyle(DS.Colors.accent)
                                    : AnyShapeStyle(DS.Colors.surface),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    // MARK: - Column Header Info

    private func columnHeader(_ page: TablePageResponse, columnName: String) -> some View {
        let dataset = datasetVM.dataset
        let colProfile = dataset?.columns.first(where: { $0.name == columnName })

        return HStack(spacing: DS.Spacing.sm) {
            if let profile = colProfile {
                Image(systemName: DS.columnTypeIcon(profile.colType))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DS.columnTypeColor(profile.colType))

                Text(DS.humanColumnType(profile.colType))
                    .font(DS.Font.caption)
                    .foregroundStyle(.secondary)

                if let min = profile.minValue, let max = profile.maxValue {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(formatCompact(min)) – \(formatCompact(max))")
                        .font(DS.Font.mono)
                        .foregroundStyle(.secondary)
                }

                if profile.nullPercent > 0 {
                    Spacer()
                    Text("\(Int(profile.nullPercent))% boş")
                        .font(DS.Font.micro)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1), in: Capsule())
                }
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface)
    }

    // MARK: - Column Data List

    private func columnList(_ page: TablePageResponse) -> some View {
        let colIdx = min(selectedColumnIndex, page.columns.count - 1)

        return ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(page.rows.enumerated()), id: \.offset) { rowIdx, row in
                    if colIdx < row.count {
                        HStack {
                            Text("#\(((page.page - 1) * page.pageSize) + rowIdx + 1)")
                                .font(DS.Font.mono)
                                .foregroundStyle(.tertiary)
                                .frame(width: 44, alignment: .trailing)

                            Text(row[colIdx].displayString)
                                .font(DS.Font.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Spacer()
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .frame(minHeight: DS.Size.rowHeight)
                        .background(
                            rowIdx % 2 == 0
                                ? Color.clear
                                : DS.Colors.muted.opacity(0.5)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Pagination

    private func paginationBar(_ page: TablePageResponse) -> some View {
        HStack {
            Button {
                Task { await datasetVM.loadPrevPage(datasetId: datasetId) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(page.page <= 1 || datasetVM.isLoadingTable)

            Spacer()

            if datasetVM.isLoadingTable {
                ProgressView().scaleEffect(0.8)
            } else {
                Text("\(page.page) / \(page.totalPages)")
                    .font(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await datasetVM.loadNextPage(datasetId: datasetId) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .disabled(page.page >= page.totalPages || datasetVM.isLoadingTable)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        .background(.regularMaterial)
    }

    private func formatCompact(_ v: Double) -> String {
        if abs(v) >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if abs(v) >= 1_000 { return String(format: "%.1fK", v / 1_000) }
        if v == v.rounded() { return String(Int(v)) }
        return String(format: "%.1f", v)
    }
}
