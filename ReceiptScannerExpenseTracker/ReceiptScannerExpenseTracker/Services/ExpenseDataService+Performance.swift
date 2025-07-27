import Foundation
import CoreData
import os.log

extension ExpenseDataService {
    
    // MARK: - Performance Optimization Methods
    
    /// Creates an optimized fetch request for expenses with performance considerations
    func createOptimizedExpenseFetchRequest(
        with criteria: ExpenseFilterService.FilterCriteria? = nil,
        sortOption: ExpenseSortService.SortOption = .dateDescending
    ) -> NSFetchRequest<Expense> {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        
        // Performance optimizations
        request.fetchBatchSize = 50 // Process in batches
        request.returnsObjectsAsFaults = false // Prefetch object data
        request.includesSubentities = false // Don't include subentities unless needed
        
        // Apply sorting based on option
        request.sortDescriptors = sortOption.sortDescriptors
        
        // Apply filtering predicate if provided
        if let criteria = criteria {
            request.predicate = buildOptimizedPredicate(from: criteria)
        }
        
        // Prefetch relationships that are commonly accessed
        request.relationshipKeyPathsForPrefetching = ["category", "receipt"]
        
        return request
    }
    
    /// Builds an optimized predicate for Core Data queries
    private func buildOptimizedPredicate(from criteria: ExpenseFilterService.FilterCriteria) -> NSPredicate {
        var predicates: [NSPredicate] = []
        
        // Text search - use indexed fields and efficient operators
        if let searchText = criteria.searchText, !searchText.isEmpty {
            // Use BEGINSWITH for better index utilization when possible
            let merchantPredicate = NSPredicate(format: "merchant BEGINSWITH[cd] %@", searchText)
            let notesPredicate = NSPredicate(format: "notes CONTAINS[cd] %@", searchText)
            let searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [merchantPredicate, notesPredicate])
            predicates.append(searchPredicate)
        }
        
        // Category filter - use object ID for better performance
        if let category = criteria.category {
            let categoryPredicate = NSPredicate(format: "category.id == %@", category.id as CVarArg)
            predicates.append(categoryPredicate)
        }
        
        // Date range filter - use efficient date comparisons
        if let dateRange = criteria.dateRange {
            let datePredicate = NSPredicate(
                format: "date >= %@ AND date < %@",
                dateRange.start as NSDate,
                dateRange.end as NSDate
            )
            predicates.append(datePredicate)
        }
        
        // Amount range filter - use decimal comparisons
        if let amountRange = criteria.amountRange {
            let amountPredicate = NSPredicate(
                format: "amount >= %@ AND amount <= %@",
                NSDecimalNumber(decimal: amountRange.lowerBound),
                NSDecimalNumber(decimal: amountRange.upperBound)
            )
            predicates.append(amountPredicate)
        }
        
        // Vendor filter - exact match for better performance
        if let vendor = criteria.vendor, !vendor.isEmpty {
            let vendorPredicate = NSPredicate(format: "merchant == %@", vendor)
            predicates.append(vendorPredicate)
        }
        
        return predicates.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
    
    /// Loads expenses with performance monitoring
    func loadExpensesWithPerformanceTracking() async {
        let startTime = CFAbsoluteTimeGetCurrent()
        let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseDataService+Performance")
        logger.info("Starting performance-tracked expense loading")
        
        await loadExpenses()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        logger.info("Expense loading completed in \(executionTime) seconds")
        
        // Log performance metrics
        if executionTime > 1.0 {
            logger.warning("Slow expense loading detected: \(executionTime) seconds for \(self.expenses.count) expenses")
        }
    }
    
    /// Preloads commonly accessed relationships to improve performance
    func preloadExpenseRelationships(_ expenses: [Expense]) async {
        guard !expenses.isEmpty else { return }
        
        let backgroundContext = CoreDataManager.shared.createBackgroundContext()
        await backgroundContext.perform {
            // Preload categories
            let categoryIds = expenses.compactMap { $0.category?.id }
            if !categoryIds.isEmpty {
                let categoryRequest: NSFetchRequest<Category> = Category.fetchRequest()
                categoryRequest.predicate = NSPredicate(format: "id IN %@", categoryIds)
                _ = try? backgroundContext.fetch(categoryRequest)
            }
            
            // Preload receipts
            let receiptIds = expenses.compactMap { $0.receipt?.id }
            if !receiptIds.isEmpty {
                let receiptRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
                receiptRequest.predicate = NSPredicate(format: "id IN %@", receiptIds)
                _ = try? backgroundContext.fetch(receiptRequest)
            }
        }
    }
    
    /// Optimized method to get expense count without loading all objects
    func getExpenseCount(with criteria: ExpenseFilterService.FilterCriteria? = nil) async throws -> Int {
        let backgroundContext = CoreDataManager.shared.createBackgroundContext()
        return try await backgroundContext.perform {
            let request: NSFetchRequest<Expense> = Expense.fetchRequest()
            
            if let criteria = criteria {
                request.predicate = self.buildOptimizedPredicate(from: criteria)
            }
            
            return try backgroundContext.count(for: request)
        }
    }
    
