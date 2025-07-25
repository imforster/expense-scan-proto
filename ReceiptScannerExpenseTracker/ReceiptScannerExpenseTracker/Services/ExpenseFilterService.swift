import Foundation
import Combine
import os.log

/// Service for filtering expenses with performance optimizations and debouncing
class ExpenseFilterService {
    
    // MARK: - Filter Criteria
    
    /// Comprehensive filter criteria for expense filtering
    struct FilterCriteria: Equatable, Hashable {
        let searchText: String?
        let category: CategoryData?
        let dateRange: DateInterval?
        let amountRange: ClosedRange<Decimal>?
        let vendor: String?
        let paymentMethod: String?
        let isRecurring: Bool?
        let tags: [TagData]
        let hasReceipt: Bool?
        
        init(
            searchText: String? = nil,
            category: CategoryData? = nil,
            dateRange: DateInterval? = nil,
            amountRange: ClosedRange<Decimal>? = nil,
            vendor: String? = nil,
            paymentMethod: String? = nil,
            isRecurring: Bool? = nil,
            tags: [TagData] = [],
            hasReceipt: Bool? = nil
        ) {
            self.searchText = searchText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : searchText
            self.category = category
            self.dateRange = dateRange
            self.amountRange = amountRange
            self.vendor = vendor?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : vendor
            self.paymentMethod = paymentMethod?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : paymentMethod
            self.isRecurring = isRecurring
            self.tags = tags
            self.hasReceipt = hasReceipt
        }
        
        /// Returns true if no filters are applied
        var isEmpty: Bool {
            return searchText == nil &&
                   category == nil &&
                   dateRange == nil &&
                   amountRange == nil &&
                   vendor == nil &&
                   paymentMethod == nil &&
                   isRecurring == nil &&
                   tags.isEmpty &&
                   hasReceipt == nil
        }
        
        /// Returns a description of active filters for UI display
        var activeFiltersDescription: String {
            var descriptions: [String] = []
            
            if let searchText = searchText {
                descriptions.append("Search: \(searchText)")
            }
            
            if let category = category {
                descriptions.append("Category: \(category.name)")
            }
            
            if let dateRange = dateRange {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                descriptions.append("Date: \(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))")
            }
            
            if let amountRange = amountRange {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                let min = formatter.string(from: NSDecimalNumber(decimal: amountRange.lowerBound)) ?? "$0"
                let max = formatter.string(from: NSDecimalNumber(decimal: amountRange.upperBound)) ?? "$0"
                descriptions.append("Amount: \(min) - \(max)")
            }
            
            if let vendor = vendor {
                descriptions.append("Vendor: \(vendor)")
            }
            
            if let paymentMethod = paymentMethod {
                descriptions.append("Payment: \(paymentMethod)")
            }
            
            if let isRecurring = isRecurring {
                descriptions.append(isRecurring ? "Recurring only" : "Non-recurring only")
            }
            
            if !tags.isEmpty {
                let tagNames = tags.map { $0.name }.joined(separator: ", ")
                descriptions.append("Tags: \(tagNames)")
            }
            
            if let hasReceipt = hasReceipt {
                descriptions.append(hasReceipt ? "With receipt" : "Without receipt")
            }
            
            return descriptions.joined(separator: "; ")
        }
    }
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseFilterService")
    private let debounceInterval: TimeInterval = 0.3
    private var filterCache: [FilterCriteria: [Expense]] = [:]
    private let maxCacheSize = 10
    
    // MARK: - Public Methods
    
