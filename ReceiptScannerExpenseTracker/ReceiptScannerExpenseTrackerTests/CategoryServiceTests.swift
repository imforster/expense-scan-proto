import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class CategoryServiceTests: XCTestCase {
    var categoryService: CategoryService!
    var testCoreDataManager: CoreDataManager!
    var testContext: NSManagedObjectContext!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create in-memory Core Data stack for testing
        testCoreDataManager = CoreDataManager.createForTesting()
        testContext = testCoreDataManager.viewContext
        categoryService = CategoryService(coreDataManager: testCoreDataManager)
    }
    
    override func tearDownWithError() throws {
        categoryService = nil
        testCoreDataManager = nil
        testContext = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Category Creation Tests
    
    func testCreateCategory() async throws {
        // Given
        let categoryName = "Test Category"
        let colorHex = "FF5733"
        let icon = "tag.fill"
        
        // When
        let createdCategory = try await categoryService.createCategory(
            name: categoryName,
            colorHex: colorHex,
            icon: icon,
            parentCategory: nil
        )
        
        // Then
        XCTAssertEqual(createdCategory.name, categoryName)
        XCTAssertEqual(createdCategory.colorHex, colorHex)
        XCTAssertEqual(createdCategory.icon, icon)
        XCTAssertFalse(createdCategory.isDefault)
        XCTAssertNil(createdCategory.parentCategory)
    }
    
    func testCreateCategoryWithParent() async throws {
        // Given
        let parentCategory = try await categoryService.createCategory(
            name: "Parent Category",
            colorHex: "FF5733",
            icon: "folder.fill",
            parentCategory: nil
        )
        
        let childCategoryName = "Child Category"
        
        // When
        let childCategory = try await categoryService.createCategory(
            name: childCategoryName,
            colorHex: "33A8FF",
            icon: "tag.fill",
            parentCategory: parentCategory
        )
        
        // Then
        XCTAssertEqual(childCategory.name, childCategoryName)
        XCTAssertEqual(childCategory.parentCategory, parentCategory)
    }
    
    func testCreateDuplicateCategoryThrowsError() async throws {
        // Given
        let categoryName = "Duplicate Category"
        _ = try await categoryService.createCategory(
            name: categoryName,
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // When & Then
        do {
            _ = try await categoryService.createCategory(
                name: categoryName,
                colorHex: "33A8FF",
                icon: "tag.fill",
                parentCategory: nil
            )
            XCTFail("Expected CategoryServiceError.categoryAlreadyExists")
        } catch CategoryServiceError.categoryAlreadyExists {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Category Retrieval Tests
    
    func testGetAllCategories() async throws {
        // Given
        let category1 = try await categoryService.createCategory(
            name: "Category 1",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        let category2 = try await categoryService.createCategory(
            name: "Category 2",
            colorHex: "33A8FF",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // When
        let allCategories = try await categoryService.getAllCategories()
        
        // Then
        XCTAssertTrue(allCategories.contains(category1))
        XCTAssertTrue(allCategories.contains(category2))
        XCTAssertGreaterThanOrEqual(allCategories.count, 2)
    }
    
    func testGetDefaultCategories() async throws {
        // Given
        let customCategory = try await categoryService.createCategory(
            name: "Custom Category",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // Create a default category manually for testing
        let defaultCategory = Category(context: testContext)
        defaultCategory.id = UUID()
        defaultCategory.name = "Default Category"
        defaultCategory.colorHex = "33A8FF"
        defaultCategory.icon = "star.fill"
        defaultCategory.isDefault = true
        try testContext.save()
        
        // When
        let defaultCategories = try await categoryService.getDefaultCategories()
        
        // Then
        XCTAssertTrue(defaultCategories.contains(defaultCategory))
        XCTAssertFalse(defaultCategories.contains(customCategory))
    }
    
    func testGetCustomCategories() async throws {
        // Given
        let customCategory = try await categoryService.createCategory(
            name: "Custom Category",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // Create a default category manually for testing
        let defaultCategory = Category(context: testContext)
        defaultCategory.id = UUID()
        defaultCategory.name = "Default Category"
        defaultCategory.colorHex = "33A8FF"
        defaultCategory.icon = "star.fill"
        defaultCategory.isDefault = true
        try testContext.save()
        
        // When
        let customCategories = try await categoryService.getCustomCategories()
        
        // Then
        XCTAssertTrue(customCategories.contains(customCategory))
        XCTAssertFalse(customCategories.contains(defaultCategory))
    }
    
    // MARK: - Category Update Tests
    
    func testUpdateCategory() async throws {
        // Given
        let category = try await categoryService.createCategory(
            name: "Original Name",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        let newName = "Updated Name"
        let newColor = "33A8FF"
        let newIcon = "star.fill"
        
        // When
        try await categoryService.updateCategory(
            category,
            name: newName,
            colorHex: newColor,
            icon: newIcon
        )
        
        // Then
        XCTAssertEqual(category.name, newName)
        XCTAssertEqual(category.colorHex, newColor)
        XCTAssertEqual(category.icon, newIcon)
    }
    
    // MARK: - Category Deletion Tests
    
    func testDeleteCategory() async throws {
        // Given
        let category = try await categoryService.createCategory(
            name: "Category to Delete",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // When
        try await categoryService.deleteCategory(category)
        
        // Then
        let allCategories = try await categoryService.getAllCategories()
        XCTAssertFalse(allCategories.contains(category))
    }
    
    func testDeleteDefaultCategoryThrowsError() async throws {
        // Given
        let defaultCategory = Category(context: testContext)
        defaultCategory.id = UUID()
        defaultCategory.name = "Default Category"
        defaultCategory.colorHex = "33A8FF"
        defaultCategory.icon = "star.fill"
        defaultCategory.isDefault = true
        try testContext.save()
        
        // When & Then
        do {
            try await categoryService.deleteCategory(defaultCategory)
            XCTFail("Expected CategoryServiceError.cannotDeleteDefaultCategory")
        } catch CategoryServiceError.cannotDeleteDefaultCategory {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    // MARK: - Category Suggestion Tests
    
    func testSuggestCategoryForMerchant() async throws {
        // Given
        try await categoryService.initializeBudgetRuleCategories()
        let merchantName = "Starbucks"
        
        // When
        let suggestedCategory = try await categoryService.suggestCategory(for: merchantName, amount: nil)
        
        // Then
        XCTAssertNotNil(suggestedCategory)
        XCTAssertEqual(suggestedCategory?.name, "Dining Out")
    }
    
    func testSuggestCategoryForReceiptText() async throws {
        // Given
        try await categoryService.initializeBudgetRuleCategories()
        let receiptText = "WALMART SUPERCENTER\nGROCERIES AND HOUSEHOLD ITEMS\nTOTAL: $45.67"
        
        // When
        let suggestedCategory = try await categoryService.suggestCategory(for: receiptText)
        
        // Then
        XCTAssertNotNil(suggestedCategory)
        XCTAssertEqual(suggestedCategory?.name, "Groceries")
    }
    
    // MARK: - Budget Rule Tests
    
    func testInitializeBudgetRuleCategories() async throws {
        // When
        try await categoryService.initializeBudgetRuleCategories()
        
        // Then
        let needsCategories = try await categoryService.getCategoriesByBudgetRule(.needs)
        let wantsCategories = try await categoryService.getCategoriesByBudgetRule(.wants)
        let savingsCategories = try await categoryService.getCategoriesByBudgetRule(.savingsAndDebt)
        
        XCTAssertFalse(needsCategories.isEmpty)
        XCTAssertFalse(wantsCategories.isEmpty)
        XCTAssertFalse(savingsCategories.isEmpty)
        
        // Check specific categories exist
        XCTAssertTrue(needsCategories.contains { $0.name == "Housing & Rent" })
        XCTAssertTrue(needsCategories.contains { $0.name == "Groceries" })
        XCTAssertTrue(wantsCategories.contains { $0.name == "Dining Out" })
        XCTAssertTrue(wantsCategories.contains { $0.name == "Entertainment" })
        XCTAssertTrue(savingsCategories.contains { $0.name == "Emergency Fund" })
        XCTAssertTrue(savingsCategories.contains { $0.name == "401k Contributions" })
    }
    
    func testGetBudgetRuleStats() async throws {
        // Given
        try await categoryService.initializeBudgetRuleCategories()
        
        // Create some test expenses
        let needsCategory = try await categoryService.getCategoriesByBudgetRule(.needs).first!
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 100)
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.category = needsCategory
        try testContext.save()
        
        let period = DateInterval(start: Date().addingTimeInterval(-86400), end: Date().addingTimeInterval(86400))
        
        // When
        let stats = try await categoryService.getBudgetRuleStats(for: .needs, period: period)
        
        // Then
        XCTAssertEqual(stats.rule, .needs)
        XCTAssertEqual(stats.totalSpent, Decimal(100))
        XCTAssertGreaterThan(stats.targetAmount, Decimal.zero)
        XCTAssertFalse(stats.categories.isEmpty)
    }
    
    // MARK: - Category Usage Statistics Tests
    
    func testGetCategoryUsageStats() async throws {
        // Given
        let category = try await categoryService.createCategory(
            name: "Test Category",
            colorHex: "FF5733",
            icon: "tag.fill",
            parentCategory: nil
        )
        
        // Create test expenses
        let expense1 = Expense(context: testContext)
        expense1.id = UUID()
        expense1.amount = NSDecimalNumber(value: 50)
        expense1.date = Date()
        expense1.merchant = "Merchant 1"
        expense1.category = category
        
        let expense2 = Expense(context: testContext)
        expense2.id = UUID()
        expense2.amount = NSDecimalNumber(value: 75)
        expense2.date = Date()
        expense2.merchant = "Merchant 2"
        expense2.category = category
        
        try testContext.save()
        
        // When
        let stats = try await categoryService.getCategoryUsageStats()
        
        // Then
        let categoryStats = stats.first { $0.category == category }
        XCTAssertNotNil(categoryStats)
        XCTAssertEqual(categoryStats?.usageCount, 2)
        XCTAssertEqual(categoryStats?.totalAmount, Decimal(125))
        XCTAssertEqual(categoryStats?.averageAmount, Decimal(62.5))
    }
    
    // MARK: - Budget Rule Enum Tests
    
    func testBudgetRulePercentages() {
        XCTAssertEqual(BudgetRule.needs.percentage, 0.50)
        XCTAssertEqual(BudgetRule.wants.percentage, 0.30)
        XCTAssertEqual(BudgetRule.savingsAndDebt.percentage, 0.20)
    }
    
    func testBudgetRuleColors() {
        XCTAssertEqual(BudgetRule.needs.color, "FF5733")
        XCTAssertEqual(BudgetRule.wants.color, "33A8FF")
        XCTAssertEqual(BudgetRule.savingsAndDebt.color, "33FF57")
    }
    
    func testBudgetRuleIcons() {
        XCTAssertEqual(BudgetRule.needs.icon, "house.fill")
        XCTAssertEqual(BudgetRule.wants.icon, "heart.fill")
        XCTAssertEqual(BudgetRule.savingsAndDebt.icon, "banknote.fill")
    }
}

// MARK: - Test Helper Extensions

// Create a test helper extension for CoreDataManager
extension CoreDataManager {
    // Create a test instance of CoreDataManager with in-memory storage
    static func createForTesting() -> CoreDataManager {
        // Get the shared instance
        let manager = CoreDataManager.shared
        
        // Configure the persistent container to use an in-memory store
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.type = NSInMemoryStoreType
        
        // Use the setPersistentStoreDescriptions method instead of direct access
        manager.setPersistentStoreDescriptions([description])
        
        return manager
    }
}