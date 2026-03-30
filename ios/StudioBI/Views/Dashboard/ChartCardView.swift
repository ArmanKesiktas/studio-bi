import SwiftUI
import Charts

struct ChartCardView: View {
    let chart: ChartConfig
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(chart.title)
                        .font(.subheadline.bold())
                    Text(chart.yColumn + " · " + chart.aggregation.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: chartIcon)
                    .foregroundStyle(.blue.opacity(0.7))
            }

            // Chart
            chartBody
                .frame(height: expanded ? 260 : 180)
                .animation(.easeInOut(duration: 0.25), value: expanded)

            // AI explanation
            if !chart.aiExplanation.isEmpty {
                Label(chart.aiExplanation, systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Expand toggle
            Button {
                withAnimation { expanded.toggle() }
            } label: {
                Text(expanded ? "Küçült" : "Büyüt")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var chartBody: some View {
        switch chart.chartType {
        case "line": lineChart
        case "bar":  barChart
        case "pie":  pieChart
        default:     barChart
        }
    }

    private var lineChart: some View {
        Chart(chart.data) { point in
            LineMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(.blue)
            AreaMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(.blue.opacity(0.1))
            PointMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(.blue)
            .symbolSize(30)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) {
                AxisValueLabel().font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { AxisValueLabel().font(.caption2) }
        }
    }

    private var barChart: some View {
        Chart(chart.data) { point in
            BarMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(.blue.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks { AxisValueLabel().font(.caption2) }
        }
    }

    private var pieChart: some View {
        Chart(chart.data) { point in
            SectorMark(
                angle: .value("Value", point.yDouble),
                innerRadius: .ratio(0.55),
                angularInset: 2
            )
            .foregroundStyle(by: .value("Label", point.xString))
            .cornerRadius(4)
        }
        .chartLegend(position: .bottom, alignment: .center)
    }

    private var chartIcon: String {
        switch chart.chartType {
        case "line": return "chart.line.uptrend.xyaxis"
        case "bar":  return "chart.bar.fill"
        case "pie":  return "chart.pie.fill"
        default:     return "chart.bar"
        }
    }
}
