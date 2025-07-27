import SwiftUI

struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: retryAction) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .padding()
                .background(AppTheme.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.backgroundColor)
    }
}

#Preview {
    ErrorView(
        title: "Error Loading Expenses",
        message: "There was a problem loading your expenses. Please try again.",
        retryAction: {}
    )
}