# Core Data Performance Optimization Guide

## Overview
This guide provides comprehensive performance optimization strategies for the Receipt Scanner Expense Tracker's Core Data implementation.

## 1. Change Tracking and Debouncing

### Implementation
The `ExpenseListViewModel` uses debounced change tracking to prevent excessive UI updates:

```swift
private var lastCoreDataChangeTime: Date = Date.distantPast
private let changeDebounceInterval: TimeInterval = 0.3 // 300ms debounce

// In applyFiltersAndSort method:
let timeSinceLastChange = Date().timeIntervalSince(lastCoreDataChangeTime)
if timeSinceLastChange < changeDebounceInterval {
    let delayNanoseconds = UInt64((changeDebounceInterval - timeSinceLastChange) * 1_000_000_000)
    try? await Task.sleep(nanoseconds: delayNanoseconds)
}
```

### Benefits
- Prevents UI flickering during rapid Core Data changes
- Reduces CPU usage during batch operations
- Improves user experience during data synchronization

## 2. Optimized Fetch Requests

### Key Optimizations

#### Batch Size Configuration
```swift
request.fetchBatchSize = 50 // Process in batches of 50
```

#### Fault Handling
```swift
request.returnsObjectsAsFaults = false // Prefetch object data
```

#### Relationship Prefetching
```swift
request.relationshipKeyPathsForPrefetching = ["category", "receipt"]
```

#### Property Fetching
```swift
request.propertiesToFetch = ["id", "amount", "date", "merchant", "notes", "paymentMethod"]
request.resultType = .managedObjectResultType
```

## 3. Predicate Optimization

### Efficient Text Search
```swift
// Use BEGINSWITH for indexed fields when possible
let merchantPredicate = NSPredicate(format: "merchant BEGINSWITH[cd] %@", searchText)

// Use CONTAINS for full-text search
let notesPredicate = NSPredicate(format: "notes CONTAINS[cd] %@", searchText)
```

### Date Range Filtering
```swift
// Use efficient date comparisons
let datePredicate = NSPredicate(
    format: "date >= %@ AND date < %@",
    dateRange.start as NSDate,
    dateRange.end as NSDate
)
```

### Object ID Comparisons
```swift
// Use object IDs for better performance
let categoryPredicate = NSPredicate(format: "category.id == %@", category.id as CVarArg)
```

## 4. Memory Management

### Automatic Memory Optimization
```swift
// Listen for memory warnings
memoryWarningObserver = NotificationCenter.default.addObserver(
    forName: UIApplication.didReceiveMemoryWarningNotification,
    object: nil,
    queue: .main
) { [weak self] _ in
    self?.handleMemoryWarning()
}
```

### Cache Management
```swift
func clearCaches() {
    NSFetchedResultsController<Expense>.deleteCache(withName: "ExpenseCache")
    context.refreshAllObjects()
    backgroundContext.refreshAllObjects()
}
```

### Object Fault Management
```swift
func optimizeMemoryUsage() {
    let allObjects = context.registeredObjects
    for object in allObjects {
        if !object.hasChanges {
            context.refresh(object, mergeChanges: false)
        }
    }
}
```

## 5. Batch Operations

### Batch Delete
```swift
func batchDeleteExpenses(matching predicate: NSPredicate) async throws -> Int {
    let context = coreDataManager.createBackgroundContext()
    
    return try await context.perform {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Expense.fetchRequest()
        fetchRequest.predicate = predicate
        
        let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        batchDeleteRequest.resultType = .resultTypeCount
        
        let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
        let deletedCount = result?.result as? Int ?? 0
        
        // Merge changes to main context
        if deletedCount > 0 {
            let changes = [NSDeletedObjectsKey: result?.result ?? []]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [self.coreDataManager.viewContext])
        }
        
        return deletedCount
    }
}
```

