import SwiftUI

/// Comprehensive demo showing all chart components working together
struct ComprehensiveChartDemo: View {
    @State private var selectedChartType: ChartType = .bar
    @State private var selectedTimeRange: TimeRange = .month
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Chart type selector
                    chartTypeSelector
                    
                    // Time range selector
                    timeRangeSelector
                    
                    // Main chart display
                    mainChartView
                    
                    // Chart insights
                    chartInsightsView
                    
                    // Additional examples
                    additionalExamplesView
                }
                .padding()
            }
            .navigationTitle("Chart Components Demo")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Chart Type Selector
    private var chartTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chart Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            Picker("Chart Type", selection: $selectedChartType) {
                ForEach(ChartType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Time Range Selector
    private var timeRangeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Range")
                .font(.headline)
                .fontWeight(.semibold)
            
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.displayName).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Main Chart View
    private var mainChartView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chartTitle)
                .font(.title2)
                .fontWeight(.semibold)
            
            Group {
                switch selectedChartType {
                case .bar:
                    BarChartView(
                        data: categoryData,
                        configuration: chartConfiguration
                    )
                    .frame(height: 300)
                    
                case .pie:
                    PieChartView(
                        data: categoryData,
                        configuration: chartConfiguration
                    )
                    .frame(height: 350)
                    
                case .line:
                    LineChartView(
                        data: timeSeriesData,
                        configuration: chartConfiguration
                    )
                    .frame(height: 300)
                    
                case .trend:
                    SpendingTrendView(
                        data: timeSeriesData,
                        configuration: chartConfiguration,
                        trendMetadata: trendMetadata
                    )
                    .frame(height: 400)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .shadow(radius: 2)
            )
        }
    }
    
    // MARK: - Chart Insights
    private var chartInsightsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Chart Insights")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                insightCard(
                    title: "Total Spending",
                    value: formatCurrency(totalSpending),
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
                
                insightCard(
                    title: "Top Category",
                    value: topCategory,
                    icon: "chart.pie.fill",
                    color: .green
                )
                
                insightCard(
                    title: "Transactions",
                    value: "\(totalTransactions)",
                    icon: "list.bullet",
                    color: .orange
                )
                
                insightCard(
                    title: "Average",
                    value: formatCurrency(averageTransaction),
                    icon: "chart.bar.fill",
                    color: .purple
                )
            }
        }
    }
    
    // MARK: - Additional Examples
    private var additionalExamplesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Additional Chart Examples")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Small charts grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                // Mini bar chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weekly Spending")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    BarChartView(
                        data: weeklyData,
                        configuration: ChartConfiguration(
                            showLabels: false,
                            showValues: false,
                            showLegend: false,
                            animationDuration: 0.5
                        )
                    )
                    .frame(height: 120)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
                
                // Mini pie chart
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Split")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    PieChartView(
                        data: Array(categoryData.prefix(3)),
                        configuration: ChartConfiguration(
                            showLabels: false,
                            showValues: false,
                            showLegend: false,
                            animationDuration: 0.5
                        )
                    )
                    .frame(height: 120)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemBackground))
                )
            }
        }
    }
    
    // MARK: - Helper Views
    private func insightCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
    
    // MARK: - Computed Properties
    
    private var chartTitle: String {
        switch selectedChartType {
        case .bar:
            return "Spending by Category"
        case .pie:
            return "Spending Distribution"
        case .line:
            return "Daily Spending Trend"
        case .trend:
            return "Comprehensive Spending Analysis"
        }
    }
    
    private var chartConfiguration: ChartConfiguration {
        ChartConfiguration(
            showLabels: true,
            showValues: true,
            showLegend: selectedChartType != .line,
            animationDuration: 0.8,
            interactionEnabled: true,
            colorScheme: .category
        )
    }
    
    private var totalSpending: Double {
        categoryData.reduce(0) { $0 + $1.value }
    }
    
    private var topCategory: String {
        categoryData.max { $0.value < $1.value }?.label ?? "N/A"
    }
    
    private var totalTransactions: Int {
        categoryData.compactMap { $0.getMetadata(for: "transactionCount", as: Int.self) }
            .reduce(0, +)
    }
    
    private var averageTransaction: Double {
        totalTransactions > 0 ? totalSpending / Double(totalTransactions) : 0
    }
    
    // MARK: - Sample Data
    
    private var categoryData: [FlexibleChartDataPoint] {
        [
            FlexibleChartDataPoint(
                label: "Food & Dining",
                value: 850.0,
                color: .blue,
                flexibleMetadata: [
                    "transactionCount": 25,
                    "averageAmount": 34.0,
                    "percentage": 0.42
                ]
            ),
            FlexibleChartDataPoint(
                label: "Transportation",
                value: 420.0,
                color: .green,
                flexibleMetadata: [
                    "transactionCount": 12,
                    "averageAmount": 35.0,
                    "percentage": 0.21
                ]
            ),
            FlexibleChartDataPoint(
                label: "Shopping",
                value: 380.0,
                color: .orange,
                flexibleMetadata: [
                    "transactionCount": 18,
                    "averageAmount": 21.1,
                    "percentage": 0.19
                ]
            ),
            FlexibleChartDataPoint(
                label: "Entertainment",
                value: 220.0,
                color: .red,
                flexibleMetadata: [
                    "transactionCount": 8,
                    "averageAmount": 27.5,
                    "percentage": 0.11
                ]
            ),
            FlexibleChartDataPoint(
                label: "Health",
                value: 150.0,
                color: .purple,
                flexibleMetadata: [
                    "transactionCount": 5,
                    "averageAmount": 30.0,
                    "percentage": 0.07
                ]
            )
        ]
    }
    
    private var timeSeriesData: [TimeSeriesDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        let daysBack = selectedTimeRange.daysBack
        
        return (0..<daysBack).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let baseValue = 120.0
            let variation = Double.random(in: -60...180)
            let weekendMultiplier = calendar.isDateInWeekend(date) ? 1.3 : 1.0
            let value = max(20, (baseValue + variation) * weekendMultiplier)
            
            return TimeSeriesDataPoint(
                date: date,
                value: value,
                label: "\(Int(value.rounded())) spent"
            )
        }.reversed()
    }
    
    private var weeklyData: [FlexibleChartDataPoint] {
        let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return weekdays.enumerated().map { index, day in
            let value = Double.random(in: 50...200)
            let color: Color = index >= 5 ? .orange : .blue // Weekend different color
            
            return FlexibleChartDataPoint(
                label: day,
                value: value,
                color: color,
                flexibleMetadata: [
                    "dayOfWeek": index,
                    "isWeekend": index >= 5
                ]
            )
        }
    }
    
    private var trendMetadata: TrendChartMetadata {
        TrendChartMetadata(
            previousValue: 2800.0,
            changeAmount: 220.0,
            changePercentage: 0.085,
            trendDirection: "increasing",
            isSignificantChange: true
        )
    }
    
    // MARK: - Helper Methods
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Supporting Types

enum ChartType: CaseIterable {
    case bar
    case pie
    case line
    case trend
    
    var displayName: String {
        switch self {
        case .bar: return "Bar"
        case .pie: return "Pie"
        case .line: return "Line"
        case .trend: return "Trend"
        }
    }
}

enum TimeRange: CaseIterable {
    case week
    case month
    case quarter
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        }
    }
    
    var daysBack: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }
}

// MARK: - Preview
#Preview {
    ComprehensiveChartDemo()
}