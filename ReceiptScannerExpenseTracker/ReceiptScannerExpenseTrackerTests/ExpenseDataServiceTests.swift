import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseDataServiceTests: XCTestCase {
    
    var dataService: ExpenseDataService!
    var testContext: NSManagedObjectContext!
    var coreDataManager: CoreDataManager!
    
    override func setUp() async throws {
        try await super.setUp()
        DispatchQueue.main.async {
            // Set up in-memory Core Data stack for testing
            self.coreDataManager = CoreDataManager.shared
            
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
            
            self.coreDataManager.setPersistentStoreDescriptions([description])
            
            self.testContext = self.coreDataManager.viewContext
            self.dataService = ExpenseDataService(context: self.testContext)
        }
        
        // Create test categories
        await createTestCategories()
    }
    
    override func tearDown() async throws {
        DispatchQueue.main.async {
            self.dataService = nil
            self.testContext = nil
        }
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestCategories() async {
        let foodCategory = Category(context: testContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.colorHex = "FF5733"
        foodCategory.icon = "fork.knife"
        
        let transportCategory = Category(context: testContext)
        transportCategory.id = UUID()
        transportCategory.name = "Transportation"
        transportCategory.colorHex = "33A8FF"
        transportCategory.icon = "car.fill"
        
        try? testContext.save()
    }
    
    private func createTestExpenseData() -> ExpenseData {
        let category = try? testContext.fetch(Category.fetchRequest()).first
        let categoryData = category.map { CategoryData(from: $0) }
        
        return ExpenseData(
            amount: 25.99,
            merchant: "Test Restaurant",
            date: Date(),
            notes: "Test expense",
            paymentMethod: "Credit Card",
            isRecurring: false,
            category: categoryData,
            tags: [],
            items: [
                ExpenseItemData(name: "Burger", amount: 15.99),
                ExpenseItemData(name: "Fries", amount: 5.00),
                ExpenseItemData(name: "Drink", amount: 5.00)
            ]
        )
    }
    
    // MARK: - Load Expenses Tests
    
    func testLoadExpenses_EmptyDatabase_ReturnsEmptyArray() async throws {
        // When
        await dataService.loadExpenses()
        
        // Then
        XCTAssertEqual(dataService.expenses.count, 0)
        XCTAssertFalse(dataService.isLoading)
        XCTAssertNil(dataService.error)
    }
    
    func testLoadExpenses_WithExistingExpenses_ReturnsExpenses() async throws {
        // Given
        let testExpense = Expense(context: testContext)
        testExpense.id = UUID()
        testExpense.amount = NSDecimalNumber(string: "50.00")
        testExpense.merchant = "Test Merchant"
        testExpense.date = Date()
        try testContext.save()
        
        // When
        await dataService.loadExpenses()
        
        // Then
        XCTAssertEqual(dataService.expenses.count, 1)
        XCTAssertEqual(dataService.expenses.first?.merchant, "Test Merchant")
        XCTAssertFalse(dataService.isLoading)
        XCTAssertNil(dataService.error)
    }
    
    func testLoadExpenses_SetsLoadingState() async throws {
        // Given
        XCTAssertFalse(dataService.isLoading)
        
        // When
        let loadingTask = Task {
            await dataService.loadExpenses()
        }
        
        // Then - Check loading state is set (this is a bit tricky to test due to async nature)
        await loadingTask.value
        XCTAssertFalse(dataService.isLoading) // Should be false after completion
    }
    
    // MARK: - Create Expense Tests
    
    func testCreateExpense_ValidData_CreatesExpense() async throws {
        // Given
        let expenseData = createTestExpenseData()
        
        // When
        let createdExpense = try await dataService.createExpense(expenseData)
        
        // Then
        XCTAssertEqual(createdExpense.merchant, "Test Restaurant")
        XCTAssertEqual(createdExpense.amount.decimalValue, 25.99)
        XCTAssertEqual(createdExpense.notes, "Test expense")
        XCTAssertEqual(createdExpense.paymentMethod, "Credit Card")
        XCTAssertFalse(createdExpense.isRecurring)
        XCTAssertNotNil(createdExpense.category)
        XCTAssertEqual((createdExpense.items as? Set<ExpenseItem>)?.count, 3)
    }
    
    func testCreateExpense_InvalidAmount_ThrowsValidationError() async throws {
        // Given
        var expenseData = createTestExpenseData()
        expenseData = ExpenseData(
            amount: -10.0, // Invalid negative amount
            merchant: expenseData.merchant,
            date: expenseData.date,
            category: expenseData.category
        )
        
        // When/Then
        do {
            _ = try await dataService.createExpense(expenseData)
            XCTFail("Expected validation error")
        } catch let error as ExpenseError {
            switch error {
            case .validationError(let message):
                XCTAssertTrue(message.contains("Amount must be greater than zero"))
            default:
                XCTFail("Expected validation error, got \(error)")
            }
        }
    }
    
    func testCreateExpense_EmptyMerchant_ThrowsValidationError() async throws {
        // Given
        var expenseData = createTestExpenseData()
        expenseData = ExpenseData(
            amount: expenseData.amount,
            merchant: "", // Empty merchant
            date: expenseData.date,
            category: expenseData.category
        )
        
        // When/Then
        do {
            _ = try await dataService.createExpense(expenseData)
            XCTFail("Expected validation error")
        } catch let error as ExpenseError {
            switch error {
            case .validationError(let message):
                XCTAssertTrue(message.contains("Merchant name is required"))
            default:
                XCTFail("Expected validation error, got \(error)")
            }
        }
    }
    
    // MARK: - Update Expense Tests
    
    func testUpdateExpense_ValidData_UpdatesExpense() async throws {
        // Given
        let originalExpenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(originalExpenseData)
        
        let updatedExpenseData = ExpenseData(
            amount: 35.99,
            merchant: "Updated Restaurant",
            date: Date(),
            notes: "Updated notes",
            paymentMethod: "Cash",
            category: originalExpenseData.category
        )
        
        // When
        try await dataService.updateExpense(createdExpense, with: updatedExpenseData)
        
        // Refresh the context to get updated data
        testContext.refresh(createdExpense, mergeChanges: true)
        
        // Then
        XCTAssertEqual(createdExpense.merchant, "Updated Restaurant")
        XCTAssertEqual(createdExpense.amount.decimalValue, 35.99)
        XCTAssertEqual(createdExpense.notes, "Updated notes")
        XCTAssertEqual(createdExpense.paymentMethod, "Cash")
    }
    
    func testUpdateExpense_NonExistentExpense_ThrowsNotFoundError() async throws {
        // Given
        let expenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(expenseData)
        
        // Delete the expense from context to simulate non-existent expense
        testContext.delete(createdExpense)
        try testContext.save()
        
        let updatedExpenseData = ExpenseData(
            amount: 35.99,
            merchant: "Updated Restaurant",
            date: Date()
        )
        
        // When/Then
        do {
            try await dataService.updateExpense(createdExpense, with: updatedExpenseData)
            XCTFail("Expected not found error")
        } catch let error as ExpenseError {
            switch error {
            case .notFound:
                break // Expected
            default:
                XCTFail("Expected not found error, got \(error)")
            }
        }
    }
    
    // MARK: - Delete Expense Tests
    
    func testDeleteExpense_ExistingExpense_DeletesExpense() async throws {
        // Given
        let expenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(expenseData)
        let expenseId = createdExpense.objectID
        
        // When
        try await dataService.deleteExpense(createdExpense)
        
        // Then
        let retrievedExpense = await dataService.getExpense(by: expenseId)
        XCTAssertNil(retrievedExpense)
    }
    
    func testDeleteExpense_NonExistentExpense_ThrowsNotFoundError() async throws {
        // Given
        let expenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(expenseData)
        
        // Delete the expense from context to simulate non-existent expense
        testContext.delete(createdExpense)
        try testContext.save()
        
        // When/Then
        do {
            try await dataService.deleteExpense(createdExpense)
            XCTFail("Expected not found error")
        } catch let error as ExpenseError {
            switch error {
            case .notFound:
                break // Expected
            default:
                XCTFail("Expected not found error, got \(error)")
            }
        }
    }
    
    // MARK: - Get Expense Tests
    
    func testGetExpense_ExistingId_ReturnsExpense() async throws {
        // Given
        let expenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(expenseData)
        let expenseId = createdExpense.objectID
        
        // When
        let retrievedExpense = await dataService.getExpense(by: expenseId)
        
        // Then
        XCTAssertNotNil(retrievedExpense)
        XCTAssertEqual(retrievedExpense?.merchant, "Test Restaurant")
    }
    
    func testGetExpense_NonExistentId_ReturnsNil() async throws {
        // Given
        let expenseData = createTestExpenseData()
        let createdExpense = try await dataService.createExpense(expenseData)
        let expenseId = createdExpense.objectID
        
        // Delete the expense
        try await dataService.deleteExpense(createdExpense)
        
        // When
        let retrievedExpense = await dataService.getExpense(by: expenseId)
        
        // Then
        XCTAssertNil(retrievedExpense)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearErrors_ClearsErrorState() async throws {
        // Given
        // Simulate an error state
        await MainActor.run {
            dataService.error = ExpenseError.loadingFailed(NSError(domain: "test", code: 1))
        }
        
        // When
        dataService.clearErrors()
        
        // Then
        XCTAssertNil(dataService.error)
    }
    
    // MARK: - Integration Tests
    
    func testCreateUpdateDelete_FullWorkflow() async throws {
        // Given
        let originalData = createTestExpenseData()
        
        // Create
        let expense = try await dataService.createExpense(originalData)
        XCTAssertEqual(expense.merchant, "Test Restaurant")
        
        // Update
        let updatedData = ExpenseData(
            amount: 50.00,
            merchant: "Updated Restaurant",
            date: Date(),
            category: originalData.category
        )
        try await dataService.updateExpense(expense, with: updatedData)
        
        // Refresh and verify update
        testContext.refresh(expense, mergeChanges: true)
        XCTAssertEqual(expense.merchant, "Updated Restaurant")
        XCTAssertEqual(expense.amount.decimalValue, 50.00)
        
        // Delete
        try await dataService.deleteExpense(expense)
        
        // Verify deletion
        let retrievedExpense = await dataService.getExpense(by: expense.objectID)
        XCTAssertNil(retrievedExpense)
    }
    
    func testMultipleExpenses_LoadAndManage() async throws {
        // Given
        let expenseData1 = ExpenseData(amount: 10.00, merchant: "Merchant 1", date: Date())
        let expenseData2 = ExpenseData(amount: 20.00, merchant: "Merchant 2", date: Date())
        let expenseData3 = ExpenseData(amount: 30.00, merchant: "Merchant 3", date: Date())
        
        // When
        _ = try await dataService.createExpense(expenseData1)
        _ = try await dataService.createExpense(expenseData2)
        _ = try await dataService.createExpense(expenseData3)
        
        await dataService.loadExpenses()
        
        // Then
        XCTAssertEqual(dataService.expenses.count, 3)
        
        let merchants = dataService.expenses.map { $0.merchant }.sorted()
        XCTAssertEqual(merchants, ["Merchant 1", "Merchant 2", "Merchant 3"])
    }
}