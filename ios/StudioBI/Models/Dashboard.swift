import Foundation

struct DashboardResponse: Codable {
    let datasetId: String
    let kpiCards: [KPICard]
    let charts: [ChartConfig]
}

struct KPICard: Codable, Identifiable {
    var id: String { label }
    let label: String
    let valueColumn: String
    let aggregation: String
    let computedValue: AnyCodable
    let formattedValue: String
}

struct ChartConfig: Codable, Identifiable {
    let chartId: String
    var id: String { chartId }
    let chartType: String   // "line" | "bar" | "pie"
    let title: String
    let xColumn: String
    let yColumn: String
    let aggregation: String
    let sortOrder: Int
    let aiExplanation: String
    let data: [ChartDataPoint]
}

struct ChartDataPoint: Codable, Identifiable {
    let id: String
    // line / bar
    let x: AnyCodable?
    let y: AnyCodable?
    // pie
    let label: String?
    let value: AnyCodable?

    enum CodingKeys: String, CodingKey {
        case x, y, label, value
    }

    init(from decoder: Decoder) throws {
        self.id = UUID().uuidString
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decodeIfPresent(AnyCodable.self, forKey: .x)
        y = try container.decodeIfPresent(AnyCodable.self, forKey: .y)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        value = try container.decodeIfPresent(AnyCodable.self, forKey: .value)
    }

    var xString: String { x?.displayString ?? label ?? "" }
    var yDouble: Double {
        if let v = y?.value as? Double { return v }
        if let v = y?.value as? Int { return Double(v) }
        if let v = value?.value as? Double { return v }
        if let v = value?.value as? Int { return Double(v) }
        return 0
    }
}
