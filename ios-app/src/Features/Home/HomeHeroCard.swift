import SwiftUI

struct HomeHeroCard: View {
    let title: String
    let message: String
    let supportingText: String
    let counterLoadable: HomeCounterLoadable

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(message)
                .font(.title3.weight(.semibold))
            Text(supportingText)
                .font(.body)
                .foregroundStyle(.secondary)
            Text(counterLoadable.displayedCounterText)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 24, y: 12)
        )
    }
}
