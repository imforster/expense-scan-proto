import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class CrossContextFixTest: XCTestCase {
    
    func testCrossContextCategoryFix() {
        // This test verifies that our fix for cross-context relationships works correctly
        
        // 1. Create two separate contexts with the same persistent store coordinator
        let container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load store: \(error)")
            }
        }
        
        let context1 = container.viewContext
        let context2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context2.persistentStoreCoordinator = container.persistentStoreCoordinator
        
        // 2. Create a category in context1
        let category = ReceiptScannerExpenseTracker.Category(context: context1)
        category.id = UUID()
        category.name = "Test Category"
        category.colorHex = "FF5733"
        category.icon = "tag.fill"
        category.isDefault = false
        
        try! context1.save()
        
        // 3. Create an expense in context2 and try to assign the category from context1
        let expense = Expense(context: context2)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        
        // 4. Create a view model with context2 and try to save with category from context1
        let viewModel = ExpenseEditViewModel(context: context2)
        viewModel.amount = "42.99"
        viewModel.merchant = "Test Merchant"
        viewModel.selectedCategory = category // This is from context1
        
        // 5. This would have failed before our fix, but should work now
        let expectation = XCTestExpectation(description: "Save expense with cross-context category")
        
        Task {
            do {
                try await viewModel.saveExpense()
                
                // 6. Verify the expense was saved with the correct category
                let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                let expenses = try context2.fetch(fetchRequest)
                
                XCTAssertEqual(expenses.count, 1)
                let savedExpense = expenses.first!
                
                // The category should be set and have the same ID as our original category
                XCTAssertNotNil(savedExpense.category)
                XCTAssertEqual(savedExpense.category?.id, category.id)
                XCTAssertEqual(savedExpense.category?.name, "Test Category")
                
                // The contexts should be different
                XCTAssertNotEqual(
                    savedExpense.managedObjectContext,
                    category.managedObjectContext
                )
                
                expectation.fulfill()
            } catch {
                XCTFail("Failed to save expense with cross-context category: \(error)")
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}