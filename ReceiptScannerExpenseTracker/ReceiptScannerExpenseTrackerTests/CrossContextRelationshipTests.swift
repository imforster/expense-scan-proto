import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
class CrossContextRelationshipTests: XCTestCase {
    var mainContext: NSManagedObjectContext!
    var secondaryContext: NSManagedObjectContext!
    var viewModel: ExpenseEditViewModel!
    
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
        
        // Create two separate contexts that share the same persistent store
        mainContext = persistentContainer.viewContext
        secondaryContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        secondaryContext.persistentStoreCoordinator = persistentContainer.persistentStoreCoordinator
        
        // Initialize view model with the main context
        viewModel = ExpenseEditViewModel(context: mainContext)
    }
    
    override func tearDown() {
        viewModel = nil
        mainContext = nil
        secondaryContext = nil
        super.tearDown()
    }
    
    // MARK: - Cross-Context Relationship Tests
    
    func testSaveExpenseWithCrossContextCategory() async {
        // 1. Create a category in the secondary context
        let categoryInSecondaryContext = createCategory(in: secondaryContext, name: "Food", icon: "fork.knife", color: "FF5733")
        try! secondaryContext.save()
        
        // 2. Set up the view model with data including the category from secondary context
        viewModel.amount = "42.99"
        viewModel.merchant = "Test Restaurant"
        viewModel.selectedCategory = categoryInSecondaryContext // This is from a different context
        viewModel.notes = "Test notes"
        viewModel.paymentMethod = "Credit Card"
        
        // 3. Save the expense - this should work with our fix
        do {
            try await viewModel.saveExpense()
            
            // 4. Verify the expense was saved with the correct category
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try mainContext.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            
            // The category should be set and have the same ID as our original category
            XCTAssertNotNil(savedExpense.category)
            XCTAssertEqual(savedExpense.category?.id, categoryInSecondaryContext.id)
            XCTAssertEqual(savedExpense.category?.name, "Food")
            
            // The contexts should be different
            XCTAssertNotEqual(
                savedExpense.managedObjectContext?.persistentStoreCoordinator,
                categoryInSecondaryContext.managedObjectContext?.persistentStoreCoordinator
            )
        } catch {
            XCTFail("Failed to save expense with cross-context category: \(error)")
        }
    }
    
    func testCreateExpensesFromSplitsWithCrossContextCategories() async {
        // 1. Create categories in the secondary context
        let foodCategory = createCategory(in: secondaryContext, name: "Food", icon: "fork.knife", color: "FF5733")
        let entertainmentCategory = createCategory(in: secondaryContext, name: "Entertainment", icon: "film.fill", color: "33A8FF")
        try! secondaryContext.save()
        
        // 2. Set up receipt splits with categories from secondary context
        viewModel.receiptSplits = [
            ReceiptSplit(id: UUID(), name: "Dinner", amount: "35.50", category: foodCategory, isSelected: true),
            ReceiptSplit(id: UUID(), name: "Movie Tickets", amount: "24.99", category: entertainmentCategory, isSelected: true)
        ]
        
        viewModel.merchant = "Mall Visit"
        viewModel.date = Date()
        
        // 3. Create expenses from splits - this should work with our fix
        do {
            let createdExpenses = try await viewModel.createExpensesFromSplits()
            
            // 4. Verify the expenses were created with correct categories
            XCTAssertEqual(createdExpenses.count, 2)
            
            // Check first expense
            XCTAssertEqual(createdExpenses[0].amount, NSDecimalNumber(string: "35.50"))
            XCTAssertNotNil(createdExpenses[0].category)
            XCTAssertEqual(createdExpenses[0].category?.id, foodCategory.id)
            XCTAssertEqual(createdExpenses[0].category?.name, "Food")
            
            // Check second expense
            XCTAssertEqual(createdExpenses[1].amount, NSDecimalNumber(string: "24.99"))
            XCTAssertNotNil(createdExpenses[1].category)
            XCTAssertEqual(createdExpenses[1].category?.id, entertainmentCategory.id)
            XCTAssertEqual(createdExpenses[1].category?.name, "Entertainment")
        } catch {
            XCTFail("Failed to create expenses from splits with cross-context categories: \(error)")
        }
    }
    
    func testSaveExpenseWithCrossContextTags() async {
        // 1. Create tags in the secondary context
        let businessTag = createTag(in: secondaryContext, name: "Business")
        let travelTag = createTag(in: secondaryContext, name: "Travel")
        try! secondaryContext.save()
        
        // 2. Set up the view model with data including tags from secondary context
        viewModel.amount = "125.75"
        viewModel.merchant = "Business Trip"
        viewModel.tags = [businessTag, travelTag] // Tags from different context
        
        // 3. Save the expense - this should work with our fix
        do {
            try await viewModel.saveExpense()
            
            // 4. Verify the expense was saved with the correct tags
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try mainContext.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            
            // The tags should be set and have the same IDs as our original tags
            let savedTags = savedExpense.tags?.allObjects as? [Tag] ?? []
            XCTAssertEqual(savedTags.count, 2)
            
            let savedTagIds = Set(savedTags.map { $0.id })
            XCTAssertTrue(savedTagIds.contains(businessTag.id))
            XCTAssertTrue(savedTagIds.contains(travelTag.id))
            
            // Verify tag names were preserved
            let savedTagNames = Set(savedTags.map { $0.name })
            XCTAssertTrue(savedTagNames.contains("Business"))
            XCTAssertTrue(savedTagNames.contains("Travel"))
        } catch {
            XCTFail("Failed to save expense with cross-context tags: \(error)")
        }
    }
    
    func testSaveExpenseWithCrossContextExpenseItems() async {
        // 1. Create a category in the secondary context for the expense item
        let foodCategory = createCategory(in: secondaryContext, name: "Food", icon: "fork.knife", color: "FF5733")
        try! secondaryContext.save()
        
        // 2. Set up the view model with expense items that use the category from secondary context
        viewModel.amount = "42.99"
        viewModel.merchant = "Restaurant"
        viewModel.expenseItems = [
            ExpenseItemEdit(id: UUID(), name: "Main Course", amount: "28.99", category: foodCategory),
            ExpenseItemEdit(id: UUID(), name: "Dessert", amount: "14.00", category: foodCategory)
        ]
        
        // 3. Save the expense - this should work with our fix
        do {
            try await viewModel.saveExpense()
            
            // 4. Verify the expense was saved with the correct items and categories
            let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
            let expenses = try mainContext.fetch(fetchRequest)
            
            XCTAssertEqual(expenses.count, 1)
            let savedExpense = expenses.first!
            
            // Check expense items
            let savedItems = savedExpense.items?.allObjects as? [ExpenseItem] ?? []
            XCTAssertEqual(savedItems.count, 2)
            
            // Verify item categories
            for item in savedItems {
                XCTAssertNotNil(item.category)
                XCTAssertEqual(item.category?.id, foodCategory.id)
                XCTAssertEqual(item.category?.name, "Food")
            }
            
            // Verify item amounts
            let itemAmounts = savedItems.map { $0.amount.stringValue }
            XCTAssertTrue(itemAmounts.contains("28.99"))
            XCTAssertTrue(itemAmounts.contains("14.00"))
        } catch {
            XCTFail("Failed to save expense with cross-context expense items: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createCategory(in context: NSManagedObjectContext, name: String, icon: String, color: String) -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: context)
        category.id = UUID()
        category.name = name
        category.icon = icon
        category.colorHex = color
        category.isDefault = false
        return category
    }
    
    private func createTag(in context: NSManagedObjectContext, name: String) -> ReceiptScannerExpenseTracker.Tag {
        let tag = ReceiptScannerExpenseTracker.Tag(context: context)
        tag.id = UUID()
        tag.name = name
        return tag
    }
}