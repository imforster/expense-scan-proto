import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class ExpenseEditViewModelTests: XCTestCase {
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
    
    // MARK: - Initialization Tests
    
    func testInitializationWithoutExpense() {
        XCTAssertEqual(viewModel.amount, "")
        XCTAssertEqual(viewModel.merchant, "")
        XCTAssertNil(viewModel.selectedCategory)
        XCTAssertEqual(viewModel.notes, "")
        XCTAssertEqual(viewModel.paymentMethod, "")
        XCTAssertFalse(viewModel.isRecurring)
        XCTAssertTrue(viewModel.tags.isEmpty)
        XCTAssertTrue(viewModel.expenseItems.isEmpty)
        XCTAssertFalse(viewModel.isReceiptSplitMode)
    }
    
    func testInitializationWithExpense() {
        // Create a test expense
        let expense = createTestExpense()
        
        // Create view model with expense
        let viewModelWithExpense = ExpenseEditViewModel(context: context, expense: expense, categoryService: mockCategoryService)
        
        XCTAssertEqual(viewModelWithExpense.amount, expense.amount.stringValue)
        XCTAssertEqual(viewModelWithExpense.merchant, expense.merchant)
        XCTAssertEqual(viewModelWithExpense.selectedCategory, expense.category)
        XCTAssertEqual(viewModelWithExpense.notes, expense.notes ?? "")
        XCTAssertEqual(viewModelWithExpense.paymentMethod, expense.paymentMethod ?? "")
        XCTAssertEqual(viewModelWithExpense.isRecurring, expense.isRecurring)
    }
    
    // MARK: - Validation Tests
    
    func testValidationWithValidInput() {
        viewModel.amount = "25.99"
        viewModel.merchant = "Test Merchant"
        
        XCTAssertTrue(viewModel.isValid)
    }
    
    func testValidationWithEmptyAmount() {
        viewModel.amount = ""
        viewModel.merchant = "Test Merchant"
        
        XCTAssertFalse(viewModel.isValid)
    }
    
    func testValidationWithInvalidAmount() {
        viewModel.amount = "invalid"
        viewModel.merchant = "Test Merchant"
        
        XCTAssertFalse(viewModel.isValid)
    }
    
    func testValidationWithEmptyMerchant() {
        viewModel.amount = "25.99"
        viewModel.merchant = ""
        
        XCTAssertFalse(viewModel.isValid)
    }
    
    // MARK: - Category Suggestion Tests
    
    func testCategorySuggestionForMerchant() async {
        let testCategory = createTestCategory(name: "Food", icon: "fork.knife", color: "FF0000")
        mockCategoryService.suggestedCategory = testCategory
        
        viewModel.merchant = "McDonald's"
        
        // Wait for debounced suggestion
        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds
        
        XCTAssertEqual(viewModel.suggestedCategories.count, 1)
        XCTAssertEqual(viewModel.suggestedCategories.first?.name, "Food")
    }
    
    // MARK: - Recurring Expense Detection Tests
    
    func testRecurringExpenseDetection() async {
        // Create multiple similar expenses
        createMultipleTestExpenses(merchant: "Electric Company", count: 4)
        
        viewModel.merchant = "Electric Company"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertTrue(viewModel.isRecurring)
    }
    
    func testRecurringExpenseDetectionWithFewExpenses() async {
        // Create only 2 similar expenses (below threshold)
        createMultipleTestExpenses(merchant: "Random Store", count: 2)
        
        viewModel.merchant = "Random Store"
        
        await viewModel.detectRecurringExpense()
        
        XCTAssertFalse(viewModel.isRecurring)
    }
    
    // MARK: - Tag Management Tests
    
    func testAddNewTag() async {
        let tagName = "Business"
        
        do {
            try await viewModel.addTag(tagName)
            
            XCTAssertEqual(viewModel.tags.count, 1)
            XCTAssertEqual(viewModel.tags.first?.name, tagName)
            XCTAssertEqual(viewModel.availableTags.count, 1)
        } catch {
            XCTFail("Failed to add tag: \(error)")
        }
    }
    
    func testAddExistingTag() async {
        // Create an existing tag
        let existingTag = createTestTag(name: "Business")
        viewModel.availableTags = [existingTag]
        
        do {
            try await viewModel.addTag("Business")
            
            XCTAssertEqual(viewModel.tags.count, 1)
            XCTAssertEqual(viewModel.tags.first?.id, existingTag.id)
            XCTAssertEqual(viewModel.availableTags.count, 1) // Should not create duplicate
        } catch {
            XCTFail("Failed to add existing tag: \(error)")
        }
    }
    
    func testRemoveTag() async {
        let tag = createTestTag(name: "Business")
        viewModel.tags = [tag]
        
        viewModel.removeTag(tag)
        
        XCTAssertTrue(viewModel.tags.isEmpty)
    }
    
    // MARK: - Expense Items Management Tests
    
    func testAddExpenseItem() {
        viewModel.addExpenseItem()
        
        XCTAssertEqual(viewModel.expenseItems.count, 1)
        XCTAssertEqual(viewModel.expenseItems.first?.name, "")
        XCTAssertEqual(viewModel.expenseItems.first?.amount, "0.00")
    }
    
    func testRemoveExpenseItem() {
        viewModel.addExpenseItem()
        viewModel.addExpenseItem()
        
        XCTAssertEqual(viewModel.expenseItems.count, 2)
        
        viewModel.removeExpenseItem(at: 0)
        
        XCTAssertEqual(viewModel.expenseItems.count, 1)
    }
    
    func testTotalExpenseItemsAmount() {
        viewModel.expenseItems = [
            ExpenseItemEdit(id: UUID(), name: "Item 1", amount: "10.00", category: nil),
            ExpenseItemEdit(id: UUID(), name: "Item 2", amount: "15.50", category: nil)
        ]
        
        XCTAssertEqual(viewModel.totalExpenseItemsAmount, Decimal(25.50))
    }
    
    // MARK: - Receipt Splitting Tests
    
    func testEnableReceiptSplitMode() {
        viewModel.enableReceiptSplitMode()
        
        XCTAssertTrue(viewModel.isReceiptSplitMode)
        XCTAssertTrue(viewModel.showingReceiptSplitView)
    }
    
    func testAddReceiptSplit() {
        viewModel.addReceiptSplit()
        
        XCTAssertEqual(viewModel.receiptSplits.count, 1)
        XCTAssertEqual(viewModel.receiptSplits.first?.name, "")
        XCTAssertEqual(viewModel.receiptSplits.first?.amount, "0.00")
        XCTAssertFalse(viewModel.receiptSplits.first?.isSelected ?? true)
    }
    
    func testRemoveReceiptSplit() {
        viewModel.addReceiptSplit()
        viewModel.addReceiptSplit()
        
        XCTAssertEqual(viewModel.receiptSplits.count, 2)
        
        viewModel.removeReceiptSplit(at: 0)
        
        XCTAssertEqual(viewModel.receiptSplits.count, 1)
    }
    
    func testCreateExpensesFromSplits() async {
        let category = createTestCategory(name: "Food", icon: "fork.knife", color: "FF0000")
        
        viewModel.receiptSplits = [
            ReceiptSplit(id: UUID(), name: "Item 1", amount: "10.00", category: category, isSelected: true),
            ReceiptSplit(id: UUID(), name: "Item 2", amount: "15.00", category: category, isSelected: true),
            ReceiptSplit(id: UUID(), name: "Item 3", amount: "5.00", category: category, isSelected: false)
        ]
        
        viewModel.merchant = "Test Merchant"
        viewModel.paymentMethod = "Credit Card"
        
        do {
            let createdExpenses = try await viewModel.createExpensesFromSplits()
            
            XCTAssertEqual(createdExpenses.count, 2) // Only selected splits
            XCTAssertEqual(createdExpenses[0].amount, NSDecimalNumber(string: "10.00"))
            XCTAssertEqual(createdExpenses[1].amount, NSDecimalNumber(string: "15.00"))
            XCTAssertEqual(createdExpenses[0].merchant, "Test Merchant")
            XCTAssertEqual(createdExpenses[0].paymentMethod, "Credit Card")
        } catch {
            XCTFail("Failed to create expenses from splits: \(error)")
        }
    }
    
    func testCreateExpensesFromSplitsWithNoSelection() async {
        viewModel.receiptSplits = [
            ReceiptSplit(id: UUID(), name: "Item 1", amount: "10.00", category: nil, isSelected: false)
        ]
        
        do {
            let _ = try await viewModel.createExpensesFromSplits()
            XCTFail("Should have thrown error for no selected splits")
        } catch ExpenseEditError.noSplitsSelected {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Delete Expense Tests
    
    func testDeleteExpenseFromListViewModel() {
        // Given
        let expense = createTestExpense()
        let listViewModel = ExpenseListViewModel()
        
        // Verify expense exists
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let initialCount = (try? context.fetch(fetchRequest).count) ?? 0
        XCTAssertGreaterThan(initialCount, 0)
        
        // When
        listViewModel.deleteExpense(expense)
        
        // Then
        let finalCount = (try? context.fetch(fetchRequest).count) ?? 0
        XCTAssertEqual(finalCount, initialCount - 1)
        XCTAssertNil(listViewModel.errorMessage)
    }
    
    func testDeleteExpenseWithRelatedData() {
        // Given
        let expense = createTestExpense()
        let tag = createTestTag(name: "Test Tag")
        expense.addToTags(tag)
        
        // Add expense items
        let expenseItem = ExpenseItem(context: context)
        expenseItem.id = UUID()
        expenseItem.name = "Test Item"
        expenseItem.amount = NSDecimalNumber(string: "10.00")
        expense.addToItems(expenseItem)
        
        try! context.save()
        
        let listViewModel = ExpenseListViewModel()
        
        // When
        listViewModel.deleteExpense(expense)
        
        // Then
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let expenses = (try? context.fetch(fetchRequest)) ?? []
        XCTAssertFalse(expenses.contains(expense))
        
        // Verify related ExpenseItem was cascade deleted
        let itemFetchRequest: NSFetchRequest<ExpenseItem> = ExpenseItem.fetchRequest()
        let items = (try? context.fetch(itemFetchRequest)) ?? []
        XCTAssertFalse(items.contains(expenseItem))
        
        // Verify Tag still exists (nullify relationship)
        let tagFetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let tags = (try? context.fetch(tagFetchRequest)) ?? []
        XCTAssertTrue(tags.contains(tag))
    }
    
    func testDeleteExpensePerformance() {
        // Given - Create multiple expenses
        var expenses: [Expense] = []
        for i in 0..<100 {
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(string: "10.00")
            expense.date = Date()
            expense.merchant = "Test Merchant \(i)"
            expenses.append(expense)
        }
        try! context.save()
        
        let listViewModel = ExpenseListViewModel()
        
        // When - Measure delete performance
        measure {
            for expense in expenses.prefix(10) {
                listViewModel.deleteExpense(expense)
            }
        }
        
        // Then - Verify deletes completed without hanging
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = (try? context.fetch(fetchRequest)) ?? []
        XCTAssertEqual(remainingExpenses.count, 90)
    }
    
    func testDeleteExpenseWithInvalidContext() {
        // Given
        let expense = createTestExpense()
        
        // Create a new context that doesn't contain the expense
        let newContainer = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        newContainer.persistentStoreDescriptions = [description]
        
        newContainer.loadPersistentStores { _, error in
            if let error = error {
                XCTFail("Failed to load store: \(error)")
            }
        }
        
        let newContext = newContainer.viewContext
        let listViewModel = ExpenseListViewModel()
        
        // When - Try to delete expense from different context
        listViewModel.deleteExpense(expense)
        
        // Then - Should handle error gracefully
        XCTAssertNotNil(listViewModel.errorMessage)
        XCTAssertTrue(listViewModel.errorMessage?.contains("Failed to delete expense") == true)
    }
    
    func testDeleteExpenseThreadSafety() {
        // Given
        let expenses = (0..<10).map { i in
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(string: "10.00")
            expense.date = Date()
            expense.merchant = "Test Merchant \(i)"
            return expense
        }
        try! context.save()
        
        let listViewModel = ExpenseListViewModel()
        let expectation = XCTestExpectation(description: "Delete operations complete")
        expectation.expectedFulfillmentCount = expenses.count
        
        // When - Delete expenses concurrently (simulating rapid user taps)
        DispatchQueue.concurrentPerform(iterations: expenses.count) { index in
            DispatchQueue.main.async {
                listViewModel.deleteExpense(expenses[index])
                expectation.fulfill()
            }
        }
        
        // Then - All operations should complete without hanging
        wait(for: [expectation], timeout: 5.0)
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = (try? context.fetch(fetchRequest)) ?? []
        XCTAssertEqual(remainingExpenses.count, 0)
    }
    
    func testDeleteExpenseUIResponsiveness() {
        // Given
        let expense = createTestExpense()
        let listViewModel = ExpenseListViewModel()
        
        // When - Measure delete operation time
        let startTime = CFAbsoluteTimeGetCurrent()
        listViewModel.deleteExpense(expense)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Then - Should complete quickly to avoid UI blocking
        XCTAssertLessThan(timeElapsed, 0.1, "Delete operation took too long, may cause UI unresponsiveness")
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = (try? context.fetch(fetchRequest)) ?? []
        XCTAssertEqual(remainingExpenses.count, 0)
        XCTAssertNil(listViewModel.errorMessage)
    }
    
    func testDeleteExpenseMainThreadExecution() {
        // Given
        let expense = createTestExpense()
        let listViewModel = ExpenseListViewModel()
        
        var executedOnMainThread = false
        
        // When
        DispatchQueue.main.sync {
            executedOnMainThread = Thread.isMainThread
            listViewModel.deleteExpense(expense)
        }
        
        // Then
        XCTAssertTrue(executedOnMainThread, "Delete should execute on main thread")
        
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = (try? context.fetch(fetchRequest)) ?? []
        XCTAssertEqual(remainingExpenses.count, 0)
    }
    
    // MARK: - Save Expense Tests
    
    func testSaveNewExpense() async {
        let category = createTestCategory(name: "Food", icon: "fork.knife", color: "FF0000")
        
        viewModel.amount = "25.99"
        viewModel.merchant = "Test Restaurant"
        viewModel.selectedCategory = category
        viewModel.notes = "Test notes"
        viewModel.paymentMethod = "Credit Card"
        viewModel.isRecurring = true
        
        do {
            try await viewModel.saveExpense()
            
            // Verify expense was saved
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try context.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            XCTAssertEqual(savedExpense.amount, NSDecimalNumber(string: "25.99"))
            XCTAssertEqual(savedExpense.merchant, "Test Restaurant")
            XCTAssertEqual(savedExpense.category, category)
            XCTAssertEqual(savedExpense.notes, "Test notes")
            XCTAssertEqual(savedExpense.paymentMethod, "Credit Card")
            XCTAssertTrue(savedExpense.isRecurring)
        } catch {
            XCTFail("Failed to save expense: \(error)")
        }
    }
    
    func testSaveExpenseWithInvalidInput() async {
        viewModel.amount = "" // Invalid
        viewModel.merchant = "Test Merchant"
        
        do {
            try await viewModel.saveExpense()
            XCTFail("Should have thrown validation error")
        } catch ExpenseEditError.invalidInput {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
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
        expense.category = createTestCategory(name: "Food", icon: "fork.knife", color: "FF0000")
        
        try! context.save()
        return expense
    }
    
    private func createTestCategory(name: String, icon: String, color: String) -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.colorHex = color
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
    
    private func createMultipleTestExpenses(merchant: String, count: Int) {
        let calendar = Calendar.current
        
        for i in 0..<count {
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(string: "100.00")
            expense.merchant = merchant
            expense.date = calendar.date(byAdding: .month, value: -i, to: Date()) ?? Date()
            expense.notes = "Test expense \(i)"
            expense.paymentMethod = "Credit Card"
            expense.isRecurring = false
        }
        
        try! context.save()
    }
}

// MARK: - Mock Category Service

class MockCategoryService: CategoryServiceProtocol {
    var suggestedCategory: ReceiptScannerExpenseTracker.Category?
    var categories: [ReceiptScannerExpenseTracker.Category] = []
    var shouldThrowError = false
    
    func getAllCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: 1, userInfo: nil)
        }
        return categories
    }
    
    func getDefaultCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
        return categories.filter { $0.isDefault }
    }
    
    func getCustomCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
        return categories.filter { !$0.isDefault }
    }
    
    func getCategoriesByBudgetRule(_ rule: BudgetRule) async throws -> [ReceiptScannerExpenseTracker.Category] {
        return []
    }
    
    func createCategory(name: String, colorHex: String, icon: String, parentCategory: ReceiptScannerExpenseTracker.Category?) async throws -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
        category.id = UUID()
        category.name = name
        category.colorHex = colorHex
        category.icon = icon
        category.isDefault = false
        category.parentCategory = parentCategory
        categories.append(category)
        return category
    }
    
    func updateCategory(_ category: ReceiptScannerExpenseTracker.Category, name: String?, colorHex: String?, icon: String?) async throws {
        // Mock implementation
    }
    
    func deleteCategory(_ category: ReceiptScannerExpenseTracker.Category) async throws {
        categories.removeAll { $0.id == category.id }
    }
    
    func suggestCategory(for merchantName: String, amount: Decimal?) async throws -> ReceiptScannerExpenseTracker.Category? {
        return suggestedCategory
    }
    
    func suggestCategory(for receiptText: String) async throws -> ReceiptScannerExpenseTracker.Category? {
        return suggestedCategory
    }
    
    func getCategoryUsageStats() async throws -> [CategoryUsageStats] {
        return []
    }
    
    func getBudgetRuleStats(for rule: BudgetRule, period: DateInterval) async throws -> BudgetRuleStats {
        return BudgetRuleStats(
            rule: rule,
            totalSpent: 0,
            targetAmount: 0,
            percentageUsed: 0,
            categories: [],
            isOverBudget: false
        )
    }
    
    func initializeBudgetRuleCategories() async throws {
        // Mock implementation
    }
}