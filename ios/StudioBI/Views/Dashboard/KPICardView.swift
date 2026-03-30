import SwiftUI

struct KPICardView: View {
    let card: KPICard

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(card.label)
                .font(DS.Font.micro)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(card.formattedValue)
                .font(DS.Font.monoLarge)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(DS.Spacing.sm + DS.Spacing.xs)
        .frame(minWidth: 100, maxWidth: .infinity, minHeight: DS.Size.kpiHeight, alignment: .leading)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
    }
}
