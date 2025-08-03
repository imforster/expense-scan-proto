import Foundation
import SwiftUI

/// Utility class for transforming expense data into chart-compatible formats
struct ChartDataTransformers {
    
    // MARK: - Category Spending Transformations
    
    /// Transforms category spending data into type-safe chart data points
    static func transformCategorySpending(_ categorySpending: [CategorySpending]) -> [ExpenseChartDataPoint] {
        let colors = ChartColorScheme.category.colors(for: categorySpending.count)
        
        return categorySpending.enumerated().map { index, spending in
            let color = index < colors.count ? colors[index] : .gray
            let metadata = ExpenseChartMetadata(
                transactionCount: spending.transactionCount,
                averageAmount: spending.averageAmount,
                percentage: spending.percentage,
                categoryId: spending.category.id
            )
            
            return ExpenseChartDataPoint(
                label: spending.category.name,
                value: Double(truncating: spending.amount as NSNumber),
                color: color,
                metadata: metadata
            )
        }
    }
    
    /// Legacy method for backward compatibility with flexible metadata
    static func transformCategorySpendingFlexible(_ categorySpending: [CategorySpending]) -> [FlexibleChartDataPoint] {
        let colors = ChartColorScheme.category.colors(for: categorySpending.count)
        
        return categorySpending.enumerated().map { index, spending in
            let color = index < colors.count ? colors[index] : .gray
            
            return FlexibleChartDataPoint(
                label: spending.category.name,
                value: Double(truncating: spending.amount as NSNumber),
                color: color,
                flexibleMetadata: [
                    "transactionCount": spending.transactionCount,
                    "averageAmount": spending.averageAmount,
                    "percentage": spending.percentage,
                    "categoryId": spending.category.id
                ]
            )
        }
    }
    
    /// Transforms vendor spending data into chart data points
    static func transformVendorSpending(_ vendorSpending: [VendorSpending]) -> [FlexibleChartDataPoint] {
        let colors = ChartColorScheme.automatic.colors(for: vendorSpending.count)
        
        return vendorSpending.enumerated().map { index, spending in
            let color = index < colors.count ? colors[index] : .gray
            
            return FlexibleChartDataPoint(
                label: spending.vendorName,
                value: Double(truncating: spending.amount as NSNumber),
                color: color,
                flexibleMetadata: [
                    "transactionCount": spending.transactionCount,
                    "averageAmount": spending.averageAmount,
                    "lastTransactionDate": spending.lastTransactionDate
                ]
            )
        }
    }
    
    // MARK: - Time Series Transformations
    
    /// Transforms daily spending data into time series data points
    static func transformDailySpending(_ dailySpending: [DailySpending]) -> [TimeSeriesDataPoint] {
        return dailySpending.map { daily in
            TimeSeriesDataPoint(
                date: daily.date,
                value: Double(truncating: daily.amount as NSNumber),
                label: daily.transactionCount > 0 ? "\(daily.transactionCount) transactions" : "No transactions"
            )
        }
    }
    
    /// Transforms spending trends into time series data points
    static func transformSpendingTrends(_ trends: SpendingTrends) -> [TimeSeriesDataPoint] {
        let currentData = transformDailySpending(trends.currentPeriodSummary.dailySpending)
        let previousData = transformDailySpending(trends.previousPeriodSummary.dailySpending)
        
        // Combine current and previous data for comparison
        var combinedData: [TimeSeriesDataPoint] = []
        
        // Add previous period data with adjusted dates for comparison
        let calendar = Calendar.current
        let daysDifference = calendar.dateComponents([.day], 
            from: trends.previousPeriodSummary.dateInterval.start, 
            to: trends.currentPeriodSummary.dateInterval.start).day ?? 0
        
        for point in previousData {
            if let adjustedDate = calendar.date(byAdding: .day, value: daysDifference, to: point.date) {
                combinedData.append(TimeSeriesDataPoint(
                    date: adjustedDate,
                    value: point.value,
                    label: "Previous: \(point.label ?? "")"
                ))
            }
        }
        
        // Add current period data
        combinedData.append(contentsOf: currentData)
        
        return combinedData.sorted { $0.date < $1.date }
    }
    
    // MARK: - Budget Data Transformations
    
    /// Transforms budget status data into chart data points
    /// Note: BudgetStatus type will be implemented in future tasks
    static func transformBudgetStatusPlaceholder(_ budgetData: [(name: String, current: Double, limit: Double, percentage: Float)]) -> [FlexibleChartDataPoint] {
        return budgetData.map { data in
            let color = getBudgetStatusColor(for: data.percentage)
            
            return FlexibleChartDataPoint(
                label: data.name,
                value: data.current,
                color: color,
                flexibleMetadata: [
                    "budgetLimit": data.limit,
                    "remainingBudget": data.limit - data.current,
                    "percentageUsed": data.percentage
                ]
            )
        }
    }
    
    // MARK: - Comparison Data Transformations
    
