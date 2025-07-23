import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseContextTests: XCTestCase {
    var viewModel: ExpenseEditViewModel!
    var context: NSManagedObjectContext!
    var mockCategoryService: MockCategoryService!
    
    override func setUp() {
        super.setUp()
        
        // Set up in-memory Core Data stack for testing
        let persistentContainer = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        persistentContainer.persistentStoreDescriptions = [description]
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        context = persistentContainer.viewContext
        mockCategoryService = MockCategoryService()
        viewModel = ExpenseEditViewModel(context: context, categoryService: mockCategoryService)
    }
    
    override func tearDown() {
        viewModel = nil
        context = nil
        mockCategoryService = nil
        super.tearDown()
    }
    
    // MARK: - Expense Context Tests
    
    func testToggleExpenseContext() {
        // Given
        XCTAssertTrue(viewModel.expenseContexts.isEmpty)
        
        // When
        viewModel.toggleExpenseContext(.business)
        
        // Then
        XCTAssertEqual(viewModel.expenseContexts.count, 1)
        XCTAssertTrue(viewModel.expenseContexts.contains(.business))
        
        // When toggling again
        viewModel.toggleExpenseContext(.business)
        
        // Then
        XCTAssertEqual(viewModel.expenseContexts.count, 0)
        XCTAssertFalse(viewModel.expenseContexts.contains(.business))
    }
    
    func testMultipleExpenseContexts() {
        // When
        viewModel.toggleExpenseContext(.business)
        viewModel.toggleExpenseContext(.reimbursable)
        
        // Then
        XCTAssertEqual(viewModel.expenseContexts.count, 2)
        XCTAssertTrue(viewModel.expenseContexts.contains(.business))
        XCTAssertTrue(viewModel.expenseContexts.contains(.reimbursable))
    }
    
    func testSaveExpenseWithContexts() async {
        // Given
        viewModel.amount = "25.99"
        viewModel.merchant = "Test Merchant"
        viewModel.toggleExpenseContext(.business)
        viewModel.toggleExpenseContext(.tax)
        
        // When
        do {
            try await viewModel.saveExpense()
            
            // Then
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try context.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            
            // Verify contexts were saved in notes
            XCTAssertTrue(savedExpense.notes?.contains("[Context: Business, Tax Deductible]") ?? false)
            
        } catch {
            XCTFail("Failed to save expense: \(error)")
        }
    }
    
    func testLoadExpenseWithContexts() {
        // Given
        let expense = createTestExpense()
        expense.notes = "Test notes\n\n[Context: Business, Personal]"
        try! context.save()
        
        // When
        let loadedViewModel = ExpenseEditViewModel(context: context, expense: expense)
        
        // Then
        XCTAssertEqual(loadedViewModel.expenseContexts.count, 2)
        XCTAssertTrue(loadedViewModel.expenseContexts.contains(.business))
        XCTAssertTrue(loadedViewModel.expenseContexts.contains(.personal))
        XCTAssertEqual(loadedViewModel.notes, "Test notes") // Context tag should be removed from notes
    }
    
    func testUpdateExpenseContexts() async {
        // Given
        let expense = createTestExpense()
        expense.notes = "Test notes\n\n[Context: Business]"
        try! context.save()
        
        let loadedViewModel = ExpenseEditViewModel(context: context, expense: expense)
        
        // When
        loadedViewModel.toggleExpenseContext(.business) // Remove business
        loadedViewModel.toggleExpenseContext(.personal) // Add personal
        
        // Save the updated expense
        do {
            try await loadedViewModel.saveExpense()
            
            // Then
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try context.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            
            // Verify contexts were updated
            XCTAssertTrue(savedExpense.notes?.contains("[Context: Personal]") ?? false)
            XCTAssertFalse(savedExpense.notes?.contains("Business") ?? false)
            
        } catch {
            XCTFail("Failed to save expense: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense() -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.notes = "Test notes"
        expense.paymentMethod = "Credit Card"
        expense.isRecurring = false
        
        return expense
    }
}