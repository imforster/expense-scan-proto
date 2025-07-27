import XCTest
import CoreData
import Combine
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseEditToListUpdateTest: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    var viewContext: NSManagedObjectContext!
    var dataService: ExpenseDataService!
    var listViewModel: ExpenseListViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up in-memory Core Data stack for testing
        coreDataManager = CoreDataManager.createForTesting()
        viewContext = coreDataManager.viewContext
        
        // Initialize services
        dataService = ExpenseDataService(context: viewContext)
        listViewModel = ExpenseListViewModel(dataService: dataService)
        cancellables = Set<AnyCancellable>()
        
        // Create test category
        await createTestCategory()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        listViewModel = nil
        dataService = nil
        viewContext = nil
        coreDataManager = nil
        try await super.tearDown()
    }
    
    private func createTestCategory() async {
        let category = ReceiptScannerExpenseTracker.Category(context: viewContext)
        category.id = UUID()
        category.name = "Food"
        category.colorHex = "FF5733"
        category.icon = "fork.knife"
        category.isDefault = true
        
        try? viewContext.save()
    }
    
    func testExpenseEditUpdatesListView() async throws {
        // 1. Create initial expense
        let initialExpenseData = ExpenseData(
            amount: 25.99,
            merchant: "Original Restaurant",
            date: Date(),
            notes: "Original notes",
            paymentMethod: "Credit Card",
            isRecurring: false,
            category: nil,
            tags: [],
            items: []
        )
        
        let createdExpense = try await dataService.createExpense(initialExpenseData)
        
        // 2. Load expenses in list view model
        await listViewModel.loadExpenses()
        
        // Wait for data to load
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify initial state
        XCTAssertEqual(listViewModel.displayedExpenses.count, 1)
        XCTAssertEqual(listViewModel.displayedExpenses.first?.merchant, "Original Restaurant")
        XCTAssertEqual(listViewModel.displayedExpenses.first?.amount.decimalValue, 25.99)
        
        // 3. Simulate expense edit (like ExpenseEditView would do)
        let editViewModel = ExpenseEditViewModel(context: viewContext, expense: createdExpense)
        
        // Update the expense data
        editViewModel.merchant = "Updated Restaurant"
        editViewModel.amount = "35.99"
        editViewModel.notes = "Updated notes"
        
        // Save the expense (this simulates what happens when user taps Save)
        try await editViewModel.saveExpense()
        
        // Post notification (this simulates what ExpenseEditView does)
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        
        // 4. Wait for the notification to be processed
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // 5. Verify that the list view model reflects the changes
        XCTAssertEqual(listViewModel.displayedExpenses.count, 1, "Should still have 1 expense")
        
        let updatedExpense = listViewModel.displayedExpenses.first
        XCTAssertNotNil(updatedExpense, "Updated expense should exist")
        XCTAssertEqual(updatedExpense?.merchant, "Updated Restaurant", "Merchant should be updated")
        XCTAssertEqual(updatedExpense?.amount.decimalValue, 35.99, "Amount should be updated")
        XCTAssertEqual(updatedExpense?.notes, "Updated notes", "Notes should be updated")
    }
    
    func testExpenseEditWithCategoryUpdatesListView() async throws {
        // Get the test category
        let fetchRequest: NSFetchRequest<ReceiptScannerExpenseTracker.Category> = ReceiptScannerExpenseTracker.Category.fetchRequest()
        let category = try viewContext.fetch(fetchRequest).first!
        
        // 1. Create initial expense without category
        let initialExpenseData = ExpenseData(
            amount: 45.00,
            merchant: "Test Merchant",
            date: Date(),
            category: nil
        )
        
        let createdExpense = try await dataService.createExpense(initialExpenseData)
        
        // 2. Load expenses in list view model
        await listViewModel.loadExpenses()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify initial state (no category)
        XCTAssertEqual(listViewModel.displayedExpenses.count, 1)
        XCTAssertNil(listViewModel.displayedExpenses.first?.category)
        
        // 3. Simulate expense edit with category assignment
        let editViewModel = ExpenseEditViewModel(context: viewContext, expense: createdExpense)
        editViewModel.selectedCategory = category
        
        // Save the expense
        try await editViewModel.saveExpense()
        
        // Post notification
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        
        // 4. Wait for the notification to be processed
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // 5. Verify that the list view model reflects the category change
        let updatedExpense = listViewModel.displayedExpenses.first
        XCTAssertNotNil(updatedExpense?.category, "Category should be assigned")
        XCTAssertEqual(updatedExpense?.category?.name, "Food", "Category should be Food")
    }
    
    func testMultipleExpenseEditsUpdateListView() async throws {
        // 1. Create multiple expenses
        let expenses = try await createMultipleTestExpenses(count: 3)
        
        // 2. Load expenses in list view model
        await listViewModel.loadExpenses()
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify initial state
        XCTAssertEqual(listViewModel.displayedExpenses.count, 3)
        
        // 3. Edit each expense
        for (index, expense) in expenses.enumerated() {
            let editViewModel = ExpenseEditViewModel(context: viewContext, expense: expense)
            editViewModel.merchant = "Updated Merchant \(index)"
            editViewModel.amount = "\(50.0 + Double(index * 10))"
            
            try await editViewModel.saveExpense()
            NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
            
            // Small delay between edits
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // 4. Wait for all updates to propagate
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // 5. Verify all changes are reflected
        XCTAssertEqual(listViewModel.displayedExpenses.count, 3)
        
        let sortedExpenses = listViewModel.displayedExpenses.sorted { $0.merchant < $1.merchant }
        for (index, expense) in sortedExpenses.enumerated() {
            XCTAssertEqual(expense.merchant, "Updated Merchant \(index)")
            XCTAssertEqual(expense.amount.decimalValue, Decimal(50.0 + Double(index * 10)))
        }
    }
    
    private func createMultipleTestExpenses(count: Int) async throws -> [Expense] {
        var expenses: [Expense] = []
        
        for i in 0..<count {
            let expenseData = ExpenseData(
                amount: Decimal(20.0 + Double(i * 5)),
                merchant: "Test Merchant \(i)",
                date: Date(),
                category: nil
            )
            
            let expense = try await dataService.createExpense(expenseData)
            expenses.append(expense)
        }
        
        return expenses
    }
}