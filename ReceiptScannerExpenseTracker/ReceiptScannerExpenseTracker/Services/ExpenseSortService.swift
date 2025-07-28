import Foundation
import CoreData

class ExpenseSortService {
    
    enum SortOption: String, CaseIterable {
        case dateAscending = "Date (Oldest First)"
        case dateDescending = "Date (Newest First)"
        case amountAscending = "Amount (Low to High)"
        case amountDescending = "Amount (High to Low)"
        case merchantAscending = "Merchant (A-Z)"
        case merchantDescending = "Merchant (Z-A)"
        case categoryAscending = "Category (A-Z)"
        case categoryDescending = "Category (Z-A)"
        case paymentMethodAscending = "Payment Method (A-Z)"
        case paymentMethodDescending = "Payment Method (Z-A)"
        case recurringFirst = "Recurring First"
        case nonRecurringFirst = "Non-Recurring First"
        
        var iconName: String {
            switch self {
            case .dateAscending, .dateDescending:
                return "calendar"
            case .amountAscending, .amountDescending:
                return "dollarsign.circle"
            case .merchantAscending, .merchantDescending:
                return "storefront"
            case .categoryAscending, .categoryDescending:
                return "tag"
            case .paymentMethodAscending, .paymentMethodDescending:
                return "creditcard"
            case .recurringFirst, .nonRecurringFirst:
                return "repeat"
            }
        }
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    func sort(_ expenses: [Expense], by option: SortOption) -> [Expense] {
        switch option {
        case .dateAscending:
            return expenses.sorted { $0.date < $1.date }
        case .dateDescending:
            return expenses.sorted { $0.date > $1.date }
        case .amountAscending:
            return expenses.sorted { $0.amount.decimalValue < $1.amount.decimalValue }
        case .amountDescending:
            return expenses.sorted { $0.amount.decimalValue > $1.amount.decimalValue }
        case .merchantAscending:
            return expenses.sorted { $0.merchant.localizedCaseInsensitiveCompare($1.merchant) == .orderedAscending }
        case .merchantDescending:
            return expenses.sorted { $0.merchant.localizedCaseInsensitiveCompare($1.merchant) == .orderedDescending }
        case .categoryAscending:
            return expenses.sorted { $0.safeCategoryName.localizedCaseInsensitiveCompare($1.safeCategoryName) == .orderedAscending }
        case .categoryDescending:
            return expenses.sorted { $0.safeCategoryName.localizedCaseInsensitiveCompare($1.safeCategoryName) == .orderedDescending }
        case .paymentMethodAscending:
            return expenses.sorted { ($0.paymentMethod ?? "").localizedCaseInsensitiveCompare($1.paymentMethod ?? "") == .orderedAscending }
        case .paymentMethodDescending:
            return expenses.sorted { ($0.paymentMethod ?? "").localizedCaseInsensitiveCompare($1.paymentMethod ?? "") == .orderedDescending }
        case .recurringFirst:
            return expenses.sorted { $0.isRecurring && !$1.isRecurring }
        case .nonRecurringFirst:
            return expenses.sorted { !$0.isRecurring && $1.isRecurring }
        }
    }
    
    /// Async version for better performance with large datasets
    func sortAsync(_ expenses: [Expense], by option: SortOption) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let sortedExpenses = self.sort(expenses, by: option)
                continuation.resume(returning: sortedExpenses)
            }
        }
    }
}