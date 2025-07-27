# Design Document

## Overview

This document outlines the architectural redesign of the ExpenseList and ExpenseDetail components to address critical stability issues and improve maintainability. The new architecture introduces a service-oriented approach with proper separation of concerns, robust error handling, and performance optimizations.

## Architecture

### Current Problems

1. **CoreData Lifecycle Issues**: Direct use of `@FetchRequest` with `NSManagedObjectID` creates unstable object references
2. **Complex State Management**: Multiple interdependent state variables leading to inconsistent states
3. **Poor Error Handling**: Limited error recovery mechanisms causing crashes
4. **Performance Issues**: Synchronous operations on main thread and excessive recalculations
5. **Tight Coupling**: Views directly managing data operations and business logic

### New Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Presentation Layer                    │
├─────────────────────────────────────────────────────────────┤
│  ExpenseListView  │  ExpenseDetailView  │  ExpenseEditView  │
│       │           │         │           │         │         │
│  ExpenseList      │  ExpenseDetail      │  ExpenseEdit      │
│  ViewModel        │  ViewModel          │  ViewModel        │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                          │
├─────────────────────────────────────────────────────────────┤
│  ExpenseDataService  │  ExpenseFilterService  │  ExpenseSortService  │
│                      │                        │                      │
│  - Data Management   │  - Filter Logic        │  - Sort Logic        │
│  - CRUD Operations   │  - Search Functions    │  - Performance Opts  │
│  - Error Handling    │  - Debouncing          │  - Custom Comparators│
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                           │
├─────────────────────────────────────────────────────────────┤
│           NSFetchedResultsController                        │
│                      │                                      │
│                 CoreData Stack                              │
│                      │                                      │
│              Persistent Store                               │
└─────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. ExpenseDataService

**Purpose**: Centralized data management with automatic UI updates and proper error handling.

```swift
@MainActor
class ExpenseDataService: NSObject, ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var error: ExpenseError?
    
    private let context: NSManagedObjectContext
    private lazy var fetchedResultsController: NSFetchedResultsController<Expense>
    
    // Core functionality
    func loadExpenses() async
    func createExpense(_ expense: ExpenseData) async throws -> Expense
    func updateExpense(_ expense: Expense, with data: ExpenseData) async throws
    func deleteExpense(_ expense: Expense) async throws
    func getExpense(by id: NSManagedObjectID) async -> Expense?
}
```

**Key Features**:
- Uses NSFetchedResultsController for automatic updates
- Background context for heavy operations
- Comprehensive error handling
- Thread-safe operations

### 2. ExpenseFilterService

**Purpose**: Isolated filtering logic with performance optimizations.

```swift
class ExpenseFilterService {
    struct FilterCriteria {
        let searchText: String?
        let category: Category?
        let dateRange: DateInterval?
        let amountRange: ClosedRange<Decimal>?
        let vendor: String?
    }
    
    func filter(_ expenses: [Expense], with criteria: FilterCriteria) -> [Expense]
    func debounceFilter(_ expenses: [Expense], with criteria: FilterCriteria) -> AnyPublisher<[Expense], Never>
}
```

**Key Features**:
- Debounced filtering to prevent excessive operations
- Optimized filter algorithms
- Composable filter criteria
- Memory efficient operations

### 3. ExpenseSortService

**Purpose**: Efficient sorting with custom comparators and error handling.

```swift
class ExpenseSortService {
    enum SortOption: CaseIterable {
        case dateAscending, dateDescending
        case amountAscending, amountDescending
        case merchantAscending, merchantDescending
    }
    
    func sort(_ expenses: [Expense], by option: SortOption) -> [Expense]
    func sortAsync(_ expenses: [Expense], by option: SortOption) async -> [Expense]
}
```

**Key Features**:
- Async sorting for large datasets
- Custom comparators for complex sorting
- Error handling for invalid data
- Performance monitoring

### 4. ExpenseDetailViewModel

**Purpose**: Robust state management for expense detail view with proper error handling.

```swift
@MainActor
class ExpenseDetailViewModel: ObservableObject {
    @Published var viewState: ViewState = .loading
    @Published var error: ExpenseError?
    
    enum ViewState {
        case loading
        case loaded(Expense)
        case error(ExpenseError)
        case deleted
    }
    
    private let dataService: ExpenseDataService
    private let expenseID: NSManagedObjectID
    
    func loadExpense() async
    func deleteExpense() async
    func refreshExpense() async
}
```

**Key Features**:
- State machine for clear view states
- Safe expense loading and updates
- Proper cleanup and memory management
- Error recovery mechanisms

### 5. ExpenseListViewModel

**Purpose**: Simplified list management with service delegation and performance optimization.

