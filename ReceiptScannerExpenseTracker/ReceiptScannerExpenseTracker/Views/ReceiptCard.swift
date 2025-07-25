import SwiftUI

struct ReceiptCard: View {
    let merchantName: String
    let date: Date
    let amount: String
    let imageURL: URL?
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            CardView {
                HStack(spacing: 12) {
                    // Receipt thumbnail or placeholder
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        if imageURL != nil {
                            // In a real app, you'd use AsyncImage or similar to load the image
                            Image(systemName: "doc.text.image")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        } else {
                            Image(systemName: "receipt")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Receipt details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(merchantName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(dateFormatter.string(from: date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Amount
                    Text("$\(amount)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                }
                .padding(.vertical, 8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        ReceiptCard(
            merchantName: "Grocery Store",
            date: Date(),
            amount: "56.78",
            imageURL: nil,
            onTap: {}
        )
        
        ReceiptCard(
            merchantName: "Coffee Shop",
            date: Date().addingTimeInterval(-86400),
            amount: "4.50",
            imageURL: nil,
            onTap: {}
        )
    }
    .padding()
    .previewLayout(.sizeThatFits)
}