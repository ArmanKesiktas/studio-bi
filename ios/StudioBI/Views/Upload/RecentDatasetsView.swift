import SwiftUI

struct RecentDatasetsSection: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Son Datasetler")
                .font(.headline)
                .padding(.horizontal)

            ForEach(appState.recentDatasets, id: \.datasetId) { dataset in
                RecentDatasetRow(dataset: dataset)
            }
        }
        .padding(.vertical)
    }
}

private struct RecentDatasetRow: View {
    @EnvironmentObject var appState: AppStateManager
    let dataset: UploadResponse

    var body: some View {
        Button {
            appState.openRecent(dataset)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: dataset.fileType == "xlsx" ? "tablecells.fill" : "tablecells")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(dataset.filename)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(dataset.rowCount) satır · \(dataset.colCount) kolon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                appState.removeRecent(dataset)
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }
}
