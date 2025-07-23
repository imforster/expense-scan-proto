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
        // Create weekly recurring expenses
        createRecurringTestExpenses(merchant: "Weekly Service", interval: .day, intervalValue: 7, count: 5)
        
        viewModel.merchant = "Weekly Service"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertTrue(viewModel.isRecurring)
        XCTAssertEqual(viewModel.recurringPattern, .weekly)
        XCTAssertNotNil(viewModel.nextExpectedDate)
    }
    
    func testMonthlyRecurringPatternDetection() async {
        // Create monthly recurring expenses
        createRecurringTestExpenses(merchant: "Monthly Subscription", interval: .month, intervalValue: 1, count: 4)
        
        viewModel.merchant = "Monthly Subscription"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertTrue(viewModel.isRecurring)
        XCTAssertEqual(viewModel.recurringPattern, .monthly)
        XCTAssertNotNil(viewModel.nextExpectedDate)
    }
    
    func testQuarterlyRecurringPatternDetection() async {
        // Create quarterly recurring expenses
        createRecurringTestExpenses(merchant: "Quarterly Fee", interval: .month, intervalValue: 3, count: 4)
        
        viewModel.merchant = "Quarterly Fee"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertTrue(viewModel.isRecurring)
        XCTAssertEqual(viewModel.recurringPattern, .quarterly)
        XCTAssertNotNil(viewModel.nextExpectedDate)
    }
    
    func testNoRecurringPatternDetection() async {
        // Create random expenses with same merchant but no pattern
        let dates = [
            Date(),
            Date().addingTimeInterval(-1_000_000), // ~11.5 days ago
            Date().addingTimeInterval(-5_000_000), // ~58 days ago
            Date().addingTimeInterval(-9_000_000)  // ~104 days ago
        ]
        
        for (index, date) in dates.enumerated() {
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(string: "100.00")
            expense.merchant = "Random Store"
            expense.date = date
            expense.notes = "Test expense \(index)"
            expense.paymentMethod = "Credit Card"
            expense.isRecurring = false
        }
        
        try! context.save()
        
        viewModel.merchant = "Random Store"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertFalse(viewModel.isRecurring)
    }
    
    func testSaveAndLoadRecurringExpense() async {
        // Set up recurring expense
        viewModel.amount = "49.99"
        viewModel.merchant = "Streaming Service"
        viewModel.date = Date()
        viewModel.isRecurring = true
        viewModel.recurringPattern = .monthly
        viewModel.nextExpectedDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        
        // Save expense
        do {
            try await viewModel.saveExpense()
            
            // Fetch the saved expense
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "merchant == %@", "Streaming Service")
            let savedExpenses = try context.fetch(fetchRequest)
            
            XCTAssertEqual(savedExpenses.count, 1)
            let savedExpense = savedExpenses.first!
            
            // Verify recurring info was saved
            XCTAssertTrue(savedExpense.isRecurring)
            XCTAssertTrue(savedExpense.notes?.contains("[Recurring: Monthly]") ?? false)
            
            // Create a new view model with the saved expense
            let newViewModel = ExpenseEditViewModel(context: context, expense: savedExpense)
            
            // Verify recurring info was loaded
            XCTAssertTrue(newViewModel.isRecurring)
            XCTAssertEqual(newViewModel.recurringPattern, .monthly)
            XCTAssertNotNil(newViewModel.nextExpectedDate)
            
        } catch {
            XCTFail("Failed to save expense: \(error)")
        }
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