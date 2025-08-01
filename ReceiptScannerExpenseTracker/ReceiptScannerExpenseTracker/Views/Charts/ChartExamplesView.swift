import SwiftUI

/// Example view demonstrating the type-safe chart components
struct ChartExamplesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Type-safe expense chart example
                expenseChartExample
                
                // Type-safe budget chart example
                budgetChartExample
                
                // Type-safe trend chart example
                trendChartExample
                
                // Flexible chart example for backward compatibility
                flexibleChartExample
            }
            .padding()
        }
        .navigationTitle("Chart Examples")
    }
    
    // MARK: - Type-Safe Examples
    
    private var expenseChartExample: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Expense Chart (Type-Safe)")
                .font(.headline)
            
            BarChartView(data: sampleExpenseData.map { ChartDataPoint(label: $0.label, value: $0.value, color: $0.color, flexibleMetadata: ["transactionCount": $0.metadata?.transactionCount ?? 0 as AnyHashable, "averageAmount": $0.metadata?.averageAmount ?? 0 as AnyHashable, "percentage": $0.metadata?.percentage ?? 0 as AnyHashable, "categoryId": $0.metadata?.categoryId?.uuidString ?? "" as AnyHashable, "dateRange": $0.metadata?.dateRange?.description ?? "" as AnyHashable]) })
                .frame(height: 250)
        }
    }
    
    private var budgetChartExample: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Budget Chart (Type-Safe)")
                .font(.headline)
            
            PieChartView(data: sampleBudgetData.map { ChartDataPoint(label: $0.label, value: $0.value, color: $0.color, flexibleMetadata: ["budgetLimit": $0.metadata?.budgetLimit ?? 0 as AnyHashable, "remainingBudget": $0.metadata?.remainingBudget ?? 0 as AnyHashable, "percentageUsed": $0.metadata?.percentageUsed ?? 0 as AnyHashable, "period": $0.metadata?.period ?? "" as AnyHashable, "isOverBudget": $0.metadata?.isOverBudget ?? false as AnyHashable]) })
                .frame(height: 250)
        }
    }
    
    private var trendChartExample: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trend Chart (Type-Safe)")
                .font(.headline)
            
                        BarChartView(data: sampleTrendData.map { ChartDataPoint(label: $0.label, value: $0.value, color: $0.color, flexibleMetadata: ["previousValue": $0.metadata?.previousValue as AnyHashable? ?? 0 as AnyHashable, "changeAmount": $0.metadata?.changeAmount as AnyHashable? ?? 0 as AnyHashable, "changePercentage": $0.metadata?.changePercentage as AnyHashable? ?? 0 as AnyHashable, "trendDirection": $0.metadata?.trendDirection as AnyHashable? ?? "" as AnyHashable, "isSignificantChange": $0.metadata?.isSignificantChange as AnyHashable? ?? false as AnyHashable]) })
                .frame(height: 250)
        }
    }
    
    private var flexibleChartExample: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Flexible Chart (Backward Compatible)")
                .font(.headline)
            
            BarChartView(data: sampleFlexibleData)
                .frame(height: 250)
        }
    }
    
    // MARK: - Sample Data
    
    private var sampleExpenseData: [ExpenseChartDataPoint] {
        [
            ExpenseChartDataPoint(
                label: "Food",
                value: 450.0,
                color: .blue,
                metadata: ExpenseChartMetadata(
                    transactionCount: 15,
                    averageAmount: Decimal(30.0),
                    percentage: 0.35,
                    categoryId: UUID()
                )
            ),
            ExpenseChartDataPoint(
                label: "Transport",
                value: 320.0,
                color: .green,
                metadata: ExpenseChartMetadata(
                    transactionCount: 8,
                    averageAmount: Decimal(40.0),
                    percentage: 0.25,
                    categoryId: UUID()
                )
            ),
            ExpenseChartDataPoint(
                label: "Shopping",
                value: 280.0,
                color: .orange,
                metadata: ExpenseChartMetadata(
                    transactionCount: 12,
                    averageAmount: Decimal(23.33),
                    percentage: 0.22,
                    categoryId: UUID()
                )
            )
        ]
    }
    
    private var sampleBudgetData: [BudgetChartDataPoint] {
        [
            BudgetChartDataPoint(
                label: "Food Budget",
                value: 350.0,
                color: .green,
                metadata: BudgetChartMetadata(
                    budgetLimit: Decimal(500.0),
                    remainingBudget: Decimal(150.0),
                    percentageUsed: 0.7,
                    period: "month"
                )
            ),
            BudgetChartDataPoint(
                label: "Transport Budget",
                value: 450.0,
                color: .red,
                metadata: BudgetChartMetadata(
                    budgetLimit: Decimal(400.0),
                    remainingBudget: Decimal(-50.0),
                    percentageUsed: 1.125,
                    period: "month",
                    isOverBudget: true
                )
            )
        ]
    }
    
    private var sampleTrendData: [TrendChartDataPoint] {
        [
            TrendChartDataPoint(
                label: "This Month",
                value: 1200.0,
                color: .blue,
                metadata: TrendChartMetadata(
                    previousValue: 1000.0,
                    changeAmount: 200.0,
                    changePercentage: 0.2,
                    trendDirection: "increasing",
                    isSignificantChange: true
                )
            ),
            TrendChartDataPoint(
                label: "Last Month",
                value: 1000.0,
                color: .gray,
                metadata: TrendChartMetadata(
                    previousValue: 950.0,
                    changeAmount: 50.0,
                    changePercentage: 0.053,
                    trendDirection: "stable",
                    isSignificantChange: false
                )
            )
        ]
    }
    
    private var sampleFlexibleData: [FlexibleChartDataPoint] {
        [
            FlexibleChartDataPoint(
                label: "Mixed Data",
                value: 100.0,
                color: .purple,
                flexibleMetadata: [
                    "customField": "Custom Value",
                    "numericField": 42,
                    "booleanField": true
                ]
            )
        ]
    }
}

// MARK: - Preview
#Preview {
    NavigationView {
        ChartExamplesView()
    }
}