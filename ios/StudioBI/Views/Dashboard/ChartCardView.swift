import SwiftUI
import Charts

struct ChartCardView: View {
    let chart: ChartConfig
    var isFullScreen: Bool = false

    var body: some View {
        chartBody
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) {
                    AxisValueLabel()
                        .font(.system(size: 11))
                }
            }
            .chartYAxis {
                AxisMarks {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    AxisValueLabel()
                        .font(.system(size: 11))
                }
            }
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
            .interpolationMethod(.catmullRom)
            .foregroundStyle(DS.Colors.accent)
            .lineStyle(StrokeStyle(lineWidth: 2))

            AreaMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [DS.Colors.accent.opacity(0.15), DS.Colors.accent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            PointMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(DS.Colors.accent)
            .symbolSize(isFullScreen ? 30 : 20)
        }
    }

    private var barChart: some View {
        Chart(chart.data) { point in
            BarMark(
                x: .value("X", point.xString),
                y: .value("Y", point.yDouble)
            )
            .foregroundStyle(DS.Colors.accent.gradient)
            .cornerRadius(DS.Radius.small, style: .continuous)
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
            .cornerRadius(DS.Radius.xs)
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: DS.Spacing.sm)
    }
}

// Tiny extension for cornerRadius value
private extension DS.Radius {
    static let xs: CGFloat = 4
}
