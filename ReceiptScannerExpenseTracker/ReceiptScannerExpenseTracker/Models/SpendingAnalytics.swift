import Foundation
import SwiftUI
import CoreData

// MARK: - Summary Data Models

/// Data structure for expense summary cards
struct SummaryData: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let amount: Decimal
    let trend: TrendData?
    
    init(title: String, amount: Decimal, trend: TrendData? = nil) {
        self.title = title
        self.amount = amount
        self.trend = trend
    }
}

/// Trend information for summary cards
struct TrendData: Equatable {
    let previousAmount: Decimal
    let changeAmount: Decimal
    let changePercentage: Double
    let direction: SpendingTrendDirection
    let isSignificant: Bool
    
    init(previousAmount: Decimal, currentAmount: Decimal) {
        self.previousAmount = previousAmount
        self.changeAmount = currentAmount - previousAmount
        
        if previousAmount > 0 {
            self.changePercentage = Double(truncating: (changeAmount / previousAmount) as NSNumber)
        } else {
            self.changePercentage = currentAmount > 0 ? 1.0 : 0.0
        }
        
        // Determine trend direction
        if changeAmount > 0.01 {
            self.direction = .increasing
        } else if changeAmount < -0.01 {
            self.direction = .decreasing
        } else {
            self.direction = .stable
        }
        
        // Consider changes > 10% as significant
        self.isSignificant = abs(changePercentage) > 0.1
    }
}

/// Trend direction enumeration for spending analytics
enum SpendingTrendDirection: String, CaseIterable {
    case increasing = "increasing"
    case decreasing = "decreasing"
    case stable = "stable"
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
    
    var color: Color {
        switch self {
        case .increasing: return .red
        case .decreasing: return .green
        case .stable: return .blue
        }
    }
    
    var iconName: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}

// MARK: - Spending Analytics Service

/// Service for calculating spending analytics and summaries
class SpendingAnalyticsService {
    
    /// Calculates current month total spending
    static func calculateCurrentMonthTotal(from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
            return 0
        }
        
        return expenses
            .filter { expense in
                return monthInterval.contains(expense.date ?? Date())
            }
            .reduce(0) { total, expense in
                total + expense.amount.decimalValue
            }
    }
    
    /// Calculates previous month total spending
    static func calculatePreviousMonthTotal(from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: now),
              let monthInterval = calendar.dateInterval(of: .month, for: previousMonth) else {
            return 0
        }
        
        return expenses
            .filter { expense in
                return monthInterval.contains(expense.date ?? Date())
            }
            .reduce(0) { total, expense in
                total + expense.amount.decimalValue
            }
    }
    
    /// Calculates current week total spending
    static func calculateCurrentWeekTotal(from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return 0
        }
        
        return expenses
            .filter { expense in
                return weekInterval.contains(expense.date ?? Date())
            }
            .reduce(0) { total, expense in
                total + expense.amount.decimalValue
            }
    }
    
    /// Calculates average daily spending for current month
    static func calculateAverageDailySpending(from expenses: [Expense]) -> Decimal {
        let calendar = Calendar.current
        let now = Date()
        
        guard calendar.dateInterval(of: .month, for: now) != nil else {
            return 0
        }
        
        let monthTotal = calculateCurrentMonthTotal(from: expenses)
        let daysInMonth = calendar.component(.day, from: now)
        
        return daysInMonth > 0 ? monthTotal / Decimal(daysInMonth) : 0
    }
    
    /// Generates summary data for expense overview
    static func generateSummaryData(from expenses: [Expense]) -> [SummaryData] {
        let currentMonthTotal = calculateCurrentMonthTotal(from: expenses)
        let previousMonthTotal = calculatePreviousMonthTotal(from: expenses)
        let currentWeekTotal = calculateCurrentWeekTotal(from: expenses)
        let averageDaily = calculateAverageDailySpending(from: expenses)
        
        return [
            SummaryData(
                title: "This Month",
                amount: currentMonthTotal,
                trend: TrendData(previousAmount: previousMonthTotal, currentAmount: currentMonthTotal)
            ),
            SummaryData(
                title: "This Week",
                amount: currentWeekTotal,
                trend: nil // Could add previous week comparison later
            ),
            SummaryData(
                title: "Daily Average",
                amount: averageDaily,
                trend: nil // Could add previous month's daily average comparison later
            )
        ]
    }
}

// MARK: - Extensions

extension SummaryData {
    /// Formatted amount string for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: amount as NSNumber) ?? "$0"
    }
    
    /// Formatted trend string for display
    var formattedTrend: String? {
        guard let trend = trend else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        
        let percentageString = formatter.string(from: NSNumber(value: trend.changePercentage)) ?? "0%"
        return "\(percentageString) vs last month"
    }
}

extension TrendData {
    /// Formatted change amount string
    var formattedChangeAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        formatter.positivePrefix = "+"
        
        return formatter.string(from: changeAmount as NSNumber) ?? "$0"
    }
}