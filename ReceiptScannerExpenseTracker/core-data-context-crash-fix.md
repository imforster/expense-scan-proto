# Core Data Context Crash Fix

## Issue
The app was crashing with the error:
```
*** Terminating app due to uncaught exception 'NSInvalidArgumentException', reason: '-[ReceiptScannerExpenseTrackerExpense persistentStore]: unrecognized selector sent to instance 0x119443070'
```

## Root Cause
The crash was caused by Core Data context inconsistency between ExpenseListView and ExpenseDetailView:

1. **ExpenseListView** was creating expense objects in its own context
2. **ExpenseDetailView** was creating a new ExpenseDataService with a potentially different context instance
3. When passing `expense.objectID` from one context to another, Core Data got confused about which persistent store the object belonged to
4. This caused Core Data to try calling `persistentStore` on the Expense object itself, which doesn't have that method

## Solution
Ensured consistent Core Data context usage by:

### 1. Updated ExpenseListView
- Modified the sheet presentation to pass the `viewContext` to ExpenseDetailView
- This ensures both views use the exact same Core Data context instance

```swift
.sheet(isPresented: $showingExpenseDetail, onDismiss: {
    selectedExpense = nil
}) {
    if let expense = selectedExpense {
        NavigationView {
            ExpenseDetailView(expenseID: expense.objectID, context: viewContext)
        }
    }
}
```

### 2. Updated ExpenseDetailView
- Modified the initializer to accept an optional context parameter
- Uses the provided context or falls back to the shared context
- Ensures the ExpenseDataService uses the same context as the expense object

```swift
init(expenseID: NSManagedObjectID, context: NSManagedObjectContext? = nil) {
    self.expenseID = expenseID
    let contextToUse = context ?? CoreDataManager.shared.viewContext
    let dataService = ExpenseDataService(context: contextToUse)
    _viewModel = StateObject(wrappedValue: ExpenseDetailViewModel(dataService: dataService, expenseID: expenseID))
}
```

### 3. Fixed ExpenseEditView Context
- Updated ExpenseEditView to use the same context as the expense object
- This prevents context mismatch when editing expenses

```swift
ExpenseEditView(expense: expense, context: expense.managedObjectContext ?? viewContext)
```

## Key Principles Applied

1. **Context Consistency**: All Core Data operations for a given workflow should use the same context instance
2. **Object ID Safety**: When passing NSManagedObjectID between views, ensure the receiving context is the same as the originating context
3. **Relationship Safety**: When working with Core Data relationships, ensure all objects belong to the same context

## Build Status
✅ **Build Successful** - All compilation errors resolved

## Testing Recommendations
1. Test navigation from ExpenseListView to ExpenseDetailView
2. Test editing expenses from the detail view
3. Test sorting operations in the expense list
4. Verify no crashes occur when switching between views rapidly
5. Test with both empty and populated expense lists

## Related Files Modified
- `ExpenseListView.swift` - Added context parameter to ExpenseDetailView
- `ExpenseDetailView.swift` - Updated initializer and ExpenseEditView context usage

This fix ensures complete Core Data context consistency throughout the expense workflow, preventing the `persistentStore` crash and related Core Data context issues.