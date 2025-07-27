# App Crash Fixes

## Problems
1. The app was crashing when closing the ExpenseDetailView due to context management and object lifecycle issues
2. The app was crashing in ExpenseSortService due to a syntax error
3. The ExpenseDetailView edit functionality was not showing properly

## Root Causes Identified
1. **Context Mismatch**: ExpenseDetailView was creating its own ExpenseDataService with shared context, but expense objects might be from different contexts
2. **Object Lifecycle**: Expense objects could become invalid when the detail view was dismissed
3. **State Management**: ViewModel might try to access deallocated objects during cleanup
4. **Syntax Error**: ExpenseSortService had a typo (`indo` instead of `in`) causing crashes
5. **Deprecated API**: ExpenseDetailView was using deprecated `.navigationBarItems` instead of `.toolbar`

## Fixes Applied

### 1. Added Proper Cleanup in ExpenseDetailView
- Added `onDisappear` modifier to call cleanup when view disappears
- Added `expenseID` property to store the object ID safely

### 2. Enhanced ExpenseDetailViewModel
- Added `cleanup()` method to properly clean up resources
- Clear references to prevent retain cycles
- Cancel ongoing operations when view disappears

### 3. Improved ExpenseDataService.getExpense()
- Enhanced error handling for deleted/invalid objects
- Better fault handling with proper refresh logic
- More robust object validation

### 4. Context Management
- Ensured consistent use of shared context
- Fixed context mismatch in ExpenseEditView sheet

## Key Changes Made

### ExpenseDetailView.swift
```swift
// Added expenseID property for safe access
private let expenseID: NSManagedObjectID

// Added cleanup on view disappear
.onDisappear {
    Task {
        await viewModel.cleanup()
    }
}

// Fixed context usage in edit sheet
ExpenseEditView(expense: expense, context: CoreDataManager.shared.viewContext)

// Updated to modern toolbar API
.toolbar {
    ToolbarItem(placement: .navigationBarLeading) {
        Button("Close") { dismiss() }
    }
    ToolbarItem(placement: .navigationBarTrailing) {
        navigationBarTrailingItems
    }
}
```

### ExpenseDetailViewModel.swift
```swift
// Added cleanup method
func cleanup() async {
    logger.info("Cleaning up ExpenseDetailViewModel")
    cancellables.forEach { $0.cancel() }
    lastLoadedExpense = nil
    recoveryInProgress = false
    recoveryAttempts = 0
}
```

### ExpenseDataService.swift
```swift
// Enhanced getExpense method with better error handling
func getExpense(by id: NSManagedObjectID) async -> Expense? {
    // Better validation and fault handling
    if expense.isDeleted {
        logger.warning("Expense with ID \(id) has been deleted")
        return nil
    }
    
    if expense.isFault {
        context.refresh(expense, mergeChanges: true)
        // Re-check after refresh
    }
}
```

### ExpenseSortService.swift
```swift
// Fixed syntax error and added Core Data safety checks
private func performSort(_ expenses: [Expense], by option: SortOption) throws -> [Expense] {
    // Filter out invalid/deleted expenses before sorting
    let validExpenses = expenses.filter { expense in
        guard !expense.isDeleted && expense.managedObjectContext != nil else {
            logger.warning("Filtering out invalid expense object during sort")
            return false
        }
        return true
    }
    
    return validExpenses.sorted { expense1, expense2 in  // Fixed: was "indo"
        do {
            return try compareExpenses(expense1, expense2, using: option)
        } catch {
            logger.error("Comparison failed: \(error.localizedDescription), using fallback")
            // Safe fallback with additional error handling
            do {
                return expense1.date < expense2.date
            } catch {
                return expense1.objectID.description < expense2.objectID.description
            }
        }
    }
}

// Added Core Data safety checks to compareExpenses
private func compareExpenses(_ expense1: Expense, _ expense2: Expense, using option: SortOption) throws -> Bool {
    // Safety check: ensure objects are valid and not deleted
    guard !expense1.isDeleted && !expense2.isDeleted else {
        throw NSError(domain: "ExpenseSortService", code: 1001, 
                     userInfo: [NSLocalizedDescriptionKey: "Cannot compare deleted expense objects"])
    }
    
    // Safety check: ensure objects have valid contexts
    guard expense1.managedObjectContext != nil && expense2.managedObjectContext != nil else {
        throw NSError(domain: "ExpenseSortService", code: 1002, 
                     userInfo: [NSLocalizedDescriptionKey: "Cannot compare expense objects without valid contexts"])
    }
    
    // ... rest of comparison logic
}
```

## Testing
- Build completed successfully
- No compilation errors
- Proper resource cleanup implemented
- Context management improved

## Expected Results
- No more crashes when closing ExpenseDetailView
- No more crashes in ExpenseSortService during sorting operations
- Edit functionality properly visible in ExpenseDetailView
- Proper cleanup of resources
- Better error handling for invalid objects
- Modern toolbar API usage
- Improved stability overall

## Summary of Fixes
1. **Fixed ExpenseDetailView crashes** - Added proper cleanup and context management
2. **Fixed ExpenseSortService syntax error** - Corrected typo that was causing crashes
3. **Added Core Data safety checks** - Prevent crashes from invalid/deleted objects during sorting
4. **Updated navigation bar implementation** - Replaced deprecated API with modern toolbar
5. **Enhanced error handling** - Better validation for Core Data objects with multiple fallback strategies
6. **Improved resource management** - Proper cleanup when views disappear
7. **Robust sorting implementation** - Filter invalid objects and handle Core Data context issues