import SwiftUI

struct HomePrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(red: 0.12, green: 0.38, blue: 0.84))
    }
}
