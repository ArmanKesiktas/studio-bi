import SwiftUI

struct KPICardView: View {
    let card: KPICard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(card.formattedValue)
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(card.aggregation.uppercased())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(width: 130, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.blue.opacity(0.15), lineWidth: 1)
        )
    }
}
