import SwiftUI

struct DurationPicker: View {
    @Binding var timeInput: String
    let onChange: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Estimated duration")
                .font(.durationLabel)
                .foregroundStyle(Color.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                TextField("30", text: $timeInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .frame(width: 44, height: 28)
                    .padding(.horizontal, 8)
                    .background(Color.white)
                    .cornerRadius(3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.accentGold, lineWidth: 1)
                    )
                    .onChange(of: timeInput) { _, newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            timeInput = filtered
                        }
                        onChange(filtered)
                    }

                Text("min")
                    .font(.durationLabel)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(3)
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.borderNeutral, lineWidth: 1)
        )
    }
}
