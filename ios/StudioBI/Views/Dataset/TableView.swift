import SwiftUI

struct TableView: View {
    let datasetId: String
    @StateObject private var vm = DatasetViewModel()

    var body: some View {
        Group {
            if vm.isLoadingDataset && vm.tablePage == nil {
                LoadingView(message: "Tablo yükleniyor…")
            } else if let error = vm.errorMessage, vm.tablePage == nil {
                ErrorView(message: error) {
                    Task { await vm.load(datasetId: datasetId) }
                }
            } else if let page = vm.tablePage {
                VStack(spacing: 0) {
                    tableGrid(page: page)
                    pagination(page: page)
                }
            }
        }
        .task { await vm.load(datasetId: datasetId) }
    }

    private func columnWidth(for col: String, in page: TablePageResponse) -> CGFloat {
        let colIdx = page.columns.firstIndex(of: col) ?? 0
        let headerLen = col.count
        let maxCellLen = page.rows.prefix(20).compactMap { row in
            row.indices.contains(colIdx) ? row[colIdx].displayString.count : nil
        }.max() ?? 0
        let chars = max(headerLen, maxCellLen)
        return CGFloat(min(max(chars, 8) * 9, 220))
    }

    private func tableGrid(page: TablePageResponse) -> some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    ForEach(page.columns, id: \.self) { col in
                        Text(col)
                            .font(.caption.bold())
                            .lineLimit(2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(width: columnWidth(for: col, in: page), alignment: .leading)
                            .background(Color(.systemGroupedBackground))
                        Divider()
                    }
                }
                Divider()

                // Data rows
                ForEach(Array(page.rows.enumerated()), id: \.offset) { rowIdx, row in
                    HStack(spacing: 0) {
                        ForEach(Array(zip(page.columns, row)), id: \.0) { col, cell in
                            Text(cell.displayString)
                                .font(.caption)
                                .lineLimit(2)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(width: columnWidth(for: col, in: page), alignment: .leading)
                                .background(rowIdx % 2 == 0 ? Color.clear : Color(.systemFill).opacity(0.4))
                            Divider()
                        }
                    }
                    Divider()
                }
            }
        }
    }

    private func pagination(page: TablePageResponse) -> some View {
        HStack {
            Button {
                Task { await vm.loadPrevPage(datasetId: datasetId) }
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(page.page <= 1 || vm.isLoadingTable)

            Spacer()

            if vm.isLoadingTable {
                ProgressView()
            } else {
                Text("Sayfa \(page.page) / \(page.totalPages)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task { await vm.loadNextPage(datasetId: datasetId) }
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(page.page >= page.totalPages || vm.isLoadingTable)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}
