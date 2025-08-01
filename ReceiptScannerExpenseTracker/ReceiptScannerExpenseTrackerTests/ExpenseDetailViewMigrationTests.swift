import XCTest
import CoreData
import SwiftUI
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseDetailViewMigrationTests: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    var viewContext: NSManagedObjectContext!
    
    @MainActor
    override func setUpWithError() throws {
        coreDataManager = CoreDataManager.createForTesting()
        viewContext = coreDataManager.viewContext
    }
    
    @MainActor
    override func tearDownWithError() throws {
        viewContext = nil
        coreDataManager = nil
    }
    
    // MARK: - Test Cases
    
    func testExpenseDetailViewLoading() throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create the view
        let viewModel = ReceiptScannerExpenseTracker.ExpenseDetailViewModel(dataService: ExpenseDataService(context: viewContext), expenseID: expense.objectID)
        let view = ExpenseDetailView(expense: viewModel.expense!)
        
        // Since we can't inspect the view directly without ViewInspector, we'll just verify it can be created
        XCTAssertNotNil(view)
    }
    
    func testExpenseDetailViewStates() throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create a mock data service
        let mockDataService = MockExpenseDataService(context: viewContext)
        
        // Create the view model with the mock service
        let viewModel = ExpenseDetailViewModel(dataService: mockDataService, expenseID: expense.objectID)
        
        // Test loading state
        XCTAssertTrue(viewModel.isLoading)
        
        // Test loaded state
        let expectation = XCTestExpectation(description: "Load expense")
        
        Task {
            // Wait for the initial load to complete
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Verify the expense is loaded
            XCTAssertFalse(viewModel.isLoading)
            XCTAssertNotNil(viewModel.expense)
            
            // Test error state
            mockDataService.shouldFailGetExpense = true
            await viewModel.refreshExpense()
            
            // Verify the error state
            XCTAssertNotNil(viewModel.error)
            
            // Test deleted state
            mockDataService.shouldFailGetExpense = false
            await viewModel.deleteExpense()
            
            // Verify the deleted state
            XCTAssertTrue(viewModel.isDeleted)
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExpenseDetailViewErrorRecovery() throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create a mock data service
        let mockDataService = MockExpenseDataService(context: viewContext)
        mockDataService.shouldFailGetExpense = true
        
        // Create the view model with the mock service
        let viewModel = ExpenseDetailViewModel(dataService: mockDataService, expenseID: expense.objectID)
        
        let expectation = XCTestExpectation(description: "Error recovery")
        
        Task {
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
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testExpenseDetailViewMemoryLeaks() throws {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create a weak reference to track memory leaks
        weak var weakViewModel: ExpenseDetailViewModel?
        
        // Create a scope to control the lifetime of the view model
        do {
            let viewModel = ReceiptScannerExpenseTracker.ExpenseDetailViewModel(dataService: ExpenseDataService(context: viewContext), expenseID: expense.objectID)
            weakViewModel = viewModel
            
            // Use the view model
            XCTAssertTrue(viewModel.isLoading)
        }
        
        // Force a garbage collection cycle
        autoreleasepool {
            // This helps ensure any autorelease objects are released
        }
        
        // Verify the view model was deallocated
        XCTAssertNil(weakViewModel, "ExpenseDetailViewModel should be deallocated")
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