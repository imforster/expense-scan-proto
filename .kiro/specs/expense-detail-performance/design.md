# ExpenseDetailView Performance Optimization Design

## Overview

This design addresses performance bottlenecks in the ExpenseDetailView by implementing Core Data optimization, view rendering improvements, memory management, and background processing strategies.

## Architecture

### Core Data Performance Layer
- **ExpenseDetailViewModel**: Manages data fetching and caching
- **ExpenseDataCache**: Caches computed properties and formatted values
- **RelationshipPrefetcher**: Handles efficient Core Data relationship loading

### View Performance Layer
- **OptimizedExpenseDetailView**: Refactored view with performance optimizations
- **LazyLoadingComponents**: Components that load data on-demand
- **CachedFormatters**: Shared formatters for currency and date formatting

### Background Processing Layer
- **DataProcessor**: Handles heavy computations on background threads
- **ImageLoader**: Asynchronous image loading for receipts
- **CacheManager**: Manages memory usage and cleanup

## Components and Interfaces

### ExpenseDetailViewModel

```swift
@MainActor
class ExpenseDetailViewModel: ObservableObject {
    @Published var expense: Expense
    @Published var isLoading = false
    
    private let dataCache: ExpenseDataCache
    private let imageLoader: ImageLoader
    
    // Cached properties
    var formattedAmount: String { dataCache.formattedAmount }
    var formattedDate: String { dataCache.formattedDate }
    var expenseItems: [ExpenseItem] { dataCache.expenseItems }
    var tags: [Tag] { dataCache.tags }
    
    func loadExpenseData() async
    func refreshData() async
    func prefetchRelationships() async
}
```

### ExpenseDataCache

```swift
class ExpenseDataCache {
    private var cachedValues: [String: Any] = [:]
    private let expense: Expense
    
    var formattedAmount: String { getCachedValue("amount") }
    var formattedDate: String { getCachedValue("date") }
    var expenseItems: [ExpenseItem] { getCachedValue("items") }
    var tags: [Tag] { getCachedValue("tags") }
    
    private func getCachedValue<T>(_ key: String, compute: () -> T) -> T
    func invalidateCache()
}
```

### OptimizedExpenseDetailView

```swift
struct OptimizedExpenseDetailView: View {
    @StateObject private var viewModel: ExpenseDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    HeaderCardView(viewModel: viewModel)
                    
                    if viewModel.hasReceipt {
                        ReceiptImageCardView(viewModel: viewModel)
                    }
                    
                    DetailsCardView(viewModel: viewModel)
                    
                    if !viewModel.expenseItems.isEmpty {
                        ItemsCardView(items: viewModel.expenseItems)
                    }
                    
                    if !viewModel.tags.isEmpty {
                        TagsCardView(tags: viewModel.tags)
                    }
                    
                    if !viewModel.notes.isEmpty {
                        NotesCardView(notes: viewModel.notes)
                    }
                    
                    ActionButtonsView(viewModel: viewModel)
                }
                .padding()
            }
        }
        .task {
            await viewModel.loadExpenseData()
        }
    }
}
```

### CachedFormatters

```swift
class CachedFormatters {
    static let shared = CachedFormatters()
    
    lazy var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
    
    lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    lazy var mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
}
```

## Data Models

### Core Data Optimization

```swift
extension Expense {
    // Optimized property access with caching
    private static var propertyCache: [ObjectIdentifier: [String: Any]] = [:]
    
    var cachedFormattedAmount: String {
        let key = ObjectIdentifier(self)
        if let cached = Self.propertyCache[key]?["formattedAmount"] as? String {
            return cached
        }
        
        let formatted = CachedFormatters.shared.currencyFormatter.string(from: amount) ?? "$0.00"
        Self.propertyCache[key, default: [:]]]["formattedAmount"] = formatted
        return formatted
    }
    
    var cachedExpenseItems: [ExpenseItem] {
        let key = ObjectIdentifier(self)
        if let cached = Self.propertyCache[key]?["expenseItems"] as? [ExpenseItem] {
            return cached
        }
        
        let items = (self.items?.allObjects as? [ExpenseItem] ?? []).sorted { $0.name < $1.name }
        Self.propertyCache[key, default: [:]]]["expenseItems"] = items
        return items
    }
    
    static func clearCache(for expense: Expense) {
        let key = ObjectIdentifier(expense)
        propertyCache.removeValue(forKey: key)
    }
}
```

### Prefetching Strategy

