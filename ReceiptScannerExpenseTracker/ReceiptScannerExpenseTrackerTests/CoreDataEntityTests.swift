import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class CoreDataEntityTests: XCTestCase {
    var testCoreDataManager: CoreDataManager!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        testCoreDataManager = CoreDataManager.createForTesting()
        testContext = testCoreDataManager.viewContext
        
        // Create default categories for testing only if needed for this test
        // CoreDataManager.createDefaultCategoriesForTesting(in: testContext)
    }
    
    override func tearDownWithError() throws {
        testCoreDataManager = nil
        testContext = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Entity Name Tests
    
    func testEntityNames() {
        // Test that entity names are correctly set up
        let expenseEntity = NSEntityDescription.entity(forEntityName: "Expense", in: testContext)
        XCTAssertNotNil(expenseEntity, "Expense entity should exist")
        
        let categoryEntity = NSEntityDescription.entity(forEntityName: "Category", in: testContext)
        XCTAssertNotNil(categoryEntity, "Category entity should exist")
        
        let tagEntity = NSEntityDescription.entity(forEntityName: "Tag", in: testContext)
        XCTAssertNotNil(tagEntity, "Tag entity should exist")
        
        let expenseItemEntity = NSEntityDescription.entity(forEntityName: "ExpenseItem", in: testContext)
        XCTAssertNotNil(expenseItemEntity, "ExpenseItem entity should exist")
        
        let receiptEntity = NSEntityDescription.entity(forEntityName: "Receipt", in: testContext)
        XCTAssertNotNil(receiptEntity, "Receipt entity should exist")
        
        let receiptItemEntity = NSEntityDescription.entity(forEntityName: "ReceiptItem", in: testContext)
        XCTAssertNotNil(receiptItemEntity, "ReceiptItem entity should exist")
    }
    
    // MARK: - Date Formatting Tests
    
    func testExpenseDateFormatting() {
        // Create a test expense
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        
        // Test that formattedDate() doesn't crash
        let formattedDate = expense.formattedDate()
        XCTAssertFalse(formattedDate.isEmpty, "Formatted date should not be empty")
        
        // Test with nil date (should use current date)
        let nilDateExpense = Expense(context: testContext)
        nilDateExpense.id = UUID()
        nilDateExpense.amount = NSDecimalNumber(string: "42.99")
        nilDateExpense.merchant = "Test Merchant"
        // Don't set date property
        
        // This should not crash and should return a non-empty string
        let nilFormattedDate = nilDateExpense.formattedDate()
        XCTAssertFalse(nilFormattedDate.isEmpty, "Formatted date should not be empty even with nil date")
    }
    
    func testReceiptDateFormatting() {
        // Create a test receipt
        let receipt = Receipt(context: testContext)
        receipt.id = UUID()
        receipt.date = Date()
        receipt.dateProcessed = Date()
        receipt.merchantName = "Test Merchant"
        receipt.totalAmount = NSDecimalNumber(string: "42.99")
        receipt.imageURL = URL(string: "file:///test.jpg")!
        
        // Test that formattedDate() doesn't crash
        let formattedDate = receipt.formattedDate()
        XCTAssertFalse(formattedDate.isEmpty, "Formatted date should not be empty")
        
        // Test with nil date (should use current date)
        let nilDateReceipt = Receipt(context: testContext)
        nilDateReceipt.id = UUID()
        nilDateReceipt.dateProcessed = Date()
        nilDateReceipt.merchantName = "Test Merchant"
        nilDateReceipt.totalAmount = NSDecimalNumber(string: "42.99")
        nilDateReceipt.imageURL = URL(string: "file:///test.jpg")!
        // Don't set date property
        
        // This should not crash and should return a non-empty string
        let nilFormattedDate = nilDateReceipt.formattedDate()
        XCTAssertFalse(nilFormattedDate.isEmpty, "Formatted date should not be empty even with nil date")
    }
    
    // MARK: - Cross-Context Relationship Tests
    
    func testCrossContextCategoryRelationship() {
        // Create two separate contexts
        let context1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context1.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        let context2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context2.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        // Create a category in context1
        let category = Category(context: context1)
        category.id = UUID()
        category.name = "Test Category"
        category.colorHex = "FF5733"
        category.icon = "tag.fill"
        category.isDefault = false
        
        try! context1.save()
        
        // Create an expense in context2 and associate it with the category from context1
        let expense = Expense(context: context2)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        
        // This would normally cause a cross-context relationship error
        // But our fix should handle it by fetching or creating the category in context2
        let viewModel = ExpenseEditViewModel(context: context2, categoryService: MockCategoryService())
        viewModel.selectedCategory = category
        
        // Populate the expense using the view model
        viewModel.populateExpense(expense)
        
        // Test that the expense has a category with the same ID
        XCTAssertNotNil(expense.category, "Expense should have a category")
        XCTAssertEqual(expense.category?.id, category.id, "Category IDs should match")
        XCTAssertEqual(expense.category?.name, category.name, "Category names should match")
        
        // Test that the contexts are different
        XCTAssertNotEqual(expense.managedObjectContext, category.managedObjectContext, "Contexts should be different")
        
        // Test that saving works
        do {
            try context2.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
    }
    
    func testCrossContextTagRelationship() {
        // Create two separate contexts
        let context1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context1.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        let context2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context2.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        // Create a tag in context1
        let tag = Tag(context: context1)
        tag.id = UUID()
        tag.name = "Test Tag"
        
        try! context1.save()
        
        // Create an expense in context2 and associate it with the tag from context1
        let expense = Expense(context: context2)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        
        // This would normally cause a cross-context relationship error
        // But our fix should handle it by fetching or creating the tag in context2
        let viewModel = ExpenseEditViewModel(context: context2, categoryService: MockCategoryService())
        viewModel.tags = [tag]
        
        // Populate the expense using the view model
        viewModel.populateExpense(expense)
        
        // Test that the expense has a tag with the same ID
        let expenseTags = expense.tags?.allObjects as? [Tag] ?? []
        XCTAssertEqual(expenseTags.count, 1, "Expense should have one tag")
        XCTAssertEqual(expenseTags.first?.id, tag.id, "Tag IDs should match")
        XCTAssertEqual(expenseTags.first?.name, tag.name, "Tag names should match")
        
        // Test that the contexts are different
        XCTAssertNotEqual(expenseTags.first?.managedObjectContext, tag.managedObjectContext, "Contexts should be different")
        
        // Test that saving works
        do {
            try context2.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
    }
    
    func testCrossContextExpenseItemRelationship() {
        // Create two separate contexts
        let context1 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context1.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        let context2 = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context2.persistentStoreCoordinator = testContext.persistentStoreCoordinator
        
        // Create a category in context1
        let category = Category(context: context1)
        category.id = UUID()
        category.name = "Test Category"
        category.colorHex = "FF5733"
        category.icon = "tag.fill"
        category.isDefault = false
        
        try! context1.save()
        
        // Create an expense in context2 and associate it with expense items that use the category from context1
        let expense = Expense(context: context2)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
        
        // This would normally cause a cross-context relationship error
        // But our fix should handle it by fetching or creating the category in context2
        let viewModel = ExpenseEditViewModel(context: context2, categoryService: MockCategoryService())
        viewModel.expenseItems = [
            ExpenseItemEdit(id: UUID(), name: "Item 1", amount: "20.00", category: category),
            ExpenseItemEdit(id: UUID(), name: "Item 2", amount: "22.99", category: category)
        ]
        
        // Populate the expense using the view model
        viewModel.populateExpense(expense)
        
        // Test that the expense has items with the correct category
        let expenseItems = expense.items?.allObjects as? [ExpenseItem] ?? []
        XCTAssertEqual(expenseItems.count, 2, "Expense should have two items")
        
        for item in expenseItems {
            XCTAssertNotNil(item.category, "Item should have a category")
            XCTAssertEqual(item.category?.id, category.id, "Category IDs should match")
            XCTAssertEqual(item.category?.name, category.name, "Category names should match")
            
            // Test that the contexts are different
            XCTAssertNotEqual(item.category?.managedObjectContext, category.managedObjectContext, "Contexts should be different")
        }
        
        // Test that saving works
        do {
            try context2.save()
        } catch {
            XCTFail("Failed to save context: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func populateExpense(_ expense: Expense) {
        // This is a simplified version of the populateExpense method from ExpenseEditViewModel
        // Used for testing purposes
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Test Merchant"
    }
    
    // MARK: - Mock CategoryService for Testing
    
    class MockCategoryService: CategoryServiceProtocol {
        func getAllCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
            return []
        }
        
        func getDefaultCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
            return []
        }
        
        func getCustomCategories() async throws -> [ReceiptScannerExpenseTracker.Category] {
            return []
        }
        
        func getCategoriesByBudgetRule(_ rule: BudgetRule) async throws -> [ReceiptScannerExpenseTracker.Category] {
            return []
        }
        
        func createCategory(name: String, colorHex: String, icon: String, parentCategory: ReceiptScannerExpenseTracker.Category?) async throws -> ReceiptScannerExpenseTracker.Category {
            // This is a mock implementation that doesn't actually create anything
            // Just throw an error to avoid the fatalError
            throw CategoryServiceError.categoryAlreadyExists
        }
        
        func updateCategory(_ category: ReceiptScannerExpenseTracker.Category, name: String?, colorHex: String?, icon: String?) async throws {
            // No-op
        }
        
        func deleteCategory(_ category: ReceiptScannerExpenseTracker.Category) async throws {
            // No-op
        }
        
        func suggestCategory(for merchantName: String, amount: Decimal?) async throws -> ReceiptScannerExpenseTracker.Category? {
            return nil
        }
        
        func suggestCategory(for receiptText: String) async throws -> ReceiptScannerExpenseTracker.Category? {
            return nil
        }
        
        func getCategoryUsageStats() async throws -> [CategoryUsageStats] {
            return []
        }
        
        func getBudgetRuleStats(for rule: BudgetRule, period: DateInterval) async throws -> BudgetRuleStats {
            // Create a mock BudgetRuleStats
            return BudgetRuleStats(
                rule: rule,
                totalSpent: Decimal(0),
                targetAmount: Decimal(100),
                percentageUsed: 0.0,
                categories: [],
                isOverBudget: false
            )
        }
        
        func initializeBudgetRuleCategories() async throws {
            // No-op
        }
    }
}