### Batch Update
```swift
func batchUpdateExpenses(matching predicate: NSPredicate, updates: [String: Any]) async throws -> Int {
    let batchUpdateRequest = NSBatchUpdateRequest(entityName: "Expense")
    batchUpdateRequest.predicate = predicate
    batchUpdateRequest.propertiesToUpdate = updates
    batchUpdateRequest.resultType = .updatedObjectsCountResultType
    
    let result = try context.execute(batchUpdateRequest) as? NSBatchUpdateResult
    return result?.result as? Int ?? 0
}
```

## 6. Performance Monitoring

### Execution Time Tracking
```swift
func loadExpensesWithPerformanceTracking() async {
    let startTime = CFAbsoluteTimeGetCurrent()
    logger.info("Starting performance-tracked expense loading")
    
    await loadExpenses()
    
    let endTime = CFAbsoluteTimeGetCurrent()
    let executionTime = endTime - startTime
    
    logger.info("Expense loading completed in \(executionTime) seconds")
    
    if executionTime > 1.0 {
        logger.warning("Slow expense loading detected: \(executionTime) seconds")
    }
}
```

## 7. Statistics Without Full Object Loading

### Aggregation Queries
```swift
func getExpenseStatistics(for dateRange: DateInterval? = nil) async throws -> ExpenseStatistics {
    let request: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "Expense")
    request.resultType = .dictionaryResultType
    
    let sumExpression = NSExpressionDescription()
    sumExpression.name = "totalAmount"
    sumExpression.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: "amount")])
    sumExpression.expressionResultType = .decimalAttributeType
    
    request.propertiesToFetch = [sumExpression]
    
    let results = try context.fetch(request)
    // Process results...
}
```

## 8. Configuration Best Practices

### Core Data Stack Configuration
```swift
// Enable data protection
description.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)

// Enable WAL mode for better concurrency
description.setOption("WAL" as NSString, forKey: NSSQLitePragmasOption)

// Configure merge policy
context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

### Background Context Setup
```swift
func createBackgroundContext() -> NSManagedObjectContext {
    let context = container.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    context.automaticallyMergesChangesFromParent = true
    return context
}
```

## 9. Common Performance Pitfalls to Avoid

### ❌ Don't Do This
```swift
// Loading all objects to count them
let allExpenses = try context.fetch(request)
let count = allExpenses.count
```

### ✅ Do This Instead
```swift
// Use count(for:) for better performance
let count = try context.count(for: request)
```

### ❌ Don't Do This
```swift
// Accessing relationships in loops without prefetching
for expense in expenses {
    print(expense.category?.name) // N+1 query problem
}
```

### ✅ Do This Instead
```swift
// Prefetch relationships
request.relationshipKeyPathsForPrefetching = ["category"]
let expenses = try context.fetch(request)
```

## 10. Performance Testing

### Unit Test Example
```swift
func testExpenseLoadingPerformance() async throws {
    // Create test data
    let testExpenses = try await createTestExpenses(count: 1000)
    
    // Measure performance
    let startTime = CFAbsoluteTimeGetCurrent()
    await expenseDataService.loadExpenses()
    let endTime = CFAbsoluteTimeGetCurrent()
    
    let executionTime = endTime - startTime
    XCTAssertLessThan(executionTime, 1.0, "Expense loading should complete within 1 second")
}
```

## 11. Monitoring and Debugging

### Core Data Debug Arguments
Add these to your scheme's launch arguments for debugging:
- `-com.apple.CoreData.SQLDebug 1` - SQL query logging
- `-com.apple.CoreData.Logging.stderr 1` - Core Data logging

### Performance Instruments
Use Instruments to profile:
- Core Data instrument for query analysis
- Time Profiler for CPU usage
- Allocations for memory usage

## Summary

Following these optimization patterns will ensure your Core Data implementation:
- Scales well with large datasets
- Provides smooth user experience
- Uses memory efficiently
- Handles concurrent operations safely
- Maintains good performance across different device capabilities