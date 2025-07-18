import SwiftUI

struct OperationErrorView: View {
    let error: String?
    
    var body: some View {
        if let error = error {
            Text(error)
                .font(.system(size: 12))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .transition(.opacity)
        }
    }
}