import SwiftUI

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(DS.Font.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: DS.Size.iconLarge))
                .foregroundStyle(.orange)
            Text("Bir sorun oluştu")
                .font(DS.Font.headline)
            Text(message)
                .font(DS.Font.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)
            Button("Tekrar Dene", action: retry)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: DS.Size.buttonHeight)
                .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.xl)
            Spacer()
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 13, weight: .medium))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(DS.Font.captionBold)
                Text(label)
                    .font(DS.Font.micro)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Colors.surface, in: RoundedRectangle(cornerRadius: DS.Radius.small))
    }
}
