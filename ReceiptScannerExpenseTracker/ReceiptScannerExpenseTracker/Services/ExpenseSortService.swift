import Foundation
import os.log

/// Service for sorting expenses with custom comparators and performance optimizations
class ExpenseSortService {
    
    // MARK: - Sort Options
    
    /// Available sorting options for expenses
    enum SortOption: String, CaseIterable, Identifiable {
        case dateAscending = "date_asc"
        case dateDescending = "date_desc"
        case amountAscending = "amount_asc"
        case amountDescending = "amount_desc"
        case merchantAscending = "merchant_asc"
        case merchantDescending = "merchant_desc"
        case categoryAscending = "category_asc"
        case categoryDescending = "category_desc"
        case paymentMethodAscending = "payment_asc"
        case paymentMethodDescending = "payment_desc"
        case recurringFirst = "recurring_first"
        case nonRecurringFirst = "non_recurring_first"
        
        var id: String { rawValue }
        
        /// Human-readable display name for the sort option
        var displayName: String {
            switch self {
            case .dateAscending:
                return "Date (Oldest First)"
            case .dateDescending:
                return "Date (Newest First)"
            case .amountAscending:
                return "Amount (Low to High)"
            case .amountDescending:
                return "Amount (High to Low)"
            case .merchantAscending:
                return "Merchant (A to Z)"
            case .merchantDescending:
                return "Merchant (Z to A)"
            case .categoryAscending:
                return "Category (A to Z)"
            case .categoryDescending:
                return "Category (Z to A)"
            case .paymentMethodAscending:
                return "Payment Method (A to Z)"
            case .paymentMethodDescending:
                return "Payment Method (Z to A)"
            case .recurringFirst:
                return "Recurring First"
            case .nonRecurringFirst:
                return "Non-Recurring First"
            }
        }
        
        /// Icon name for UI display
        var iconName: String {
            switch self {
            case .dateAscending, .dateDescending:
                return "calendar"
            case .amountAscending, .amountDescending:
                return "dollarsign.circle"
            case .merchantAscending, .merchantDescending:
                return "building.2"
            case .categoryAscending, .categoryDescending:
                return "folder"
            case .paymentMethodAscending, .paymentMethodDescending:
                return "creditcard"
            case .recurringFirst, .nonRecurringFirst:
                return "repeat"
            }
        }
        
        /// Whether this sort option is ascending
        var isAscending: Bool {
            switch self {
            case .dateAscending, .amountAscending, .merchantAscending, .categoryAscending, .paymentMethodAscending:
                return true
            case .dateDescending, .amountDescending, .merchantDescending, .categoryDescending, .paymentMethodDescending:
                return false
            case .recurringFirst, .nonRecurringFirst:
                return true // Arbitrary for boolean sorts
            }
        }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseSortService")
    private let asyncSortThreshold = 100 // Use async sorting for datasets larger than this
    
    // MARK: - Public Methods
    