    /// Filters expenses based on the provided criteria with optimized algorithms
    /// - Parameters:
    ///   - expenses: The expenses to filter
    ///   - criteria: The filter criteria to apply
    /// - Returns: Filtered expenses array
    func filter(_ expenses: [Expense], with criteria: FilterCriteria) -> [Expense] {
        logger.info("Filtering \(expenses.count) expenses with criteria: \(criteria.activeFiltersDescription)")
        
        // Return all expenses if no filters are applied
        guard !criteria.isEmpty else {
            logger.info("No filters applied, returning all expenses")
            return expenses
        }
        
        // Check cache first
        if let cachedResult = filterCache[criteria] {
            logger.info("Returning cached filter result with \(cachedResult.count) expenses")
            return cachedResult
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Apply filters in order of selectivity (most selective first for performance)
        var filteredExpenses = expenses
        
        // 1. Category filter (usually most selective)
        if let category = criteria.category {
            filteredExpenses = filteredExpenses.filter { expense in
                expense.category?.id == category.id
            }
            logger.debug("After category filter: \(filteredExpenses.count) expenses")
        }
        
        // 2. Date range filter
        if let dateRange = criteria.dateRange {
            filteredExpenses = filteredExpenses.filter { expense in
                dateRange.contains(expense.date)
            }
            logger.debug("After date filter: \(filteredExpenses.count) expenses")
        }
        
        // 3. Amount range filter
        if let amountRange = criteria.amountRange {
            filteredExpenses = filteredExpenses.filter { expense in
                let amount = expense.amount.decimalValue
                return amountRange.contains(amount)
            }
            logger.debug("After amount filter: \(filteredExpenses.count) expenses")
        }
        
        // 4. Payment method filter
        if let paymentMethod = criteria.paymentMethod {
            filteredExpenses = filteredExpenses.filter { expense in
                expense.paymentMethod?.localizedCaseInsensitiveContains(paymentMethod) == true
            }
            logger.debug("After payment method filter: \(filteredExpenses.count) expenses")
        }
        
        // 5. Recurring filter
        if let isRecurring = criteria.isRecurring {
            filteredExpenses = filteredExpenses.filter { expense in
                expense.isRecurring == isRecurring
            }
            logger.debug("After recurring filter: \(filteredExpenses.count) expenses")
        }
        
        // 6. Receipt filter
        if let hasReceipt = criteria.hasReceipt {
            filteredExpenses = filteredExpenses.filter { expense in
                (expense.receipt != nil) == hasReceipt
            }
            logger.debug("After receipt filter: \(filteredExpenses.count) expenses")
        }
        
        // 7. Tags filter (check if expense has all required tags)
        if !criteria.tags.isEmpty {
            let requiredTagIds = Set(criteria.tags.map { $0.id })
            filteredExpenses = filteredExpenses.filter { expense in
                guard let expenseTags = expense.tags as? Set<Tag> else { return false }
                let expenseTagIds = Set(expenseTags.map { $0.id })
                return requiredTagIds.isSubset(of: expenseTagIds)
            }
            logger.debug("After tags filter: \(filteredExpenses.count) expenses")
        }
        
        // 8. Text search filter (applied last as it's most expensive)
        if let searchText = criteria.searchText {
            filteredExpenses = filterBySearchText(filteredExpenses, searchText: searchText)
            logger.debug("After search text filter: \(filteredExpenses.count) expenses")
        }
        
        // 9. Vendor filter (similar to search but more specific)
        if let vendor = criteria.vendor {
            filteredExpenses = filteredExpenses.filter { expense in
                expense.merchant.localizedCaseInsensitiveContains(vendor)
            }
            logger.debug("After vendor filter: \(filteredExpenses.count) expenses")
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        logger.info("Filtering completed in \(String(format: "%.3f", duration))s, result: \(filteredExpenses.count) expenses")
        
        // Cache the result
        cacheFilterResult(criteria: criteria, result: filteredExpenses)
        
        return filteredExpenses
    }
    
    /// Applies debounced filtering using Combine publishers for real-time search
    /// - Parameters:
    ///   - expenses: The expenses to filter
    ///   - criteria: The filter criteria to apply
    /// - Returns: Publisher that emits filtered expenses with debouncing
    func debounceFilter(_ expenses: [Expense], with criteria: FilterCriteria) -> AnyPublisher<[Expense], Never> {
        logger.info("Setting up debounced filter")
        
        return Just(criteria)
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .map { [weak self] criteria in
                guard let self = self else { return [] }
                return self.filter(expenses, with: criteria)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Creates a publisher that filters expenses as criteria changes
    /// - Parameter expenses: The expenses to filter
    /// - Returns: Publisher that emits filtered expenses when criteria changes
    func createFilterPublisher(for expenses: [Expense]) -> AnyPublisher<([Expense], FilterCriteria), Never> {
        return PassthroughSubject<FilterCriteria, Never>()
            .debounce(for: .seconds(debounceInterval), scheduler: DispatchQueue.main)
            .map { [weak self] criteria in
                guard let self = self else { return ([], criteria) }
                let filtered = self.filter(expenses, with: criteria)
                return (filtered, criteria)
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    /// Clears the filter cache to free memory
    func clearCache() {
        filterCache.removeAll()
        logger.info("Filter cache cleared")
    }
    
    /// Returns statistics about current filter cache
    var cacheStatistics: (count: Int, maxSize: Int) {
        return (count: filterCache.count, maxSize: maxCacheSize)
    }
    
    // MARK: - Private Methods
    
    /// Filters expenses by search text across multiple fields
    private func filterBySearchText(_ expenses: [Expense], searchText: String) -> [Expense] {
        let searchTerms = searchText.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        guard !searchTerms.isEmpty else { return expenses }
        
        return expenses.filter { expense in
            // Search in merchant name
            let merchantMatch = searchTerms.allSatisfy { term in
                expense.merchant.lowercased().contains(term)
            }
            
            // Search in notes
            let notesMatch = expense.notes?.lowercased().contains { character in
                searchTerms.contains { term in
                    String(character).contains(term)
                }
            } ?? false
            
            // Search in category name
            let categoryMatch = expense.category?.name.lowercased().contains { character in
                searchTerms.contains { term in
                    String(character).contains(term)
                }
            } ?? false
            
            // Search in payment method
            let paymentMethodMatch = expense.paymentMethod?.lowercased().contains { character in
                searchTerms.contains { term in
                    String(character).contains(term)
                }
            } ?? false
            
            // Search in expense items
            let itemsMatch = (expense.items as? Set<ExpenseItem>)?.contains { item in
                searchTerms.allSatisfy { term in
                    item.name.lowercased().contains(term)
                }
            } ?? false
            
            // Search in tags
            let tagsMatch = (expense.tags as? Set<Tag>)?.contains { tag in
                searchTerms.allSatisfy { term in
                    tag.name.lowercased().contains(term)
                }
            } ?? false
            
            return merchantMatch || notesMatch || categoryMatch || paymentMethodMatch || itemsMatch || tagsMatch
        }
    }
    
    /// Caches filter results with LRU eviction
    private func cacheFilterResult(criteria: FilterCriteria, result: [Expense]) {
        // Implement simple LRU by removing oldest entries when cache is full
        if filterCache.count >= maxCacheSize {
            // Remove first (oldest) entry
            if let firstKey = filterCache.keys.first {
                filterCache.removeValue(forKey: firstKey)
            }
        }
        
        filterCache[criteria] = result
        logger.debug("Cached filter result for criteria with \(result.count) expenses")
    }
}

// MARK: - Convenience Extensions

extension ExpenseFilterService.FilterCriteria {
    
    /// Creates filter criteria for a specific date range
    static func dateRange(from startDate: Date, to endDate: Date) -> ExpenseFilterService.FilterCriteria {
        let dateInterval = DateInterval(start: startDate, end: endDate)
        return ExpenseFilterService.FilterCriteria(dateRange: dateInterval)
    }
    
    /// Creates filter criteria for this month
    static func thisMonth() -> ExpenseFilterService.FilterCriteria {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let endOfMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        
        return dateRange(from: startOfMonth, to: endOfMonth)
    }
    
    /// Creates filter criteria for this week
    static func thisWeek() -> ExpenseFilterService.FilterCriteria {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.end ?? now
        
        return dateRange(from: startOfWeek, to: endOfWeek)
    }
    
    /// Creates filter criteria for today
    static func today() -> ExpenseFilterService.FilterCriteria {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        
        return dateRange(from: startOfDay, to: endOfDay)
    }
    
    /// Creates filter criteria for expenses above a certain amount
    static func amountAbove(_ amount: Decimal) -> ExpenseFilterService.FilterCriteria {
        return ExpenseFilterService.FilterCriteria(amountRange: amount...Decimal(999999.99))
    }
    
    /// Creates filter criteria for expenses below a certain amount
    static func amountBelow(_ amount: Decimal) -> ExpenseFilterService.FilterCriteria {
        return ExpenseFilterService.FilterCriteria(amountRange: Decimal(0.01)...amount)
    }
}