```swift
@MainActor
class ExpenseListViewModel: ObservableObject {
    @Published var displayedExpenses: [Expense] = []
    @Published var viewState: ViewState = .loading
    @Published var filterCriteria = ExpenseFilterService.FilterCriteria()
    @Published var sortOption: ExpenseSortService.SortOption = .dateDescending
    
    enum ViewState {
        case loading
        case loaded([Expense])
        case empty
        case error(ExpenseError)
    }
    
    private let dataService: ExpenseDataService
    private let filterService: ExpenseFilterService
    private let sortService: ExpenseSortService
    
    func applyFilters() async
    func updateSort(_ option: ExpenseSortService.SortOption) async
    func clearFilters()
}
```

**Key Features**:
- Delegated filtering and sorting
- Debounced operations
- Clear state management
- Performance optimizations

## Data Models

### ExpenseError

```swift
enum ExpenseError: LocalizedError {
    case loadingFailed(Error)
    case savingFailed(Error)
    case deletionFailed(Error)
    case notFound
    case invalidData(String)
    case networkError(Error)
    
    var errorDescription: String? { /* User-friendly messages */ }
    var recoverySuggestion: String? { /* Recovery actions */ }
}
```

### ExpenseData

```swift
struct ExpenseData {
    let amount: Decimal
    let merchant: String
    let date: Date
    let category: Category?
    let notes: String?
    let paymentMethod: String?
    let isRecurring: Bool
    let tags: [Tag]
    let items: [ExpenseItemData]
}
```

## Error Handling

### Error Recovery Strategy

1. **Graceful Degradation**: Show cached data when possible
2. **User Feedback**: Clear error messages with actionable steps
3. **Automatic Retry**: For transient errors with exponential backoff
4. **Logging**: Comprehensive error logging for debugging
5. **Fallback UI**: Alternative UI states for error conditions

### Error Types and Handling

```swift
// Service Level Error Handling
func handleError(_ error: Error) -> ExpenseError {
    switch error {
    case let coreDataError as NSError where coreDataError.domain == NSCocoaErrorDomain:
        return .savingFailed(coreDataError)
    case let validationError as ValidationError:
        return .invalidData(validationError.message)
    default:
        return .loadingFailed(error)
    }
}
```

## Testing Strategy

### Unit Testing

1. **Service Layer**: Mock dependencies, test business logic
2. **ViewModels**: Test state transitions and error handling
3. **Utilities**: Test filtering, sorting, and validation logic

### Integration Testing

1. **Data Flow**: Test service interactions
2. **CoreData**: Test data persistence and retrieval
3. **Error Scenarios**: Test error propagation and recovery

### UI Testing

1. **Critical Paths**: Test main user workflows
2. **Error States**: Test error UI and recovery
3. **Performance**: Test with large datasets

## Performance Considerations

### Optimization Strategies

1. **Background Processing**: Heavy operations on background queues
2. **Debouncing**: Prevent excessive filter/search operations
3. **Lazy Loading**: Load data progressively
4. **Memory Management**: Proper cleanup and weak references
5. **Caching**: Cache filtered results for common queries

### Performance Metrics

- List loading: < 500ms for typical datasets
- Filter application: < 200ms
- Scroll performance: 60fps maintained
- Memory usage: < 50MB for 1000 expenses
- Battery impact: Minimal background processing

## Migration Strategy

### Phase 1: Foundation Services (Week 1-2)
- Create ExpenseDataService with NSFetchedResultsController
- Implement ExpenseFilterService and ExpenseSortService
- Add comprehensive error handling
- Create unit tests for all services

### Phase 2: ExpenseDetailView Migration (Week 3)
- Create ExpenseDetailViewModel with state machine
- Migrate ExpenseDetailView to use new ViewModel
- Add error states and recovery mechanisms
- Test all detail view scenarios

### Phase 3: ExpenseListView Migration (Week 4)
- Create new ExpenseListViewModel using services
- Implement debounced filtering and sorting
- Migrate ExpenseListView to new architecture
- Performance testing and optimization

### Phase 4: Integration and Cleanup (Week 5)
- Integration testing of all components
- Remove deprecated code
- Performance optimization
- Documentation updates

## Risk Mitigation

### Technical Risks

1. **Data Migration**: Gradual migration with fallback mechanisms
2. **Performance Regression**: Continuous performance monitoring
3. **Breaking Changes**: Maintain API compatibility during transition
4. **Memory Leaks**: Comprehensive memory testing

### Mitigation Strategies

1. **Feature Flags**: Enable/disable new architecture components
2. **A/B Testing**: Gradual rollout to subset of users
3. **Monitoring**: Real-time error tracking and performance metrics
4. **Rollback Plan**: Quick revert to previous implementation if needed

## Success Metrics

### Stability Metrics
- Crash rate: < 0.1% (target: 0.01%)
- Error rate: < 1% of operations
- Data consistency: 100% across views

### Performance Metrics
- List load time: < 500ms (95th percentile)
- Filter response: < 200ms (95th percentile)
- Memory usage: < 50MB for typical usage
- Battery impact: < 5% increase

### User Experience Metrics
- User satisfaction: > 4.5/5 for expense management
- Task completion rate: > 95% for common operations
- Support tickets: < 50% reduction in expense-related issues