# Pull Request: Fix Core Data Crash in ExpenseDetailView

## 🚨 Critical Bug Fix

This PR resolves a critical Core Data crash that was preventing users from opening expense detail views. The app would crash with the error:
```
-[ReceiptScannerExpenseTrackerExpense persistentStore]: unrecognized selector sent to instance
```

## 📱 User Impact

**Before**: 
- App crashed when tapping on an expense in the list
- ExpenseDetailView showed blank screen on first load
- Sorting operations could cause crashes

**After**:
- Expense detail views load properly without crashes
- Smooth navigation between list and detail views
- Stable sorting operations

## 🔧 Technical Changes

### 1. Core Data Context Consistency
- **Problem**: ExpenseListView and ExpenseDetailView were using different Core Data contexts
- **Solution**: Modified ExpenseDetailView to accept and use the same context as ExpenseListView
- **Files**: `ExpenseDetailView.swift`, `ExpenseListView.swift`

### 2. Safe Property Access in Sorting
- **Problem**: ExpenseSortService was directly accessing Core Data properties, causing crashes when objects were faulted
- **Solution**: Replaced direct property access with safe accessor methods (`safeMerchant`, `safeCategoryName`, etc.)
- **Files**: `ExpenseSortService.swift`

### 3. Enhanced Data Loading
- **Problem**: ExpenseDetailView wasn't reliably loading data on first appearance
- **Solution**: Added `.task` modifier and improved loading logic in ExpenseDetailViewModel
- **Files**: `ExpenseDetailView.swift`, `ExpenseDetailViewModel.swift`

### 4. CoreDataManager Cleanup
- **Problem**: `registerEntityClasses()` method was trying to modify immutable Core Data model
- **Solution**: Removed the method since Core Data model already has correct class names configured
- **Files**: `CoreDataManager.swift`

### 5. Improved Error Handling
- **Problem**: Core Data object access could fail silently or crash
- **Solution**: Added proper error handling and fault management in ExpenseDataService
- **Files**: `ExpenseDataService.swift`

## 🧪 Testing

- ✅ Build succeeds without errors
- ✅ App launches without Core Data crashes  
- ✅ Expense detail views load properly when selected from list
- ✅ Sorting operations work without crashes
- ✅ Context consistency maintained throughout navigation

## 📁 Files Modified

### Core Files
- `CoreDataManager.swift` - Removed problematic registerEntityClasses()
- `ExpenseDetailView.swift` - Added context parameter and .task modifier
- `ExpenseDetailViewModel.swift` - Enhanced loading safety
- `ExpenseListView.swift` - Added context passing and refresh logic
- `ExpenseDataService.swift` - Improved error handling
- `ExpenseSortService.swift` - Safe property access

### Test Files
- `ExpenseDeleteTests.swift` - Updated for new constructor patterns
- `ExpenseEditViewModelTests.swift` - Fixed async/await compatibility

## 🎯 Commit Hash
`fe947dc6baf2d723e3b9d1fa4c16401d28d0311b`

## 🔄 Branch
`expense-list-refactor` → `main`

## ⚡ Priority
**HIGH** - This fixes a critical crash that prevents core app functionality

## 🔄 Additional Fix (Commit: 391ca68)

**Issue**: After the initial fix, a new crash occurred:
```
'An NSManagedObjectContext cannot refresh objects in other contexts.'
```

**Root Cause**: The ExpenseListView was trying to refresh expense objects with a different Core Data context than the one they belonged to.

**Solution**: 
- Removed the problematic `viewContext.refresh(expense, mergeChanges: false)` call
- Ensured both ExpenseListView and ExpenseDetailView use `CoreDataManager.shared.viewContext` consistently
- Modified both views to explicitly use the shared context for their data services

This ensures complete Core Data context consistency throughout the expense workflow.

## 🔄 Additional Fix #2 (Commit: d9d415e)

**Issue**: Another context crash occurred when saving expense edits:
```
'Illegal attempt to establish a relationship 'category' between objects in different contexts'
```

**Root Cause**: The ExpenseEditViewModel was trying to assign a category object from one Core Data context to an expense object from a different context.

**Solution**: 
- Modified ExpenseDetailView to use the expense's own context when creating ExpenseEditView
- Enhanced ExpenseEditViewModel.populateExpense() with context safety checks
- Added logic to fetch category in the correct context or create a new one if needed
- Ensured all Core Data relationship assignments happen between objects from the same context

This completes the Core Data context consistency fixes across the entire expense workflow.

---

## How to Test

1. Build and run the app
2. Navigate to the expense list
3. Tap on any expense item
4. Verify the expense detail view loads without crashing
5. Test sorting functionality in the expense list
6. Verify smooth navigation between views

## Related Issues

- Fixes: Core Data crash when opening expense details
- Fixes: Blank screen issue in ExpenseDetailView  
- Fixes: ExpenseSortService property access crashes
- Improves: Overall Core Data context safety