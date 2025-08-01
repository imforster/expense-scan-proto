import Foundation
import SwiftUI

// MARK: - Chart Data Models

/// Generic data point for charts with type-safe metadata
struct ChartDataPoint<Metadata>: Identifiable, Equatable where Metadata: Equatable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    let metadata: Metadata?
    
    init(label: String, value: Double, color: Color, metadata: Metadata? = nil) {
        self.label = label
        self.value = value
        self.color = color
        self.metadata = metadata
    }
    
    static func == (lhs: ChartDataPoint<Metadata>, rhs: ChartDataPoint<Metadata>) -> Bool {
        return lhs.id == rhs.id && lhs.metadata == rhs.metadata
    }
}

/// Type alias for backward compatibility with flexible metadata
typealias FlexibleChartDataPoint = ChartDataPoint<[String: AnyHashable]>

/// Convenience initializer for flexible metadata
extension ChartDataPoint where Metadata == [String: AnyHashable] {
    init(label: String, value: Double, color: Color, flexibleMetadata: [String: Any]? = nil) {
        let convertedMetadata = flexibleMetadata?.compactMapValues { value in
            if let hashableValue = value as? AnyHashable {
                return hashableValue
            } else {
                return String(describing: value)
            }
        }
        
        self.init(
            label: label,
            value: value,
            color: color,
            metadata: convertedMetadata
        )
    }
}

/// Time series data point for line charts
struct TimeSeriesDataPoint: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
    let label: String?
    
    init(date: Date, value: Double, label: String? = nil) {
        self.date = date
        self.value = value
        self.label = label
    }
    
    
}

/// Chart configuration options
struct ChartConfiguration {
    let showLabels: Bool
    let showValues: Bool
    let showLegend: Bool
    let animationDuration: Double
    let interactionEnabled: Bool
    let colorScheme: ChartColorScheme
    
    init(
        showLabels: Bool = true,
        showValues: Bool = true,
        showLegend: Bool = true,
        animationDuration: Double = 0.8,
        interactionEnabled: Bool = true,
        colorScheme: ChartColorScheme = .automatic
    ) {
        self.showLabels = showLabels
        self.showValues = showValues
        self.showLegend = showLegend
        self.animationDuration = animationDuration
        self.interactionEnabled = interactionEnabled
        self.colorScheme = colorScheme
    }
}

/// Color scheme options for charts
enum ChartColorScheme {
    case automatic
    case category
    case monochromatic(Color)
    case custom([Color])
    
    func colors(for count: Int) -> [Color] {
        switch self {
        case .automatic:
            return defaultColors(count: count)
        case .category:
            return categoryColors(count: count)
        case .monochromatic(let baseColor):
            return monochromaticColors(baseColor: baseColor, count: count)
        case .custom(let colors):
            return Array(colors.prefix(count))
        }
    }
    
    private func defaultColors(count: Int) -> [Color] {
        let baseColors: [Color] = [
            .blue, .green, .orange, .red, .purple, .pink, .yellow, .cyan, .mint, .indigo
        ]
        return Array(baseColors.prefix(count))
    }
    
    private func categoryColors(count: Int) -> [Color] {
        let categoryColors: [Color] = [
            Color(red: 0.2, green: 0.6, blue: 1.0),    // Food - Blue
            Color(red: 0.3, green: 0.8, blue: 0.3),    // Transportation - Green
            Color(red: 1.0, green: 0.6, blue: 0.2),    // Shopping - Orange
            Color(red: 0.9, green: 0.3, blue: 0.3),    // Entertainment - Red
            Color(red: 0.6, green: 0.4, blue: 0.9),    // Health - Purple
            Color(red: 0.9, green: 0.5, blue: 0.7),    // Travel - Pink
            Color(red: 0.8, green: 0.8, blue: 0.2),    // Utilities - Yellow
            Color(red: 0.4, green: 0.8, blue: 0.8),    // Education - Cyan
        ]
        return Array(categoryColors.prefix(count))
    }
    
    private func monochromaticColors(baseColor: Color, count: Int) -> [Color] {
        var colors: [Color] = []
        for i in 0..<count {
            let opacity = 1.0 - (Double(i) * 0.15)
            colors.append(baseColor.opacity(max(0.3, opacity)))
        }
        return colors
    }
}

