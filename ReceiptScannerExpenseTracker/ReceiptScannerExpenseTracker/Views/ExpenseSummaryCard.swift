import SwiftUI

struct ExpenseSummaryCard: View {
    let summaryData: SummaryData
    let color: Color
    
    // Legacy initializer for backward compatibility
    init(title: String, amount: String, trend: Double, color: Color) {
        let decimalAmount = Decimal(string: amount.replacingOccurrences(of: ",", with: "")) ?? 0
        let trendData = TrendData(
            previousAmount: decimalAmount * (1 - Decimal(trend / 100)),
            currentAmount: decimalAmount
        )
        
        self.summaryData = SummaryData(
            title: title,
            amount: decimalAmount,
            trend: trendData
        )
        self.color = color
    }
    
    // New initializer using SummaryData
    init(summaryData: SummaryData, color: Color = AppTheme.primaryColor) {
        self.summaryData = summaryData
        self.color = color
    }
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text(summaryData.title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(summaryData.formattedAmount)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                if let trend = summaryData.trend {
                    HStack {
                        Image(systemName: trend.direction.iconName)
                            .font(.caption)
                            .foregroundColor(trend.direction.color)
                        
                        Text("\(abs(trend.changePercentage * 100), specifier: "%.1f")%")
                            .font(.caption)
                            .foregroundColor(trend.direction.color)
                        
                        Text("vs previous")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Placeholder for consistent height when no trend data
                    HStack {
                        Text(" ")
                            .font(.caption)
                        Spacer()
                    }
                }
                
                Rectangle()
                    .fill(color)
                    .frame(height: 4)
                    .cornerRadius(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }
    
    private var accessibilityDescription: String {
        var description = "\(summaryData.title): \(summaryData.formattedAmount)"
        
        if let trend = summaryData.trend {
            let trendDescription = trend.direction == .increasing ? "increased" : 
                                 trend.direction == .decreasing ? "decreased" : "remained stable"
            let percentageValue = abs(trend.changePercentage * 100)
            description += ", \(trendDescription) by \(String(format: "%.1f", percentageValue))% from previous period"
        }
        
        return description
    }
}

#Preview {
    VStack(spacing: 16) {
        HStack {
            // Using legacy initializer
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
        
        HStack {
            // Using new SummaryData initializer
            ExpenseSummaryCard(
                summaryData: SummaryData(
                    title: "This Week",
                    amount: 287.25,
                    trend: TrendData(previousAmount: 320.00, currentAmount: 287.25)
                ),
                color: AppTheme.primaryColor
            )
            
            ExpenseSummaryCard(
                summaryData: SummaryData(
                    title: "Daily Average",
                    amount: 42.15
                ),
                color: AppTheme.secondaryColor
            )
        }
    }
    .padding()
    .previewLayout(.sizeThatFits)
}