```swift
class RelationshipPrefetcher {
    static func prefetchExpenseData(_ expense: Expense, context: NSManagedObjectContext) async {
        await context.perform {
            // Prefetch category
            _ = expense.category?.name
            _ = expense.category?.icon
            _ = expense.category?.colorHex
            
            // Prefetch items
            if let items = expense.items {
                for item in items {
                    if let expenseItem = item as? ExpenseItem {
                        _ = expenseItem.name
                        _ = expenseItem.amount
                    }
                }
            }
            
            // Prefetch tags
            if let tags = expense.tags {
                for tag in tags {
                    if let expenseTag = tag as? Tag {
                        _ = expenseTag.name
                    }
                }
            }
            
            // Prefetch receipt
            if let receipt = expense.receipt {
                _ = receipt.merchantName
                _ = receipt.imageURL
            }
        }
    }
}
```

## Error Handling

### Performance Monitoring

```swift
class PerformanceMonitor {
    static func measureViewLoadTime<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        if timeElapsed > 0.2 { // 200ms threshold
            print("⚠️ Slow view load detected: \(timeElapsed)s")
        }
        
        return result
    }
}
```

### Memory Management

```swift
class MemoryManager {
    static func cleanupExpenseCache() {
        Expense.clearAllCaches()
        CachedFormatters.shared.clearCache()
    }
    
    static func monitorMemoryUsage() {
        let memoryUsage = getMemoryUsage()
        if memoryUsage > 100_000_000 { // 100MB threshold
            cleanupExpenseCache()
        }
    }
}
```

## Testing Strategy

### Performance Tests

```swift
class ExpenseDetailPerformanceTests: XCTestCase {
    func testViewLoadTime() async throws {
        let expense = createTestExpense()
        let viewModel = ExpenseDetailViewModel(expense: expense)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadExpenseData()
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(loadTime, 0.2, "View should load within 200ms")
    }
    
    func testMemoryUsage() throws {
        let initialMemory = getMemoryUsage()
        
        // Create and load multiple expense detail views
        for _ in 0..<10 {
            let expense = createTestExpense()
            let viewModel = ExpenseDetailViewModel(expense: expense)
            // Simulate view lifecycle
        }
        
        let finalMemory = getMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThan(memoryIncrease, 50_000_000, "Memory increase should be less than 50MB")
    }
    
    func testCacheEfficiency() {
        let expense = createTestExpense()
        
        // First access - should compute
        let startTime1 = CFAbsoluteTimeGetCurrent()
        _ = expense.cachedFormattedAmount
        let firstAccessTime = CFAbsoluteTimeGetCurrent() - startTime1
        
        // Second access - should use cache
        let startTime2 = CFAbsoluteTimeGetCurrent()
        _ = expense.cachedFormattedAmount
        let secondAccessTime = CFAbsoluteTimeGetCurrent() - startTime2
        
        XCTAssertLessThan(secondAccessTime, firstAccessTime * 0.1, "Cached access should be 10x faster")
    }
}
```

### Load Testing

```swift
class ExpenseDetailLoadTests: XCTestCase {
    func testLargeExpenseItemsList() async throws {
        let expense = createExpenseWithManyItems(count: 100)
        let viewModel = ExpenseDetailViewModel(expense: expense)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadExpenseData()
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(loadTime, 0.5, "Should handle large item lists efficiently")
    }
    
    func testManyTagsPerformance() async throws {
        let expense = createExpenseWithManyTags(count: 50)
        let viewModel = ExpenseDetailViewModel(expense: expense)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        await viewModel.loadExpenseData()
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(loadTime, 0.3, "Should handle many tags efficiently")
    }
}
```

## Implementation Notes

### Phase 1: Core Data Optimization
1. Implement ExpenseDataCache for property caching
2. Add RelationshipPrefetcher for efficient data loading
3. Create CachedFormatters for shared formatter instances

### Phase 2: View Model Implementation
1. Create ExpenseDetailViewModel with async data loading
2. Implement background processing for heavy computations
3. Add performance monitoring and metrics

### Phase 3: View Optimization
1. Refactor ExpenseDetailView to use LazyVStack
2. Implement component-based architecture
3. Add lazy loading for images and large collections

### Phase 4: Memory Management
1. Implement cache cleanup strategies
2. Add memory usage monitoring
3. Optimize image loading and caching

### Performance Targets
- View load time: < 200ms for standard expenses
- Memory usage: < 50MB increase per view instance
- Scroll performance: Maintain 60fps
- Cache hit ratio: > 90% for repeated property access