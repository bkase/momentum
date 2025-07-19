import SwiftUI

struct ProgressIndicatorView: View {
    let completed: Int
    let total: Int

    var body: some View {
        Text("\(completed) of \(total) completed")
            .font(.progressIndicator)
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.canvasBackground)
                    .overlay(
                        Capsule()
                            .stroke(Color.borderNeutral, lineWidth: 1)
                    )
            )
    }
}