    /// Transforms period comparison into comparative chart data
    /// Note: PeriodComparison type will be implemented in future tasks
    static func transformPeriodComparisonPlaceholder(current: SpendingSummary, previous: SpendingSummary) -> [FlexibleChartDataPoint] {
        return [
            FlexibleChartDataPoint(
                label: "Current Period",
                value: Double(truncating: current.totalAmount as NSNumber),
                color: .blue,
                flexibleMetadata: [
                    "period": current.period.displayName,
                    "transactionCount": current.transactionCount,
                    "averageTransaction": current.averageTransaction
                ]
            ),
            FlexibleChartDataPoint(
                label: "Previous Period",
                value: Double(truncating: previous.totalAmount as NSNumber),
                color: .gray,
                flexibleMetadata: [
                    "period": previous.period.displayName,
                    "transactionCount": previous.transactionCount,
                    "averageTransaction": previous.averageTransaction
                ]
            )
        ]
    }
    
    /// Transforms category changes into chart data points
    /// Note: CategoryChange type will be implemented in future tasks
    static func transformCategoryChangesPlaceholder(_ changes: [(category: CategoryData, currentAmount: Double, previousAmount: Double, changePercentage: Double)]) -> [FlexibleChartDataPoint] {
        return changes.map { change in
            let color = getCategoryChangeColor(for: change.changePercentage)
            
            return FlexibleChartDataPoint(
                label: change.category.name,
                value: abs(change.currentAmount - change.previousAmount),
                color: color,
                flexibleMetadata: [
                    "currentAmount": change.currentAmount,
                    "previousAmount": change.previousAmount,
                    "changeAmount": change.currentAmount - change.previousAmount,
                    "changePercentage": change.changePercentage
                ]
            )
        }
    }
    
    // MARK: - Helper Methods
    
    /// Gets appropriate color for budget status based on usage percentage
    private static func getBudgetStatusColor(for percentageUsed: Float) -> Color {
        switch percentageUsed {
        case 0..<0.5:
            return .green
        case 0.5..<0.8:
            return .yellow
        case 0.8..<1.0:
            return .orange
        default:
            return .red
        }
    }
    
    /// Gets appropriate color for category changes based on change percentage
    private static func getCategoryChangeColor(for changePercentage: Double) -> Color {
        switch changePercentage {
        case ..<(-0.2):
            return .green  // Significant decrease
        case (-0.2)..<(-0.05):
            return .mint   // Moderate decrease
        case (-0.05)...0.05:
            return .gray   // Stable
        case 0.05..<0.2:
            return .orange // Moderate increase
        default:
            return .red    // Significant increase
        }
    }
    
    // MARK: - Data Aggregation Helpers
    
    /// Aggregates spending data by time period
    static func aggregateSpendingByPeriod(
        _ dailySpending: [DailySpending],
        period: AggregationPeriod
    ) -> [TimeSeriesDataPoint] {
        let calendar = Calendar.current
        var aggregatedData: [Date: Double] = [:]
        
        for daily in dailySpending {
            let periodStart: Date
            
            switch period {
            case .daily:
                periodStart = calendar.startOfDay(for: daily.date)
            case .weekly:
                periodStart = calendar.dateInterval(of: .weekOfYear, for: daily.date)?.start ?? daily.date
            case .monthly:
                periodStart = calendar.dateInterval(of: .month, for: daily.date)?.start ?? daily.date
            }
            
            aggregatedData[periodStart, default: 0] += Double(truncating: daily.amount as NSNumber)
        }
        
        return aggregatedData.map { date, amount in
            TimeSeriesDataPoint(date: date, value: amount)
        }.sorted { $0.date < $1.date }
    }
    
    /// Filters chart data points based on criteria
    static func filterChartData(
        _ data: [FlexibleChartDataPoint],
        minValue: Double? = nil,
        maxValue: Double? = nil,
        topN: Int? = nil
    ) -> [FlexibleChartDataPoint] {
        var filteredData = data
        
        // Apply value filters
        if let minValue = minValue {
            filteredData = filteredData.filter { $0.value >= minValue }
        }
        
        if let maxValue = maxValue {
            filteredData = filteredData.filter { $0.value <= maxValue }
        }
        
        // Apply top N filter
        if let topN = topN {
            filteredData = Array(filteredData.sorted { $0.value > $1.value }.prefix(topN))
        }
        
        return filteredData
    }
    
    /// Normalizes chart data values to a specific range
    static func normalizeChartData(_ data: [FlexibleChartDataPoint], to range: ClosedRange<Double>) -> [FlexibleChartDataPoint] {
        guard !data.isEmpty else { return data }
        
        let values = data.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let valueRange = maxValue - minValue
        
        guard valueRange > 0 else { return data }
        
        let targetRange = range.upperBound - range.lowerBound
        
        return data.map { dataPoint in
            let normalizedValue = ((dataPoint.value - minValue) / valueRange) * targetRange + range.lowerBound
            
            return FlexibleChartDataPoint(
                label: dataPoint.label,
                value: normalizedValue,
                color: dataPoint.color,
                flexibleMetadata: dataPoint.metadata
            )
        }
    }
}

// MARK: - Supporting Types

/// Aggregation period for time series data
enum AggregationPeriod {
    case daily
    case weekly
    case monthly
}