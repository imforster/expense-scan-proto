import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class RecurringExpenseFilterTests: CoreDataTestCase {
    
    var filterService: ExpenseFilterService!
    var recurringExpenseService: RecurringExpenseService!
    
    override func setUp() {
        super.setUp()
        filterService = ExpenseFilterService()
        recurringExpenseService = RecurringExpenseService(context: testContext)
    }
    
    override func tearDown() {
        filterService = nil
        recurringExpenseService = nil
        super.tearDown()
    }
    
    // MARK: - Test Data Setup
    
    private func createTestExpenses() -> (regular: [Expense], generatedFromTemplate: [Expense]) {
        // Create categories for testing
        let groceryCategory = createTestCategory(name: "Groceries", context: testContext)
        let gasCategory = createTestCategory(name: "Gas", context: testContext)
        
        // Create regular expenses (no recurring template)
        let regularExpense1 = createTestExpense(
            amount: 50.00,
            merchant: "Regular Store",
            category: groceryCategory,
            context: testContext
        )
        
        let regularExpense2 = createTestExpense(
            amount: 75.00,
            merchant: "Another Store",
            category: gasCategory,
            context: testContext
        )
        
        // Create a recurring template
        let recurringTemplate = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(value: 100.00),
            currencyCode: "USD",
            merchant: "Monthly Subscription",
            notes: "Test recurring expense",
            paymentMethod: "Credit Card",
            category: groceryCategory,
            tags: [],
            patternType: .monthly,
            interval: 1,
            dayOfMonth: 15,
            dayOfWeek: nil,
            startDate: Date()
        )
        
        // Create expenses generated from the template
        let generatedExpense1 = createTestExpense(
            amount: 100.00,
            merchant: "Monthly Subscription",
            category: groceryCategory,
            context: testContext
        )
        generatedExpense1.recurringTemplate = recurringTemplate
        
        let generatedExpense2 = createTestExpense(
            amount: 100.00,
            merchant: "Monthly Subscription",
            category: groceryCategory,
            context: testContext
        )
        generatedExpense2.recurringTemplate = recurringTemplate
        
        // Save context
        try! testContext.save()
        
        return (
            regular: [regularExpense1, regularExpense2],
            generatedFromTemplate: [generatedExpense1, generatedExpense2]
        )
    }
    
    // MARK: - Filter Tests
    
    func testFilterAllExpenses() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            recurringFilter: nil // No filter = show all
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 4, "Should return all expenses when no recurring filter is applied")
        XCTAssertTrue(filteredExpenses.contains(testData.regular[0]))
        XCTAssertTrue(filteredExpenses.contains(testData.regular[1]))
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[0]))
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[1]))
    }
    
    func testFilterGeneratedFromTemplates() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            recurringFilter: .generatedFromTemplates
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 2, "Should return only expenses generated from templates")
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[0]))
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[1]))
        XCTAssertFalse(filteredExpenses.contains(testData.regular[0]))
        XCTAssertFalse(filteredExpenses.contains(testData.regular[1]))
    }
    
    func testFilterNonRecurring() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            recurringFilter: .nonRecurring
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 2, "Should return only non-recurring expenses")
        XCTAssertTrue(filteredExpenses.contains(testData.regular[0]))
        XCTAssertTrue(filteredExpenses.contains(testData.regular[1]))
        XCTAssertFalse(filteredExpenses.contains(testData.generatedFromTemplate[0]))
        XCTAssertFalse(filteredExpenses.contains(testData.generatedFromTemplate[1]))
    }
    
    func testRecurringFilterWithOtherFilters() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        // Create a category filter for groceries
        let groceryCategory = testData.regular[0].category!
        let categoryData = CategoryData(id: groceryCategory.id, name: groceryCategory.name)
        
        let criteria = ExpenseFilterService.FilterCriteria(
            category: categoryData,
            recurringFilter: .generatedFromTemplates
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 2, "Should return only grocery expenses generated from templates")
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[0]))
        XCTAssertTrue(filteredExpenses.contains(testData.generatedFromTemplate[1]))
        
        // Verify all returned expenses are in the grocery category
        for expense in filteredExpenses {
            XCTAssertEqual(expense.category?.id, groceryCategory.id)
            XCTAssertNotNil(expense.recurringTemplate, "Should have recurring template")
        }
    }
    
    func testRecurringFilterWithAmountRange() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            amountRange: 90...110, // Should match the $100 generated expenses
            recurringFilter: .generatedFromTemplates
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 2, "Should return generated expenses in the amount range")
        for expense in filteredExpenses {
            XCTAssertTrue(expense.amount.decimalValue >= 90 && expense.amount.decimalValue <= 110)
            XCTAssertNotNil(expense.recurringTemplate)
        }
    }
    
    func testRecurringFilterWithSearchText() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            searchText: "Monthly",
            recurringFilter: .generatedFromTemplates
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 2, "Should return generated expenses matching search text")
        for expense in filteredExpenses {
            XCTAssertTrue(expense.merchant.contains("Monthly"))
            XCTAssertNotNil(expense.recurringTemplate)
        }
    }
    
    func testEmptyResultsWithRecurringFilter() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        // Filter for non-recurring expenses with a merchant that only exists in generated expenses
        let criteria = ExpenseFilterService.FilterCriteria(
            vendor: "Monthly Subscription",
            recurringFilter: .nonRecurring
        )
        
        // When
        let filteredExpenses = filterService.filter(allExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(filteredExpenses.count, 0, "Should return no results when filters conflict")
    }
    
    // MARK: - Filter Criteria Tests
    
    func testFilterCriteriaIsEmpty() {
        // Given
        let emptyFilter = ExpenseFilterService.FilterCriteria()
        let filterWithRecurring = ExpenseFilterService.FilterCriteria(recurringFilter: .nonRecurring)
        
        // Then
        XCTAssertTrue(emptyFilter.isEmpty, "Empty filter criteria should be empty")
        XCTAssertFalse(filterWithRecurring.isEmpty, "Filter criteria with recurring filter should not be empty")
    }
    
    func testFilterCriteriaDescription() {
        // Given
        let generatedFilter = ExpenseFilterService.FilterCriteria(recurringFilter: .generatedFromTemplates)
        let nonRecurringFilter = ExpenseFilterService.FilterCriteria(recurringFilter: .nonRecurring)
        
        // Then
        XCTAssertTrue(generatedFilter.activeFiltersDescription.contains("Generated from templates"))
        XCTAssertTrue(nonRecurringFilter.activeFiltersDescription.contains("Non-recurring only"))
    }
    
    // MARK: - Performance Tests
    
    func testRecurringFilterPerformance() {
        // Given
        let testData = createTestExpenses()
        let allExpenses = testData.regular + testData.generatedFromTemplate
        
        let criteria = ExpenseFilterService.FilterCriteria(
            recurringFilter: .generatedFromTemplates
        )
        
        // When & Then
        measure {
            _ = filterService.filter(allExpenses, with: criteria)
        }
    }
}

// MARK: - Test Helpers

extension RecurringExpenseFilterTests {
    
    private func createTestCategory(name: String, context: NSManagedObjectContext) -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: context)
        category.id = UUID()
        category.name = name
        category.colorHex = "#FF0000"
        category.icon = "tag"
        category.isDefault = false
        return category
    }
    
    private func createTestExpense(
        amount: Double,
        merchant: String,
        category: ReceiptScannerExpenseTracker.Category,
        context: NSManagedObjectContext
    ) -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: amount)
        expense.currencyCode = "USD"
        expense.date = Date()
        expense.merchant = merchant
        expense.category = category
        expense.isRecurring = false
        return expense
    }
}