    /// Sorts expenses synchronously using the specified sort option
    /// - Parameters:
    ///   - expenses: The expenses to sort
    ///   - option: The sort option to apply
    /// - Returns: Sorted expenses array
    func sort(_ expenses: [Expense], by option: SortOption) -> [Expense] {
        logger.info("Sorting \(expenses.count) expenses by \(option.displayName)")
        
        guard !expenses.isEmpty else {
            logger.info("No expenses to sort")
            return expenses
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let sortedExpenses: [Expense]
        
        do {
            sortedExpenses = try performSort(expenses, by: option)
        } catch {
            logger.error("Sort failed with error: \(error.localizedDescription), returning original array")
            return expenses
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        logger.info("Sorting completed in \(String(format: "%.3f", duration))s")
        
        return sortedExpenses
    }
    
    /// Sorts expenses asynchronously for large datasets
    /// - Parameters:
    ///   - expenses: The expenses to sort
    ///   - option: The sort option to apply
    /// - Returns: Sorted expenses array
    func sortAsync(_ expenses: [Expense], by option: SortOption) async -> [Expense] {
        logger.info("Async sorting \(expenses.count) expenses by \(option.displayName)")
        
        guard !expenses.isEmpty else {
            logger.info("No expenses to sort")
            return expenses
        }
        
        // For small datasets, use synchronous sorting
        if expenses.count < asyncSortThreshold {
            return sort(expenses, by: option)
        }
        
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: expenses)
                    return
                }
                
                let result = self.sort(expenses, by: option)
                continuation.resume(returning: result)
            }
        }
    }
    
    /// Sorts expenses with multiple criteria (primary and secondary sort)
    /// - Parameters:
    ///   - expenses: The expenses to sort
    ///   - primarySort: The primary sort option
    ///   - secondarySort: The secondary sort option for tie-breaking
    /// - Returns: Sorted expenses array
    func sort(_ expenses: [Expense], by primarySort: SortOption, then secondarySort: SortOption) -> [Expense] {
        logger.info("Multi-level sorting \(expenses.count) expenses by \(primarySort.displayName) then \(secondarySort.displayName)")
        
        guard !expenses.isEmpty else { return expenses }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let sortedExpenses: [Expense]
        
        do {
            sortedExpenses = try performMultiLevelSort(expenses, primary: primarySort, secondary: secondarySort)
        } catch {
            logger.error("Multi-level sort failed with error: \(error.localizedDescription), returning original array")
            return expenses
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        logger.info("Multi-level sorting completed in \(String(format: "%.3f", duration))s")
        
        return sortedExpenses
    }
    
    /// Returns the default sort option
    class var defaultSortOption: SortOption {
        return .dateDescending
    }
    
    /// Returns commonly used sort options for quick access
    class var commonSortOptions: [SortOption] {
        return [.dateDescending, .dateAscending, .amountDescending, .amountAscending, .merchantAscending]
    }
    
    // MARK: - Private Methods
    
    /// Performs the actual sorting with error handling
    private func performSort(_ expenses: [Expense], by option: SortOption) throws -> [Expense] {
        return expenses.sorted { expense1, expense2 in
            do {
                return try compareExpenses(expense1, expense2, using: option)
            } catch {
                // Log the error but continue with a fallback comparison
                logger.error("Comparison failed: \(error.localizedDescription), using fallback")
                return expense1.date < expense2.date // Fallback to date comparison
            }
        }
    }
    
    /// Performs multi-level sorting with primary and secondary criteria
    private func performMultiLevelSort(_ expenses: [Expense], primary: SortOption, secondary: SortOption) throws -> [Expense] {
        return expenses.sorted { expense1, expense2 in
            do {
                let primaryResult = try compareExpenses(expense1, expense2, using: primary)
                
                // If primary comparison is equal, use secondary
                if isEqual(expense1, expense2, using: primary) {
                    return try compareExpenses(expense1, expense2, using: secondary)
                }
                
                return primaryResult
            } catch {
                logger.error("Multi-level comparison failed: \(error.localizedDescription), using fallback")
                return expense1.date < expense2.date
            }
        }
    }
    
    /// Compares two expenses using the specified sort option
    private func compareExpenses(_ expense1: Expense, _ expense2: Expense, using option: SortOption) throws -> Bool {
        switch option {
        case .dateAscending:
            return expense1.date < expense2.date
        case .dateDescending:
            return expense1.date > expense2.date
            
        case .amountAscending:
            return expense1.amount.decimalValue < expense2.amount.decimalValue
        case .amountDescending:
            return expense1.amount.decimalValue > expense2.amount.decimalValue
            
        case .merchantAscending:
            return expense1.safeMerchant.localizedCaseInsensitiveCompare(expense2.safeMerchant) == .orderedAscending
        case .merchantDescending:
            return expense1.safeMerchant.localizedCaseInsensitiveCompare(expense2.safeMerchant) == .orderedDescending
            
        case .categoryAscending:
            return expense1.safeCategoryName.localizedCaseInsensitiveCompare(expense2.safeCategoryName) == .orderedAscending
        case .categoryDescending:
            return expense1.safeCategoryName.localizedCaseInsensitiveCompare(expense2.safeCategoryName) == .orderedDescending
            
        case .paymentMethodAscending:
            return expense1.safePaymentMethod.localizedCaseInsensitiveCompare(expense2.safePaymentMethod) == .orderedAscending
        case .paymentMethodDescending:
            return expense1.safePaymentMethod.localizedCaseInsensitiveCompare(expense2.safePaymentMethod) == .orderedDescending
            
        case .recurringFirst:
            if expense1.isRecurring != expense2.isRecurring {
                return expense1.isRecurring && !expense2.isRecurring
            }
            // If both have same recurring status, sort by date (newest first)
            return expense1.date > expense2.date
            
        case .nonRecurringFirst:
            if expense1.isRecurring != expense2.isRecurring {
                return !expense1.isRecurring && expense2.isRecurring
            }
            // If both have same recurring status, sort by date (newest first)
            return expense1.date > expense2.date
        }
    }
    
    /// Checks if two expenses are equal for the given sort option
    private func isEqual(_ expense1: Expense, _ expense2: Expense, using option: SortOption) -> Bool {
        switch option {
        case .dateAscending, .dateDescending:
            return expense1.date == expense2.date
            
        case .amountAscending, .amountDescending:
            return expense1.amount.decimalValue == expense2.amount.decimalValue
            
        case .merchantAscending, .merchantDescending:
            return expense1.safeMerchant.localizedCaseInsensitiveCompare(expense2.safeMerchant) == .orderedSame
            
        case .categoryAscending, .categoryDescending:
            return expense1.safeCategoryName.localizedCaseInsensitiveCompare(expense2.safeCategoryName) == .orderedSame
            
        case .paymentMethodAscending, .paymentMethodDescending:
            return expense1.safePaymentMethod.localizedCaseInsensitiveCompare(expense2.safePaymentMethod) == .orderedSame
            
        case .recurringFirst, .nonRecurringFirst:
            return expense1.isRecurring == expense2.isRecurring
        }
    }
}

