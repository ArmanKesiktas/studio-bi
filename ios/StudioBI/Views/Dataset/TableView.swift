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

    private func tableGrid(page: TablePageResponse) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                // Header
                GridRow {
                    ForEach(page.columns, id: \.self) { col in
                        Text(col)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minWidth: 100, alignment: .leading)
                            .background(Color(.systemGroupedBackground))
                        Divider()
                    }
                }
                Divider()

                // Rows
                ForEach(Array(page.rows.enumerated()), id: \.offset) { rowIdx, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIdx, cell in
                            Text(cell.displayString)
                                .font(.caption)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .frame(minWidth: 100, alignment: .leading)
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
