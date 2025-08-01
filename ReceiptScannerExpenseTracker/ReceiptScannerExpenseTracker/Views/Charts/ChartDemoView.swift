import SwiftUI

/// Demo view showing working chart examples
struct ChartDemoView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Bar Chart Example
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Monthly Spending by Category")
                            .font(.headline)
                        
                        BarChartView(data: sampleExpenseData)
                            .frame(height: 250)
                    }
                    
                    // Pie Chart Example
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Spending Distribution")
                            .font(.headline)
                        
                        PieChartView(data: sampleExpenseData)
                            .frame(height: 300)
                    }
                    
                    // Line Chart Example
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Daily Spending Trend")
                            .font(.headline)
                        
                        LineChartView(data: sampleTimeSeriesData)
                            .frame(height: 250)
                    }
                }
                .padding()
            }
            .navigationTitle("Chart Examples")
        }
    }
    
    // MARK: - Sample Data
    
    private var sampleExpenseData: [FlexibleChartDataPoint] {
        [
            FlexibleChartDataPoint(
                label: "Food",
                value: 450.0,
                color: .blue,
                flexibleMetadata: [
                    "transactionCount": 15,
                    "averageAmount": 30.0,
                    "percentage": 0.35
                ]
            ),
            FlexibleChartDataPoint(
                label: "Transport",
                value: 320.0,
                color: .green,
                flexibleMetadata: [
                    "transactionCount": 8,
                    "averageAmount": 40.0,
                    "percentage": 0.25
                ]
            ),
            FlexibleChartDataPoint(
                label: "Shopping",
                value: 280.0,
                color: .orange,
                flexibleMetadata: [
                    "transactionCount": 12,
                    "averageAmount": 23.33,
                    "percentage": 0.22
                ]
            ),
            FlexibleChartDataPoint(
                label: "Entertainment",
                value: 150.0,
                color: .red,
                flexibleMetadata: [
                    "transactionCount": 6,
                    "averageAmount": 25.0,
                    "percentage": 0.12
                ]
            ),
            FlexibleChartDataPoint(
                label: "Health",
                value: 80.0,
                color: .purple,
                flexibleMetadata: [
                    "transactionCount": 3,
                    "averageAmount": 26.67,
                    "percentage": 0.06
                ]
            )
        ]
    }
    
    private var sampleTimeSeriesData: [TimeSeriesDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let baseValue = 100.0
            let variation = Double.random(in: -50...150)
            let value = max(0, baseValue + variation)
            
            return TimeSeriesDataPoint(
                date: date,
                value: value,
                label: "Day \(dayOffset + 1)"
            )
        }.reversed()
    }
}

// MARK: - Preview
#Preview {
    ChartDemoView()
}