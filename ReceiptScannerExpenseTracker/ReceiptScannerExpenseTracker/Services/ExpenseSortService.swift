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
    private var lastSortTime: Date = Date.distantPast
    private var invalidExpenseCount = 0
    
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
        let currentTime = Date()
        let timeSinceLastSort = currentTime.timeIntervalSince(lastSortTime)
        lastSortTime = currentTime
        
        // Reset invalid count periodically to avoid log spam
        if timeSinceLastSort > 5.0 {
            invalidExpenseCount = 0
        }
        
        // Filter out any invalid or deleted expenses before sorting with enhanced validation
        var localInvalidCount = 0
        let validExpenses = expenses.compactMap { expense -> Expense? in
            // Check if the expense object itself is valid
            guard !expense.isDeleted else {
                localInvalidCount += 1
                return nil
            }
            
            // Check if the managed object context is valid
            guard let context = expense.managedObjectContext else {
                localInvalidCount += 1
                return nil
            }
            
            // Enhanced fault checking - if object is a fault, ensure it can be accessed
            if expense.isFault {
                do {
                    // Try to refresh the object to ensure it's accessible
                    context.refresh(expense, mergeChanges: true)
                    
                    // Check again if it's still valid after refresh
                    if expense.isDeleted {
                        localInvalidCount += 1
                        return nil
                    }
                } catch {
                    localInvalidCount += 1
                    return nil
                }
            }
            
            // Comprehensive property accessibility test
            do {
                _ = expense.objectID
                _ = expense.date
                _ = expense.merchant
                _ = expense.amount
                
                // Test relationship access safely
                if let category = expense.category {
                    _ = category.name
                }
                
                return expense
            } catch {
                localInvalidCount += 1
                return nil
            }
        }
        
        // Only log if we have invalid expenses and haven't logged recently
        if localInvalidCount > 0 {
            self.invalidExpenseCount += localInvalidCount
            if timeSinceLastSort > 2.0 || self.invalidExpenseCount > 10 {
                logger.warning("Filtered out \(self.invalidExpenseCount) invalid expenses during sort operations")
                self.invalidExpenseCount = 0
            }
        }
        
        guard !validExpenses.isEmpty else {
            if timeSinceLastSort > 2.0 {
                logger.warning("No valid expenses to sort after filtering")
            }
            return []
        }
        
        // Perform sorting with enhanced error handling
        var comparisonErrors = 0
        let sortedExpenses = validExpenses.sorted { expense1, expense2 in
            // Double-check validity before comparison
            guard !expense1.isDeleted && !expense2.isDeleted,
                  expense1.managedObjectContext != nil && expense2.managedObjectContext != nil else {
                // Only log occasionally to avoid spam
                if comparisonErrors == 0 {
                    logger.warning("Invalid expense objects detected during comparison")
                }
                comparisonErrors += 1
                // Fallback to object ID comparison for stability
                return expense1.objectID.description < expense2.objectID.description
            }
            
            do {
                return try compareExpenses(expense1, expense2, using: option)
            } catch {
                // Only log the first few errors to avoid spam
                if comparisonErrors < 3 {
                    logger.error("Comparison failed: \(error.localizedDescription), using fallback")
                }
                comparisonErrors += 1
                
                // Safe fallback comparison with additional checks
                do {
                    // Try date comparison first
                    let date1 = expense1.date
                    let date2 = expense2.date
                    return date1 < date2
                } catch {
                    if comparisonErrors < 3 {
                        logger.error("Date comparison failed, using object ID comparison")
                    }
                    // Ultimate fallback: compare object IDs
                    return expense1.objectID.description < expense2.objectID.description
                }
            }
        }
        
        // Log summary if there were errors
        if comparisonErrors > 0 && timeSinceLastSort > 2.0 {
            logger.warning("Sort completed with \(comparisonErrors) comparison errors")
        }
        
        return sortedExpenses
    }
    
    /// Performs multi-level sorting with primary and secondary criteria
    private func performMultiLevelSort(_ expenses: [Expense], primary: SortOption, secondary: SortOption) throws -> [Expense] {
        // First filter out invalid expenses using enhanced validation logic
        let validExpenses = expenses.compactMap { expense -> Expense? in
            guard !expense.isDeleted,
                  let context = expense.managedObjectContext else {
                logger.warning("Invalid expense object in multi-level sort")
                return nil
            }
            
            // Enhanced fault checking for multi-level sort
            if expense.isFault {
                do {
                    context.refresh(expense, mergeChanges: true)
                    if expense.isDeleted {
                        logger.warning("Expense object was deleted after refresh in multi-level sort")
                        return nil
                    }
                } catch {
                    logger.warning("Failed to refresh faulted expense in multi-level sort: \(error.localizedDescription)")
                    return nil
                }
            }
            
            // Comprehensive accessibility test for multi-level sort
            do {
                _ = expense.objectID
                _ = expense.date
                _ = expense.merchant
                _ = expense.amount
                
                // Test relationship access safely
                if let category = expense.category {
                    _ = category.name
                }
                
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
        // Enhanced safety check: ensure objects are valid and not deleted
        guard let context1 = expense1.managedObjectContext, !expense1.isDeleted else {
            logger.warning("Expense1 object is deleted or has no context")
            throw NSError(domain: "ExpenseSortService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Cannot compare deleted expense objects"])
        }
        
        guard let context2 = expense2.managedObjectContext, !expense2.isDeleted else {
            logger.warning("Expense2 object is deleted or has no context")
            throw NSError(domain: "ExpenseSortService", code: 1002, userInfo: [NSLocalizedDescriptionKey: "Cannot compare deleted expense objects"])
        }
        
        // Additional fault checking during comparison
        if expense1.isFault {
            do {
                context1.refresh(expense1, mergeChanges: true)
                if expense1.isDeleted {
                    throw NSError(domain: "ExpenseSortService", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Expense1 became deleted after refresh"])
                }
            } catch {
                throw NSError(domain: "ExpenseSortService", code: 1004, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh expense1: \(error.localizedDescription)"])
            }
        }
        
        if expense2.isFault {
            do {
                context2.refresh(expense2, mergeChanges: true)
                if expense2.isDeleted {
                    throw NSError(domain: "ExpenseSortService", code: 1005, userInfo: [NSLocalizedDescriptionKey: "Expense2 became deleted after refresh"])
                }
            } catch {
                throw NSError(domain: "ExpenseSortService", code: 1006, userInfo: [NSLocalizedDescriptionKey: "Failed to refresh expense2: \(error.localizedDescription)"])
            }
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
        // Enhanced safety check: ensure objects are valid
        guard !expense1.isDeleted && !expense2.isDeleted,
              let context1 = expense1.managedObjectContext,
              let context2 = expense2.managedObjectContext else {
            logger.warning("Attempting to compare invalid expense objects in isEqual")
            return false
        }
        
        // Handle faulted objects in equality check
        if expense1.isFault {
            do {
                context1.refresh(expense1, mergeChanges: true)
                if expense1.isDeleted {
                    logger.warning("Expense1 became deleted during equality check")
                    return false
                }
            } catch {
                logger.warning("Failed to refresh expense1 in equality check: \(error.localizedDescription)")
                return false
            }
        }
        
        if expense2.isFault {
            do {
                context2.refresh(expense2, mergeChanges: true)
                if expense2.isDeleted {
                    logger.warning("Expense2 became deleted during equality check")
                    return false
                }
            } catch {
                logger.warning("Failed to refresh expense2 in equality check: \(error.localizedDescription)")
                return false
            }
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
