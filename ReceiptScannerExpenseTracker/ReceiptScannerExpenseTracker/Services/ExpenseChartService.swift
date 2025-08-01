import Foundation
import CoreData
import SwiftUI

/// Service for converting Core Data expense entities to chart data
class ExpenseChartService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Category Charts
    
    /// Converts Core Data expenses to category spending chart data
    func getCategorySpendingChartData(for dateRange: DateInterval) -> [FlexibleChartDataPoint] {
        let expenses = fetchExpenses(for: dateRange)
        let categoryTotals = calculateCategoryTotals(from: expenses)
        
        return categoryTotals.map { categoryName, data in
            FlexibleChartDataPoint(
                label: categoryName,
                value: data.total,
                color: getColorForCategory(categoryName),
                flexibleMetadata: [
                    "transactionCount": data.count,
                    "averageAmount": data.average,
                    "percentage": data.percentage
                ]
            )
        }
    }
    
    // MARK: - Time Series Charts
    
    /// Converts Core Data expenses to daily spending time series
    func getDailySpendingChartData(for dateRange: DateInterval) -> [TimeSeriesDataPoint] {
        let expenses = fetchExpenses(for: dateRange)
        let dailyTotals = calculateDailyTotals(from: expenses)
        
        return dailyTotals.map { date, amount in
            TimeSeriesDataPoint(
                date: date,
                value: amount,
                label: formatCurrency(amount)
            )
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Private Helpers
    
    private func fetchExpenses(for dateRange: DateInterval) -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            dateRange.start as NSDate,
            dateRange.end as NSDate
        )
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching expenses: \(error)")
            return []
        }
    }
    
    private func calculateCategoryTotals(from expenses: [Expense]) -> [String: (total: Double, count: Int, average: Double, percentage: Double)] {
        let totalAmount = expenses.reduce(0) { $0 + $1.amount.doubleValue }
        var categoryTotals: [String: (total: Double, count: Int)] = [:]
        
        for expense in expenses {
            let categoryName = expense.category?.name ?? "Uncategorized"
            let amount = expense.amount.doubleValue
            
            if let existing = categoryTotals[categoryName] {
                categoryTotals[categoryName] = (
                    total: existing.total + amount,
                    count: existing.count + 1
                )
            } else {
                categoryTotals[categoryName] = (total: amount, count: 1)
            }
        }
        
        return categoryTotals.mapValues { data in
            (
                total: data.total,
                count: data.count,
                average: data.total / Double(data.count),
                percentage: totalAmount > 0 ? data.total / totalAmount : 0
            )
        }
    }
    
    private func calculateDailyTotals(from expenses: [Expense]) -> [Date: Double] {
        let calendar = Calendar.current
        var dailyTotals: [Date: Double] = [:]
        
        for expense in expenses {
            let day = calendar.startOfDay(for: expense.date ?? Date())
            dailyTotals[day, default: 0] += expense.amount.doubleValue
        }
        
        return dailyTotals
    }
    
    private func getColorForCategory(_ categoryName: String) -> Color {
        // Map category names to consistent colors
        switch categoryName.lowercased() {
        case "food", "dining": return .blue
        case "transport", "transportation": return .green
        case "shopping", "retail": return .orange
        case "entertainment": return .red
        case "health", "medical": return .purple
        case "travel": return .pink
        case "utilities": return .yellow
        case "education": return .cyan
        default: return .gray
        }
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}