/// Chart interaction state with generic support
struct ChartInteractionState<Metadata> where Metadata: Equatable {
    var selectedDataPoint: ChartDataPoint<Metadata>?
    var hoveredDataPoint: ChartDataPoint<Metadata>?
    var isInteracting: Bool = false
    
    mutating func selectDataPoint(_ dataPoint: ChartDataPoint<Metadata>?) {
        selectedDataPoint = dataPoint
        isInteracting = dataPoint != nil
    }
    
    mutating func hoverDataPoint(_ dataPoint: ChartDataPoint<Metadata>?) {
        hoveredDataPoint = dataPoint
    }
    
    mutating func clearInteraction() {
        selectedDataPoint = nil
        hoveredDataPoint = nil
        isInteracting = false
    }
}

/// Type alias for flexible interaction state
typealias FlexibleChartInteractionState = ChartInteractionState<[String: AnyHashable]>

// MARK: - Specific Metadata Types

/// Metadata for expense-related chart data points
struct ExpenseChartMetadata: Equatable, Hashable {
    let transactionCount: Int
    let averageAmount: Decimal
    let percentage: Double?
    let categoryId: UUID?
    let dateRange: DateInterval?
    
    init(
        transactionCount: Int = 0,
        averageAmount: Decimal = 0,
        percentage: Double? = nil,
        categoryId: UUID? = nil,
        dateRange: DateInterval? = nil
    ) {
        self.transactionCount = transactionCount
        self.averageAmount = averageAmount
        self.percentage = percentage
        self.categoryId = categoryId
        self.dateRange = dateRange
    }
}

/// Metadata for budget-related chart data points
struct BudgetChartMetadata: Equatable, Hashable {
    let budgetLimit: Decimal
    let remainingBudget: Decimal
    let percentageUsed: Float
    let period: String // Using String instead of TimePeriod to avoid conflicts
    let isOverBudget: Bool
    
    init(
        budgetLimit: Decimal,
        remainingBudget: Decimal,
        percentageUsed: Float,
        period: String,
        isOverBudget: Bool = false
    ) {
        self.budgetLimit = budgetLimit
        self.remainingBudget = remainingBudget
        self.percentageUsed = percentageUsed
        self.period = period
        self.isOverBudget = isOverBudget
    }
}

/// Metadata for trend analysis chart data points
struct TrendChartMetadata: Equatable, Hashable {
    let previousValue: Double?
    let changeAmount: Double?
    let changePercentage: Double?
    let trendDirection: String // Using String instead of TrendDirection to avoid conflicts
    let isSignificantChange: Bool
    
    init(
        previousValue: Double? = nil,
        changeAmount: Double? = nil,
        changePercentage: Double? = nil,
        trendDirection: String = "stable",
        isSignificantChange: Bool = false
    ) {
        self.previousValue = previousValue
        self.changeAmount = changeAmount
        self.changePercentage = changePercentage
        self.trendDirection = trendDirection
        self.isSignificantChange = isSignificantChange
    }
}

// MARK: - Supporting Enums (imported from ChartDataTypes)

// MARK: - Type Aliases for Common Use Cases

/// Type alias for expense-related chart data points
typealias ExpenseChartDataPoint = ChartDataPoint<ExpenseChartMetadata>

/// Type alias for budget-related chart data points
typealias BudgetChartDataPoint = ChartDataPoint<BudgetChartMetadata>

/// Type alias for trend analysis chart data points
typealias TrendChartDataPoint = ChartDataPoint<TrendChartMetadata>

// MARK: - Extensions

extension ChartDataPoint where Metadata == [String: AnyHashable] {
    /// Gets metadata value for a specific key (for backward compatibility)
    func getMetadata<T>(for key: String, as type: T.Type) -> T? {
        guard let metadataDict = metadata else { return nil }
        return metadataDict[key] as? T
    }
}

extension ChartDataPoint {
    /// Creates a formatted description of the data point
    var formattedDescription: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        let valueString = formatter.string(from: NSNumber(value: value)) ?? "$0"
        return "\(label): \(valueString)"
    }
}

extension TimeSeriesDataPoint {
    /// Creates a formatted description of the time series point
    var formattedDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        let dateString = dateFormatter.string(from: date)
        
        let valueFormatter = NumberFormatter()
        valueFormatter.numberStyle = .currency
        let valueString = valueFormatter.string(from: NSNumber(value: value)) ?? "$0"
        
        return "\(dateString): \(valueString)"
    }
}