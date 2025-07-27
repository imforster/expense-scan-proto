import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseContextTests: CoreDataTestCase {
    var viewModel: ExpenseEditViewModel!
    var mockCategoryService: MockCategoryService!
    
    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        mockCategoryService = MockCategoryService()
        viewModel = ExpenseEditViewModel(context: testContext, categoryService: mockCategoryService)
    }
    
    @MainActor
    override func tearDownWithError() throws {
        viewModel = nil
        mockCategoryService = nil
        try super.tearDownWithError()
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
            let expenses = try testContext.fetch(fetchRequest)
            
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
        try! testContext.save()
        
        // When
        let loadedViewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Then
        XCTAssertEqual(loadedViewModel.expenseContexts.count, 2)
        XCTAssertTrue(loadedViewModel.expenseContexts.contains(ExpenseContext.business))
        XCTAssertTrue(loadedViewModel.expenseContexts.contains(ExpenseContext.personal))
        XCTAssertEqual(loadedViewModel.notes, "Test notes") // Context tag should be removed from notes
    }
    
    func testUpdateExpenseContexts() async {
        // Given
        let expense = createTestExpense()
        expense.notes = "Test notes\n\n[Context: Business]"
        try! testContext.save()
        
        let loadedViewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // When
        loadedViewModel.toggleExpenseContext(ExpenseContext.business) // Remove business
        loadedViewModel.toggleExpenseContext(ExpenseContext.personal) // Add personal
        
        // Save the updated expense
        do {
            try await loadedViewModel.saveExpense()
            
            // Then
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try testContext.fetch(fetchRequest)
            
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
        let expense = Expense(context: testContext)
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