    /// Gets expense statistics without loading full objects
    func getExpenseStatistics(for dateRange: DateInterval? = nil) async throws -> ExpenseStatistics {
        let backgroundContext = CoreDataManager.shared.createBackgroundContext()
        return try await backgroundContext.perform {
            let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "Expense")
            request.resultType = .dictionaryResultType
            
            // Configure expression descriptions for aggregation
            let sumExpression = NSExpressionDescription()
            sumExpression.name = "totalAmount"
            sumExpression.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "amount")])
            sumExpression.expressionResultType = .decimalAttributeType
            
            let countExpression = NSExpressionDescription()
            countExpression.name = "count"
            countExpression.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
            countExpression.expressionResultType = .integer32AttributeType
            
            let avgExpression = NSExpressionDescription()
            avgExpression.name = "averageAmount"
            avgExpression.expression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "amount")])
            avgExpression.expressionResultType = .decimalAttributeType
            
            request.propertiesToFetch = [sumExpression, countExpression, avgExpression]
            
            // Apply date range filter if provided
            if let dateRange = dateRange {
                request.predicate = NSPredicate(
                    format: "date >= %@ AND date < %@",
                    dateRange.start as NSDate,
                    dateRange.end as NSDate
                )
            }
            
            let results = try backgroundContext.fetch(request)
            
            guard let result = results.first else {
                return ExpenseStatistics(totalAmount: 0, count: 0, averageAmount: 0)
            }
            
            let totalAmount = (result["totalAmount"] as? NSDecimalNumber)?.decimalValue ?? 0
            let count = result["count"] as? Int ?? 0
            let averageAmount = (result["averageAmount"] as? NSDecimalNumber)?.decimalValue ?? 0
            
            return ExpenseStatistics(
                totalAmount: totalAmount,
                count: count,
                averageAmount: averageAmount
            )
        }
    }
    
    /// Clears Core Data caches to free memory
    func clearCaches() {
        let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseDataService+Performance")
        NSFetchedResultsController<Expense>.deleteCache(withName: "ExpenseCache")
        CoreDataManager.shared.viewContext.refreshAllObjects()
        logger.info("Core Data caches cleared")
    }
    
    /// Optimizes memory usage by turning objects into faults
    func optimizeMemoryUsage() {
        let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseDataService+Performance")
        let context = CoreDataManager.shared.viewContext
        let allObjects = context.registeredObjects
        for object in allObjects {
            if !object.hasChanges {
                context.refresh(object, mergeChanges: false)
            }
        }
        logger.info("Memory optimization completed for \(allObjects.count) objects")
    }
}

// MARK: - Supporting Types

struct ExpenseStatistics {
    let totalAmount: Decimal
    let count: Int
    let averageAmount: Decimal
    
    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: totalAmount)) ?? "$0.00"
    }
    
    var formattedAverageAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: averageAmount)) ?? "$0.00"
    }
}

// MARK: - Sort Option Extensions

extension ExpenseSortService.SortOption {
    var sortDescriptors: [NSSortDescriptor] {
        switch self {
        case .dateAscending:
            return [
                NSSortDescriptor(keyPath: \Expense.date, ascending: true),
                NSSortDescriptor(keyPath: \Expense.merchant, ascending: true)
            ]
        case .dateDescending:
            return [
                NSSortDescriptor(keyPath: \Expense.date, ascending: false),
                NSSortDescriptor(keyPath: \Expense.merchant, ascending: true)
            ]
        case .amountAscending:
            return [
                NSSortDescriptor(keyPath: \Expense.amount, ascending: true),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .amountDescending:
            return [
                NSSortDescriptor(keyPath: \Expense.amount, ascending: false),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .merchantAscending:
            return [
                NSSortDescriptor(keyPath: \Expense.merchant, ascending: true),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .merchantDescending:
            return [
                NSSortDescriptor(keyPath: \Expense.merchant, ascending: false),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .categoryAscending:
            return [
                NSSortDescriptor(keyPath: \Expense.category?.name, ascending: true),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .categoryDescending:
            return [
                NSSortDescriptor(keyPath: \Expense.category?.name, ascending: false),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .paymentMethodAscending:
            return [
                NSSortDescriptor(keyPath: \Expense.paymentMethod, ascending: true),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .paymentMethodDescending:
            return [
                NSSortDescriptor(keyPath: \Expense.paymentMethod, ascending: false),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .recurringFirst:
            return [
                NSSortDescriptor(keyPath: \Expense.isRecurring, ascending: false),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        case .nonRecurringFirst:
            return [
                NSSortDescriptor(keyPath: \Expense.isRecurring, ascending: true),
                NSSortDescriptor(keyPath: \Expense.date, ascending: false)
            ]
        }
    }
}