import SwiftUI

struct ExpenseSummaryCard: View {
    let title: String
    let amount: String
    let trend: Double
    let color: Color
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$\(amount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                HStack {
                    Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(trend >= 0 ? .green : .red)
                    
                    Text("\(abs(trend), specifier: "%.1f")%")
                        .font(.caption)
                        .foregroundColor(trend >= 0 ? .green : .red)
                    
                    Text("vs previous")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Rectangle()
                    .fill(color)
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview {
    HStack {
        ExpenseSummaryCard(
            title: "This Month",
            amount: "1,245.50",
            trend: 5.2,
            color: .blue
        )
        
        ExpenseSummaryCard(
            title: "Last Month",
            amount: "1,183.75",
            trend: -2.8,
            color: .green
        )
    }
    .padding()
    .previewLayout(.sizeThatFits)
}