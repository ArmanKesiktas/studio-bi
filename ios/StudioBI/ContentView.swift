import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        if let datasetId = appState.activeDatasetId {
            DatasetWorkspaceView(datasetId: datasetId)
        } else {
            UploadView()
        }
    }
}

// MARK: - Dataset Workspace (replaces 5-tab layout)

struct DatasetWorkspaceView: View {
    let datasetId: String
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var datasetVM = DatasetViewModel()
    @StateObject private var dashboardVM = DashboardViewModel()
    @State private var selectedSegment = 0
    @State private var showChat = false
    @State private var showExport = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // Segmented control
                    Picker("", selection: $selectedSegment) {
                        Text("Özet").tag(0)
                        Text("Keşfet").tag(1)
                        Text("Dashboard").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)

                    // Content
                    TabView(selection: $selectedSegment) {
                        DatasetOverviewView(datasetVM: datasetVM, dashboardVM: dashboardVM)
                            .tag(0)
                        ColumnBrowserView(datasetId: datasetId, datasetVM: datasetVM)
                            .tag(1)
                        DashboardView(datasetId: datasetId, vm: dashboardVM)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut(duration: 0.25), value: selectedSegment)
                }

                // AI FAB
                Button {
                    showChat = true
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: DS.Size.fabSize, height: DS.Size.fabSize)
                        .background(DS.Colors.accent, in: Circle())
                        .shadow(color: DS.Colors.accent.opacity(0.35), radius: 12, y: 6)
                }
                .padding(.trailing, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .navigationTitle(datasetVM.dataset?.filename ?? "Veri Seti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appState.clearActive()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Ana Sayfa")
                            .font(DS.Font.caption)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExport = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .task {
                await datasetVM.load(datasetId: datasetId)
                await dashboardVM.load(datasetId: datasetId)
            }
            .sheet(isPresented: $showChat) {
                AIChatSheet(datasetId: datasetId, segment: selectedSegment)
                    .presentationDetents([.fraction(0.65), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExport) {
                ExportSheet(datasetId: datasetId)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
