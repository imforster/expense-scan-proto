import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class CategorySuggestionTests: XCTestCase {
    var categoryService: CategoryService!
    var testCoreDataManager: CoreDataManager!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        testCoreDataManager = CoreDataManager.shared
        
        // Configure for in-memory testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testCoreDataManager.setPersistentStoreDescriptions([description])
        
        testContext = testCoreDataManager.viewContext
        categoryService = CategoryService(coreDataManager: testCoreDataManager)
        
        // Initialize default categories for testing
        try createTestCategories()
    }
    
    override func tearDownWithError() throws {
        categoryService = nil
        testCoreDataManager = nil
        testContext = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    private func createTestCategories() throws {
        // Create default categories for testing
        let categories = [
            ("Dining Out", "33A8FF", "fork.knife.circle.fill"),
            ("Food", "FF5733", "fork.knife"),
            ("Groceries", "FFE066", "cart.fill"),
            ("Entertainment", "FF33A8", "film.fill"),
            ("Personal Care", "A29BFE", "scissors"),
            ("Shopping", "A833FF", "cart.fill"),
            ("Transportation", "33A8FF", "car.fill"),
            ("Utilities", "33FF57", "bolt.fill"),
            ("Healthcare", "33FFA8", "heart.fill"),
            ("Housing", "57FF33", "house.fill"),
            ("Travel", "5733FF", "airplane")
        ]
        
        for (name, color, icon) in categories {
            let category = Category(context: testContext)
            category.id = UUID()
            category.name = name
            category.colorHex = color
            category.icon = icon
            category.isDefault = true
        }
        
        try testContext.save()
    }
    
    // MARK: - Category Suggestion Tests
    
    func testSuggestCategoryByAmount() async throws {
        // Test small amounts (< $10)
        let smallAmount = Decimal(5.99)
        let smallCategory = try await categoryService.suggestCategory(for: "Coffee Shop", amount: smallAmount)
        XCTAssertNotNil(smallCategory)
        XCTAssertTrue(smallCategory?.name == "Dining Out" || smallCategory?.name == "Food")
        
        // Test medium amounts ($10 - $50)
        let mediumAmount = Decimal(35.75)
        let mediumCategory = try await categoryService.suggestCategory(for: "Unknown Store", amount: mediumAmount)
        XCTAssertNotNil(mediumCategory)
        XCTAssertTrue(
            mediumCategory?.name == "Groceries" || 
            mediumCategory?.name == "Entertainment" || 
            mediumCategory?.name == "Personal Care"
        )
        
        // Test larger amounts ($50 - $100)
        let largerAmount = Decimal(75.50)
        let largerCategory = try await categoryService.suggestCategory(for: "Unknown Store", amount: largerAmount)
        XCTAssertNotNil(largerCategory)
        XCTAssertTrue(
            largerCategory?.name == "Shopping" || 
            largerCategory?.name == "Transportation"
        )
        
        // Test even larger amounts ($100 - $200)
        let evenLargerAmount = Decimal(150.00)
        let evenLargerCategory = try await categoryService.suggestCategory(for: "Unknown Store", amount: evenLargerAmount)
        XCTAssertNotNil(evenLargerCategory)
        XCTAssertTrue(
            evenLargerCategory?.name == "Utilities" || 
            evenLargerCategory?.name == "Healthcare"
        )
        
        // Test very large amounts (> $200)
        let veryLargeAmount = Decimal(500.00)
        let veryLargeCategory = try await categoryService.suggestCategory(for: "Unknown Store", amount: veryLargeAmount)
        XCTAssertNotNil(veryLargeCategory)
        XCTAssertTrue(
            veryLargeCategory?.name == "Housing" || 
            veryLargeCategory?.name == "Travel"
        )
    }
    
    func testSuggestCategoryByMerchantName() async throws {
        // Test known merchant names
        let starbucksCategory = try await categoryService.suggestCategory(for: "Starbucks Coffee", amount: nil)
        XCTAssertNotNil(starbucksCategory)
        XCTAssertEqual(starbucksCategory?.name, "Dining Out")
        
        let walmartCategory = try await categoryService.suggestCategory(for: "Walmart Supercenter", amount: nil)
        XCTAssertNotNil(walmartCategory)
        XCTAssertEqual(walmartCategory?.name, "Groceries")
        
        let netflixCategory = try await categoryService.suggestCategory(for: "Netflix Subscription", amount: nil)
        XCTAssertNotNil(netflixCategory)
        XCTAssertEqual(netflixCategory?.name, "Streaming Services")
    }
    
    func testSuggestCategoryByReceiptText() async throws {
        // Test receipt text analysis
        let groceryReceiptText = """
        WALMART SUPERCENTER
        123 Main St
        City, State 12345
        
        Milk                $3.99
        Bread               $2.49
        Eggs                $3.29
        Bananas             $1.99
        
        TOTAL:             $11.76
        """
        
        let groceryCategory = try await categoryService.suggestCategory(for: groceryReceiptText)
        XCTAssertNotNil(groceryCategory)
        XCTAssertEqual(groceryCategory?.name, "Groceries")
        
        let restaurantReceiptText = """
        OLIVE GARDEN
        456 Restaurant Ave
        City, State 12345
        
        Pasta               $15.99
        Salad               $8.99
        Drink               $3.50
        
        Subtotal:          $28.48
        Tax:                $2.28
        Tip:                $5.70
        
        TOTAL:             $36.46
        """
        
        let restaurantCategory = try await categoryService.suggestCategory(for: restaurantReceiptText)
        XCTAssertNotNil(restaurantCategory)
        XCTAssertEqual(restaurantCategory?.name, "Dining Out")
    }
    
    func testCategoryLearningFromHistory() async throws {
        // Create a test expense with a specific category and merchant
        let uniqueMerchant = "Very Unique Store Name \(UUID().uuidString)"
        let category = try await getCategoryByName("Entertainment")
        XCTAssertNotNil(category)
        
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(decimal: Decimal(42.99))
        expense.date = Date()
        expense.merchant = uniqueMerchant
        expense.category = category
        try testContext.save()
        
        // Now try to suggest a category for the same merchant
        let suggestedCategory = try await categoryService.suggestCategory(for: uniqueMerchant, amount: nil)
        XCTAssertNotNil(suggestedCategory)
        XCTAssertEqual(suggestedCategory?.id, category?.id)
    }
    
    // MARK: - Helper Methods
    
    private func getCategoryByName(_ name: String) async throws -> ReceiptScannerExpenseTracker.Category? {
        let fetchRequest: NSFetchRequest<ReceiptScannerExpenseTracker.Category> = ReceiptScannerExpenseTracker.Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", name)
        fetchRequest.fetchLimit = 1
        
        let categories = try testContext.fetch(fetchRequest)
        return categories.first
    }
}