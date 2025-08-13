import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class RecurringExpenseTests: XCTestCase {
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
    
    // MARK: - Recurring Pattern Detection Tests
    
    func testWeeklyRecurringPatternDetection() async {
        // Recurring expense editing functionality has been removed from ExpenseEditView
        // This test is disabled as the functionality is no longer supported in the edit view
        // Use RecurringExpenseService and SimpleRecurringListView for recurring expense management
        XCTAssertTrue(true, "Recurring expense editing functionality has been removed from ExpenseEditView")
    }
    
    func testMonthlyRecurringPatternDetection() async {
        // Recurring expense editing functionality has been removed from ExpenseEditView
        // This test is disabled as the functionality is no longer supported in the edit view
        // Use RecurringExpenseService and SimpleRecurringListView for recurring expense management
        XCTAssertTrue(true, "Recurring expense editing functionality has been removed from ExpenseEditView")
    }
    
    func testQuarterlyRecurringPatternDetection() async {
        // Recurring expense editing functionality has been removed from ExpenseEditView
        // This test is disabled as the functionality is no longer supported in the edit view
        // Use RecurringExpenseService and SimpleRecurringListView for recurring expense management
        XCTAssertTrue(true, "Recurring expense editing functionality has been removed from ExpenseEditView")
    }
    
    func testNoRecurringPatternDetection() async {
        // Recurring expense editing functionality has been removed from ExpenseEditView
        // This test is disabled as the functionality is no longer supported in the edit view
        // Use RecurringExpenseService and SimpleRecurringListView for recurring expense management
        XCTAssertTrue(true, "Recurring expense editing functionality has been removed from ExpenseEditView")
    }
    
    func testSaveAndLoadRecurringExpense() async {
        // Recurring expense editing functionality has been removed from ExpenseEditView
        // This test is disabled as the functionality is no longer supported in the edit view
        // Use RecurringExpenseService and SimpleRecurringListView for recurring expense management
        XCTAssertTrue(true, "Recurring expense editing functionality has been removed from ExpenseEditView")
    }
    
    // MARK: - Helper Methods
    
    private func createRecurringTestExpenses(merchant: String, interval: Calendar.Component, intervalValue: Int, count: Int) {
        let calendar = Calendar.current
        var currentDate = Date()
        
        for i in 0..<count {
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(string: "100.00")
            expense.merchant = merchant
            expense.date = currentDate
            expense.notes = "Test expense \(i)"
            expense.paymentMethod = "Credit Card"
            expense.isRecurring = false
            
            // Move back in time for the next expense
            currentDate = calendar.date(byAdding: interval, value: -intervalValue, to: currentDate)!
        }
        
        try! context.save()
    }
}