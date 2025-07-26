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
        
        // Filter out any invalid or deleted expenses before sorting with comprehensive checks
        let validExpenses = expenses.compactMap { expense -> Expense? in
            // Check if the expense object itself is valid
            guard !expense.isDeleted else {
                logger.warning("Expense object is deleted")
                return nil
            }
            
            // Check if the managed object context is valid
            guard let context = expense.managedObjectContext else {
                logger.warning("Expense object has no managed object context")
                return nil
            }
            
            // Check if the context itself is still valid (not deallocated)
            // Note: NSManagedObjectContext doesn't have isDeleted property, but we can check if it's still accessible
            
            // Additional safety check: try to access a basic property to ensure object is accessible
            do {
                _ = expense.objectID
                _ = expense.date // This will throw if the object is inaccessible
                return expense
            } catch {
                logger.warning("Expense object is inaccessible: \(error.localizedDescription)")
                return nil
            }
        }
        
        guard !validExpenses.isEmpty else {
            logger.warning("No valid expenses to sort after filtering")
            return []
        }
        
        // Perform sorting with enhanced error handling
        return validExpenses.sorted { expense1, expense2 in
            // Double-check validity before comparison
            guard !expense1.isDeleted && !expense2.isDeleted,
                  expense1.managedObjectContext != nil && expense2.managedObjectContext != nil else {
                logger.warning("Invalid expense objects detected during comparison")
                // Fallback to object ID comparison for stability
                return expense1.objectID.description < expense2.objectID.description
            }
            
            do {
                return try compareExpenses(expense1, expense2, using: option)
            } catch {
                // Log the error but continue with a fallback comparison
                logger.error("Comparison failed: \(error.localizedDescription), using fallback")
                
                // Safe fallback comparison with additional checks
                do {
                    // Try date comparison first
                    let date1 = expense1.date
                    let date2 = expense2.date
                    return date1 < date2
                } catch {
                    logger.error("Date comparison failed, using object ID comparison")
                    // Ultimate fallback: compare object IDs
                    return expense1.objectID.description < expense2.objectID.description
                }
            }
        }
    }
    
    /// Performs multi-level sorting with primary and secondary criteria
    private func performMultiLevelSort(_ expenses: [Expense], primary: SortOption, secondary: SortOption) throws -> [Expense] {
        // First filter out invalid expenses using the same logic as performSort
        let validExpenses = expenses.compactMap { expense -> Expense? in
            guard !expense.isDeleted,
                  let context = expense.managedObjectContext else {
                logger.warning("Invalid expense object in multi-level sort")
                return nil
            }
            
            // Test accessibility
            do {
                _ = expense.objectID
                _ = expense.date
                return expense
            } catch {
                logger.warning("Expense object is inaccessible in multi-level sort: \(error.localizedDescription)")
                return nil
            }
        }
        
        guard !validExpenses.isEmpty else {
            logger.warning("No valid expenses for multi-level sort")
            return []
        }
        
        return validExpenses.sorted { expense1, expense2 in
            // Double-check validity before comparison
            guard !expense1.isDeleted && !expense2.isDeleted,
                  expense1.managedObjectContext != nil && expense2.managedObjectContext != nil else {
                logger.warning("Invalid expense objects detected during multi-level comparison")
                return expense1.objectID.description < expense2.objectID.description
            }
            
            do {
                let primaryResult = try compareExpenses(expense1, expense2, using: primary)
                
                // If primary comparison is equal, use secondary
                if isEqual(expense1, expense2, using: primary) {
                    return try compareExpenses(expense1, expense2, using: secondary)
                }
                
                return primaryResult
            } catch {
                logger.error("Multi-level comparison failed: \(error.localizedDescription), using fallback")
                
                // Safe fallback
                do {
                    return expense1.date < expense2.date
                } catch {
                    logger.error("Date fallback failed in multi-level sort, using object ID")
                    return expense1.objectID.description < expense2.objectID.description
                }
            }
        }
    }
    
    /// Compares two expenses using the specified sort option
    private func compareExpenses(_ expense1: Expense, _ expense2: Expense, using option: SortOption) throws -> Bool {
        // Safety check: ensure objects are valid and not deleted
        guard let context1 = expense1.managedObjectContext, !expense1.isDeleted else {
            logger.warning("Expense1 object is deleted or has no context")
            throw NSError(domain: "ExpenseSortService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Cannot compare deleted expense objects"])
        }
        
        guard let context2 = expense2.managedObjectContext, !expense2.isDeleted else {
            logger.warning("Expense2 object is deleted or has no context")
            throw NSError(domain: "ExpenseSortService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Cannot compare deleted expense objects"])
        }
        
        switch option {
        case .dateAscending:
            let date1 = expense1.date
            let date2 = expense2.date
            return date1 < date2
        case .dateDescending:
            let date1 = expense1.date
            let date2 = expense2.date
            return date1 > date2
            
        case .amountAscending:
            let amount1 = expense1.amount.decimalValue
            let amount2 = expense2.amount.decimalValue
            return amount1 < amount2
        case .amountDescending:
            let amount1 = expense1.amount.decimalValue
            let amount2 = expense2.amount.decimalValue
            return amount1 > amount2
            
        case .merchantAscending:
            let merchant1 = expense1.safeMerchant
            let merchant2 = expense2.safeMerchant
            return merchant1.localizedCaseInsensitiveCompare(merchant2) == .orderedAscending
        case .merchantDescending:
            let merchant1 = expense1.safeMerchant
            let merchant2 = expense2.safeMerchant
            return merchant1.localizedCaseInsensitiveCompare(merchant2) == .orderedDescending
            
        case .categoryAscending:
            let category1 = expense1.safeCategoryName
            let category2 = expense2.safeCategoryName
            return category1.localizedCaseInsensitiveCompare(category2) == .orderedAscending
        case .categoryDescending:
            let category1 = expense1.safeCategoryName
            let category2 = expense2.safeCategoryName
            return category1.localizedCaseInsensitiveCompare(category2) == .orderedDescending
            
        case .paymentMethodAscending:
            let payment1 = expense1.safePaymentMethod
            let payment2 = expense2.safePaymentMethod
            return payment1.localizedCaseInsensitiveCompare(payment2) == .orderedAscending
        case .paymentMethodDescending:
            let payment1 = expense1.safePaymentMethod
            let payment2 = expense2.safePaymentMethod
            return payment1.localizedCaseInsensitiveCompare(payment2) == .orderedDescending
            
        case .recurringFirst:
            let recurring1 = expense1.isRecurring
            let recurring2 = expense2.isRecurring
            if recurring1 != recurring2 {
                return recurring1 && !recurring2
            }
            // If both have same recurring status, sort by date (newest first)
            let date1 = expense1.date
            let date2 = expense2.date
            return date1 > date2
            
        case .nonRecurringFirst:
            let recurring1 = expense1.isRecurring
            let recurring2 = expense2.isRecurring
            if recurring1 != recurring2 {
                return !recurring1 && recurring2
            }
            // If both have same recurring status, sort by date (newest first)
            let date1 = expense1.date
            let date2 = expense2.date
            return date1 > date2
        }
    }
    
    /// Checks if two expenses are equal for the given sort option
    private func isEqual(_ expense1: Expense, _ expense2: Expense, using option: SortOption) -> Bool {
        // Safety check: ensure objects are valid
        guard !expense1.isDeleted && !expense2.isDeleted,
              expense1.managedObjectContext != nil && expense2.managedObjectContext != nil else {
            logger.warning("Attempting to compare invalid expense objects in isEqual")
            return false
        }
        
        switch option {
        case .dateAscending, .dateDescending:
            let date1 = expense1.date
            let date2 = expense2.date
            return date1 == date2
            
        case .amountAscending, .amountDescending:
            let amount1 = expense1.amount.decimalValue
            let amount2 = expense2.amount.decimalValue
            return amount1 == amount2
            
        case .merchantAscending, .merchantDescending:
            let merchant1 = expense1.safeMerchant
            let merchant2 = expense2.safeMerchant
            return merchant1.localizedCaseInsensitiveCompare(merchant2) == .orderedSame
            
        case .categoryAscending, .categoryDescending:
            let category1 = expense1.safeCategoryName
            let category2 = expense2.safeCategoryName
            return category1.localizedCaseInsensitiveCompare(category2) == .orderedSame
            
        case .paymentMethodAscending, .paymentMethodDescending:
            let payment1 = expense1.safePaymentMethod
            let payment2 = expense2.safePaymentMethod
            return payment1.localizedCaseInsensitiveCompare(payment2) == .orderedSame
            
        case .recurringFirst, .nonRecurringFirst:
            let recurring1 = expense1.isRecurring
            let recurring2 = expense2.isRecurring
            return recurring1 == recurring2
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
