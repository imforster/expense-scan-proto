import XCTest
import CoreData
import Combine
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseDetailViewModelTests: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    var viewContext: NSManagedObjectContext!
    var dataService: ExpenseDataService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUpWithError() throws {
        coreDataManager = CoreDataManager.createForTesting()
        viewContext = coreDataManager.viewContext
        dataService = ExpenseDataService(context: viewContext)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDownWithError() throws {
        cancellables = nil
        dataService = nil
        viewContext = nil
        coreDataManager = nil
    }
    
    // MARK: - Test Cases
    
    func testInitialLoadingState() throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view model
        let viewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Initially, the view model should be in loading state
        XCTAssertTrue(viewModel.isLoading)
    }
    
    func testLoadExpenseSuccess() async throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view model
        let viewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Wait for the initial load to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify the expense is loaded
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.expense)
        XCTAssertEqual(viewModel.expense?.objectID, expense.objectID)
    }
    
    func testLoadExpenseNotFound() async throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Delete the expense
        viewContext.delete(expense)
        try viewContext.save()
        
        // Create the view model with the deleted expense's ID
        let viewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Wait for the initial load to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify the error state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.expense)
        XCTAssertNotNil(viewModel.error)
        XCTAssertEqual(viewModel.error as? ExpenseError, ExpenseError.notFound)
    }
    
    func testDeleteExpense() async throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view model
        let viewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Wait for the initial load to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Delete the expense
        await viewModel.deleteExpense()
        
        // Verify the deleted state
        XCTAssertTrue(viewModel.isDeleted)
        XCTAssertNil(viewModel.expense)
        
        // Verify the expense is actually deleted from the context
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", expense.id as CVarArg)
        let results = try viewContext.fetch(fetchRequest)
        XCTAssertEqual(results.count, 0)
    }
    
    func testRefreshExpense() async throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view model
        let viewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Wait for the initial load to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Modify the expense in the context
        expense.merchant = "Updated Merchant"
        try viewContext.save()
        
        // Refresh the expense
        await viewModel.refreshExpense()
        
        // Verify the expense is updated
        XCTAssertEqual(viewModel.expense?.merchant, "Updated Merchant")
    }
    
    func testErrorRecovery() async throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view model with a mock data service that will fail
        let mockDataService = MockExpenseDataService(context: viewContext)
        mockDataService.shouldFailGetExpense = true
        let viewModel = ExpenseDetailViewModel(dataService: mockDataService, expenseID: expense.objectID)
        
        // Wait for the initial load to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Verify the error state
        XCTAssertNotNil(viewModel.error)
        
        // Now make the mock service succeed
        mockDataService.shouldFailGetExpense = false
        
        // Try to recover
        await viewModel.recoverFromError()
        
        // Verify recovery succeeded
        XCTAssertNil(viewModel.error)
        XCTAssertNotNil(viewModel.expense)
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense() -> Expense {
        let expense = Expense(context: viewContext)
        expense.id = UUID()
        expense.merchant = "Test Merchant"
        expense.amount = NSDecimalNumber(value: 99.99)
        expense.date = Date()
        expense.notes = "Test notes"
        expense.paymentMethod = "Credit Card"
        expense.isRecurring = false
        
        try! viewContext.save()
        
        return expense
    }
}

// MARK: - Mock ExpenseDataService

class MockExpenseDataService: ExpenseDataService {
    var shouldFailGetExpense = false
    
    override func getExpense(by id: NSManagedObjectID) async -> Expense? {
        if shouldFailGetExpense {
            return nil
        }
        return await super.getExpense(by: id)
    }
}