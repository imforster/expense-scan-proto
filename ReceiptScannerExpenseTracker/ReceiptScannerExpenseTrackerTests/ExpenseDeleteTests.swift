import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseDeleteTests: XCTestCase {
    var context: NSManagedObjectContext!
    var persistentContainer: NSPersistentContainer!
    
    override func setUp() {
        super.setUp()
        
        // Set up in-memory Core Data stack for testing
        persistentContainer = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
    }
    
    override func tearDown() {
        context = nil
        persistentContainer = nil
        super.tearDown()
    }
    
    // MARK: - Basic Delete Tests
    
    func testDeleteSingleExpense() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        let initialCount = getExpenseCount()
        XCTAssertEqual(initialCount, 1)
        
        // When
        let listViewModel = ExpenseListViewModel()
        listViewModel.deleteExpense(expense)
        
        // Then
        let finalCount = getExpenseCount()
        XCTAssertEqual(finalCount, 0)
        XCTAssertNil(listViewModel.errorMessage)
    }
    
    func testDeleteExpenseDoesNotHang() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        let listViewModel = ExpenseListViewModel()
        
        // When - Measure execution time to ensure it doesn't hang
        let startTime = CFAbsoluteTimeGetCurrent()
        listViewModel.deleteExpense(expense)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should complete quickly (within 1 second)
        XCTAssertLessThan(timeElapsed, 1.0, "Delete operation took too long, possible hang detected")
        XCTAssertEqual(getExpenseCount(), 0)
    }
    
    func testDeleteMultipleExpensesSequentially() {
        // Given
        let expenses = (0..<5).map { i in
            createTestExpense(merchant: "Merchant \(i)", amount: "10.00")
        }
        XCTAssertEqual(getExpenseCount(), 5)
        
        let listViewModel = ExpenseListViewModel()
        
        // When - Delete expenses one by one
        let startTime = CFAbsoluteTimeGetCurrent()
        for expense in expenses {
            listViewModel.deleteExpense(expense)
        }
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then
        XCTAssertEqual(getExpenseCount(), 0)
        XCTAssertLessThan(timeElapsed, 2.0, "Sequential deletes took too long")
        XCTAssertNil(listViewModel.errorMessage)
    }
    
    // MARK: - Delete with Relationships Tests
    
    func testDeleteExpenseWithCascadeRelationships() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "50.00")
        
        // Add expense items (cascade delete)
        let item1 = ExpenseItem(context: context)
        item1.id = UUID()
        item1.name = "Item 1"
        item1.amount = NSDecimalNumber(string: "25.00")
        expense.addToItems(item1)
        
        let item2 = ExpenseItem(context: context)
        item2.id = UUID()
        item2.name = "Item 2"
        item2.amount = NSDecimalNumber(string: "25.00")
        expense.addToItems(item2)
        
        // Add receipt (cascade delete)
        let receipt = Receipt(context: context)
        receipt.id = UUID()
        receipt.merchantName = "Test Merchant"
        receipt.totalAmount = NSDecimalNumber(string: "50.00")
        receipt.date = Date()
        receipt.dateProcessed = Date()
        receipt.imageURL = URL(string: "file://test.jpg")!
        expense.receipt = receipt
        
        try! context.save()
        
        XCTAssertEqual(getExpenseCount(), 1)
        XCTAssertEqual(getExpenseItemCount(), 2)
        XCTAssertEqual(getReceiptCount(), 1)
        
        // When
        let listViewModel = ExpenseListViewModel()
        listViewModel.deleteExpense(expense)
        
        // Then - Cascade deletes should work
        XCTAssertEqual(getExpenseCount(), 0)
        XCTAssertEqual(getExpenseItemCount(), 0) // Should be cascade deleted
        XCTAssertEqual(getReceiptCount(), 0) // Should be cascade deleted
    }
    
    func testDeleteExpenseWithNullifyRelationships() {
        // Given
        let category = createTestCategory(name: "Test Category")
        let tag = createTestTag(name: "Test Tag")
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        
        // Set nullify relationships
        expense.category = category
        expense.addToTags(tag)
        
        try! context.save()
        
        XCTAssertEqual(getExpenseCount(), 1)
        XCTAssertEqual(getCategoryCount(), 1)
        XCTAssertEqual(getTagCount(), 1)
        
        // When
        let listViewModel = ExpenseListViewModel()
        listViewModel.deleteExpense(expense)
        
        // Then - Nullify relationships should preserve related objects
        XCTAssertEqual(getExpenseCount(), 0)
        XCTAssertEqual(getCategoryCount(), 1) // Should still exist
        XCTAssertEqual(getTagCount(), 1) // Should still exist
        
        // Verify relationships are nullified
        XCTAssertTrue(category.expenses?.count == 0)
        XCTAssertTrue(tag.expenses?.count == 0)
    }
    
    // MARK: - Performance Tests
    
    func testDeletePerformanceWithLargeDataset() {
        // Given - Create 100 expenses with relationships
        var expenses: [Expense] = []
        for i in 0..<100 {
            let expense = createTestExpense(merchant: "Merchant \(i)", amount: "10.00")
            
            // Add some expense items
            let item = ExpenseItem(context: context)
            item.id = UUID()
            item.name = "Item \(i)"
            item.amount = NSDecimalNumber(string: "5.00")
            expense.addToItems(item)
            
            expenses.append(expense)
        }
        try! context.save()
        
        XCTAssertEqual(getExpenseCount(), 100)
        XCTAssertEqual(getExpenseItemCount(), 100)
        
        let listViewModel = ExpenseListViewModel()
        
        // When - Delete first 10 expenses and measure performance
        measure {
            for expense in expenses.prefix(10) {
                listViewModel.deleteExpense(expense)
            }
        }
        
        // Then
        XCTAssertEqual(getExpenseCount(), 90)
        XCTAssertEqual(getExpenseItemCount(), 90)
    }
    
    func testConcurrentDeleteOperations() {
        // Given
        let expenses = (0..<20).map { i in
            createTestExpense(merchant: "Merchant \(i)", amount: "10.00")
        }
        try! context.save()
        
        let listViewModel = ExpenseListViewModel()
        let expectation = XCTestExpectation(description: "All deletes complete")
        expectation.expectedFulfillmentCount = expenses.count
        
        // When - Simulate rapid delete operations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for expense in expenses {
            DispatchQueue.main.async {
                listViewModel.deleteExpense(expense)
                expectation.fulfill()
            }
        }
        
        // Then
        wait(for: [expectation], timeout: 10.0)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 5.0, "Concurrent deletes took too long")
        XCTAssertEqual(getExpenseCount(), 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testDeleteWithInvalidExpense() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        let listViewModel = ExpenseListViewModel()
        
        // Delete the expense directly from context (simulating it being deleted elsewhere)
        context.delete(expense)
        try! context.save()
        
        // When - Try to delete the already deleted expense
        listViewModel.deleteExpense(expense)
        
        // Then - Should handle gracefully
        XCTAssertNotNil(listViewModel.errorMessage)
        XCTAssertTrue(listViewModel.errorMessage?.contains("Failed to delete expense") == true)
    }
    
    func testDeleteWithContextSaveFailure() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        
        // Create a mock context that will fail on save
        let mockContext = MockFailingContext(concurrencyType: .mainQueueConcurrencyType)
        mockContext.persistentStoreCoordinator = context.persistentStoreCoordinator
        
        // Move expense to mock context
        let expenseInMockContext = mockContext.object(with: expense.objectID) as! Expense
        
        let listViewModel = ExpenseListViewModel()
        
        // When
        listViewModel.deleteExpense(expenseInMockContext)
        
        // Then
        XCTAssertNotNil(listViewModel.errorMessage)
        XCTAssertTrue(listViewModel.errorMessage?.contains("Failed to delete expense") == true)
    }
    
    // MARK: - Threading Tests
    
    func testDeleteOnMainThread() {
        // Given
        let expense = createTestExpense(merchant: "Test Merchant", amount: "25.99")
        let listViewModel = ExpenseListViewModel()
        
        var isMainThread = false
        
        // When
        listViewModel.deleteExpense(expense)
        
        // Verify we're still on main thread after delete
        DispatchQueue.main.sync {
            isMainThread = Thread.isMainThread
        }
        
        // Then
        XCTAssertTrue(isMainThread, "Delete operation should complete on main thread")
        XCTAssertEqual(getExpenseCount(), 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense(merchant: String, amount: String) -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.merchant = merchant
        expense.amount = NSDecimalNumber(string: amount)
        expense.date = Date()
        expense.notes = "Test expense"
        expense.paymentMethod = "Credit Card"
        expense.isRecurring = false
        
        try! context.save()
        return expense
    }
    
    private func createTestCategory(name: String) -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: context)
        category.id = UUID()
        category.name = name
        category.colorHex = "FF0000"
        category.icon = "tag.fill"
        category.isDefault = false
        
        try! context.save()
        return category
    }
    
    private func createTestTag(name: String) -> Tag {
        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        
        try! context.save()
        return tag
    }
    
    private func getExpenseCount() -> Int {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        return (try? context.fetch(request).count) ?? 0
    }
    
    private func getExpenseItemCount() -> Int {
        let request: NSFetchRequest<ExpenseItem> = ExpenseItem.fetchRequest()
        return (try? context.fetch(request).count) ?? 0
    }
    
    private func getReceiptCount() -> Int {
        let request: NSFetchRequest<Receipt> = Receipt.fetchRequest()
        return (try? context.fetch(request).count) ?? 0
    }
    
    private func getCategoryCount() -> Int {
        let request: NSFetchRequest<ReceiptScannerExpenseTracker.Category> = ReceiptScannerExpenseTracker.Category.fetchRequest()
        return (try? context.fetch(request).count) ?? 0
    }
    
    private func getTagCount() -> Int {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        return (try? context.fetch(request).count) ?? 0
    }
}

// MARK: - Mock Failing Context

class MockFailingContext: NSManagedObjectContext {
    override func save() throws {
        throw NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock save failure"])
    }
}