// MARK: - Sort Option Groups

extension ExpenseSortService.SortOption {
    
    /// Groups sort options by category for UI organization
    static var groupedOptions: [String: [ExpenseSortService.SortOption]] {
        return [
            "Date": [.dateDescending, .dateAscending],
            "Amount": [.amountDescending, .amountAscending],
            "Merchant": [.merchantAscending, .merchantDescending],
            "Category": [.categoryAscending, .categoryDescending],
            "Payment": [.paymentMethodAscending, .paymentMethodDescending],
            "Type": [.recurringFirst, .nonRecurringFirst]
        ]
    }
}

// MARK: - Performance Monitoring

extension ExpenseSortService {
    
    /// Performance metrics for sorting operations
    struct SortPerformanceMetrics {
        let itemCount: Int
        let sortOption: SortOption
        let duration: TimeInterval
        let wasAsync: Bool
        
        var itemsPerSecond: Double {
            guard duration > 0 else { return 0 }
            return Double(itemCount) / duration
        }
    }
    
    /// Measures and logs performance metrics for sorting operations
    private func measurePerformance<T>(
        operation: () throws -> T,
        itemCount: Int,
        sortOption: SortOption,
        isAsync: Bool = false
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let metrics = SortPerformanceMetrics(
            itemCount: itemCount,
            sortOption: sortOption,
            duration: endTime - startTime,
            wasAsync: isAsync
        )
        
        logger.info("Sort performance: \(metrics.itemCount) items, \(String(format: "%.3f", metrics.duration))s, \(String(format: "%.0f", metrics.itemsPerSecond)) items/sec")
        
        // Log warning for slow operations
        if metrics.duration > 1.0 {
            logger.warning("Slow sort operation detected: \(String(format: "%.3f", metrics.duration))s for \(metrics.itemCount) items")
        }
        
        return result
    }
}