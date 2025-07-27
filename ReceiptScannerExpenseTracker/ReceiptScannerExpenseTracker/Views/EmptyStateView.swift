import SwiftUI

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(title: String, message: String, systemImage: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(AppTheme.primaryColor.opacity(0.7))
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if let actionTitle = actionTitle, let action = action, !actionTitle.isEmpty {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(AppTheme.primaryColor)
                        .cornerRadius(10)
                }
                .padding(.top, 8)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    EmptyStateView(
        title: "No Expenses Yet",
        message: "Start by scanning your receipts to track your expenses.",
        systemImage: "doc.text.magnifyingglass",
        actionTitle: "Scan Receipt",
        action: {}
    )
}