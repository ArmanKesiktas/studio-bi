import Foundation

// MARK: - Upload

struct UploadResponse: Codable, Equatable {
    let datasetId: String
    let filename: String
    let fileType: String
    let rowCount: Int
    let colCount: Int
    let aiSummary: String
}

// MARK: - Dataset Detail

struct DatasetResponse: Codable, Identifiable {
    var id: String { datasetId }
    let datasetId: String
    let filename: String
    let fileType: String
    let rowCount: Int
    let colCount: Int
    let duplicateRowCount: Int
    let duplicateRowPercent: Double
    let aiSummary: String
    let columns: [ColumnProfileResponse]
}

struct ColumnProfileResponse: Codable, Identifiable {
    var id: String { name }
    let name: String
    let colType: String
    let dtype: String
    let nullCount: Int
    let nullPercent: Double
    let uniqueCount: Int
    let sampleValues: [AnyCodable]
    let minValue: Double?
    let maxValue: Double?
    let meanValue: Double?
    let medianValue: Double?
    let topValues: [TopValue]
    let dateMin: String?
    let dateMax: String?
    let dateGranularity: String?
    let isKpiCandidate: Bool

    var typeIcon: String {
        switch colType {
        case "DATE": return "calendar"
        case "METRIC": return "number"
        case "DIMENSION": return "tag"
        case "IDENTIFIER": return "key"
        default: return "text.alignleft"
        }
    }

    var typeColor: String {
        switch colType {
        case "DATE": return "blue"
        case "METRIC": return "green"
        case "DIMENSION": return "orange"
        case "IDENTIFIER": return "gray"
        default: return "purple"
        }
    }
}

struct TopValue: Codable {
    let value: String
    let count: Int
}

// MARK: - Table

struct TablePageResponse: Codable {
    let datasetId: String
    let page: Int
    let pageSize: Int
    let totalRows: Int
    let totalPages: Int
    let columns: [String]
    let rows: [[AnyCodable]]
}

// MARK: - AnyCodable helper

struct AnyCodable: Codable {
    let value: Any?

    init(_ value: Any?) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = nil }
        else if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else { value = nil }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case nil: try container.encodeNil()
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        default: try container.encodeNil()
        }
    }

    var displayString: String {
        switch value {
        case nil: return "—"
        case let v as Bool: return v ? "true" : "false"
        case let v as Int: return "\(v)"
        case let v as Double:
            if v == v.rounded() { return String(Int(v)) }
            return String(format: "%.2f", v)
        case let v as String: return v
        default: return "—"
        }
    }
}
