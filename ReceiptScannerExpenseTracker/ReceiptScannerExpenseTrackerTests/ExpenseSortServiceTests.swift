import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class ExpenseSortServiceTests: XCTestCase {
    
    var sortService: ExpenseSortService!
    var testContext: NSManagedObjectContext!
    var testExpenses: [Expense] = []
    
    override func setUp() async throws {
        try await super.setUp()
        
        sortService = ExpenseSortService()
        
        // Set up in-memory Core Data stack for testing
        let container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load store: \(error)")
            }
        }
        
        testContext = container.viewContext
        await createTestData()
    }
    
    override func tearDown() async throws {
        sortService = nil
        testContext = nil
        testExpenses = []
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestData() async {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create test categories
        let foodCategory = Category(context: testContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        
        let transportCategory = Category(context: testContext)
        transportCategory.id = UUID()
        transportCategory.name = "Transportation"
        
        let shoppingCategory = Category(context: testContext)
        shoppingCategory.id = UUID()
        shoppingCategory.name = "Shopping"
        
        // Create test expenses with different dates, amounts, merchants, etc.
        let expense1 = Expense(context: testContext)
        expense1.id = UUID()
        expense1.amount = NSDecimalNumber(string: "25.99")
        expense1.merchant = "McDonald's"
        expense1.date = calendar.date(byAdding: .day, value: -1, to: baseDate) ?? baseDate
        expense1.paymentMethod = "Credit Card"
        expense1.isRecurring = false
        expense1.category = foodCategory
        
        let expense2 = Expense(context: testContext)
        expense2.id = UUID()
        expense2.amount = NSDecimalNumber(string: "100.00")
        expense2.merchant = "Uber"
        expense2.date = calendar.date(byAdding: .day, value: -3, to: baseDate) ?? baseDate
        expense2.paymentMethod = "Credit Card"
        expense2.isRecurring = false
        expense2.category = transportCategory
        
        let expense3 = Expense(context: testContext)
        expense3.id = UUID()
        expense3.amount = NSDecimalNumber(string: "15.50")
        expense3.merchant = "Starbucks"
        expense3.date = calendar.date(byAdding: .day, value: -2, to: baseDate) ?? baseDate
        expense3.paymentMethod = "Cash"
        expense3.isRecurring = true
        expense3.category = foodCategory
        
        let expense4 = Expense(context: testContext)
        expense4.id = UUID()
        expense4.amount = NSDecimalNumber(string: "75.25")
        expense4.merchant = "Amazon"
        expense4.date = baseDate // Most recent
        expense4.paymentMethod = "Debit Card"
        expense4.isRecurring = true
        expense4.category = shoppingCategory
        
        let expense5 = Expense(context: testContext)
        expense5.id = UUID()
        expense5.amount = NSDecimalNumber(string: "50.00")
        expense5.merchant = "Best Buy"
        expense5.date = calendar.date(byAdding: .day, value: -4, to: baseDate) ?? baseDate // Oldest
        expense5.paymentMethod = "Credit Card"
        expense5.isRecurring = false
        expense5.category = shoppingCategory
        
        try? testContext.save()
        
        testExpenses = [expense1, expense2, expense3, expense4, expense5]
    }
    
    // MARK: - Basic Sorting Tests
    
    func testSort_EmptyArray_ReturnsEmptyArray() {
        // Given
        let emptyExpenses: [Expense] = []
        
        // When
        let result = sortService.sort(emptyExpenses, by: .dateDescending)
        
        // Then
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Date Sorting Tests
    
    func testSort_DateDescending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .dateDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify order: Amazon (today), McDonald's (-1), Starbucks (-2), Uber (-3), Best Buy (-4)
        XCTAssertEqual(result[0].merchant, "Amazon")
        XCTAssertEqual(result[1].merchant, "McDonald's")
        XCTAssertEqual(result[2].merchant, "Starbucks")
        XCTAssertEqual(result[3].merchant, "Uber")
        XCTAssertEqual(result[4].merchant, "Best Buy")
        
        // Verify dates are in descending order
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i].date, result[i + 1].date)
        }
    }
    
    func testSort_DateAscending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .dateAscending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify order: Best Buy (-4), Uber (-3), Starbucks (-2), McDonald's (-1), Amazon (today)
        XCTAssertEqual(result[0].merchant, "Best Buy")
        XCTAssertEqual(result[1].merchant, "Uber")
        XCTAssertEqual(result[2].merchant, "Starbucks")
        XCTAssertEqual(result[3].merchant, "McDonald's")
        XCTAssertEqual(result[4].merchant, "Amazon")
        
        // Verify dates are in ascending order
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i].date, result[i + 1].date)
        }
    }
    
    // MARK: - Amount Sorting Tests
    
    func testSort_AmountDescending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .amountDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify order by amount: Uber (100), Amazon (75.25), Best Buy (50), McDonald's (25.99), Starbucks (15.50)
        XCTAssertEqual(result[0].merchant, "Uber")
        XCTAssertEqual(result[1].merchant, "Amazon")
        XCTAssertEqual(result[2].merchant, "Best Buy")
        XCTAssertEqual(result[3].merchant, "McDonald's")
        XCTAssertEqual(result[4].merchant, "Starbucks")
        
        // Verify amounts are in descending order
        for i in 0..<(result.count - 1) {
            XCTAssertGreaterThanOrEqual(result[i].amount.decimalValue, result[i + 1].amount.decimalValue)
        }
    }
    
    func testSort_AmountAscending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .amountAscending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify order by amount: Starbucks (15.50), McDonald's (25.99), Best Buy (50), Amazon (75.25), Uber (100)
        XCTAssertEqual(result[0].merchant, "Starbucks")
        XCTAssertEqual(result[1].merchant, "McDonald's")
        XCTAssertEqual(result[2].merchant, "Best Buy")
        XCTAssertEqual(result[3].merchant, "Amazon")
        XCTAssertEqual(result[4].merchant, "Uber")
        
        // Verify amounts are in ascending order
        for i in 0..<(result.count - 1) {
            XCTAssertLessThanOrEqual(result[i].amount.decimalValue, result[i + 1].amount.decimalValue)
        }
    }
    
    // MARK: - Merchant Sorting Tests
    
    func testSort_MerchantAscending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .merchantAscending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify alphabetical order: Amazon, Best Buy, McDonald's, Starbucks, Uber
        XCTAssertEqual(result[0].merchant, "Amazon")
        XCTAssertEqual(result[1].merchant, "Best Buy")
        XCTAssertEqual(result[2].merchant, "McDonald's")
        XCTAssertEqual(result[3].merchant, "Starbucks")
        XCTAssertEqual(result[4].merchant, "Uber")
        
        // Verify merchants are in ascending order
        for i in 0..<(result.count - 1) {
            let comparison = result[i].merchant.localizedCaseInsensitiveCompare(result[i + 1].merchant)
            XCTAssertTrue(comparison == .orderedAscending || comparison == .orderedSame)
        }
    }
    
    func testSort_MerchantDescending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .merchantDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify reverse alphabetical order: Uber, Starbucks, McDonald's, Best Buy, Amazon
        XCTAssertEqual(result[0].merchant, "Uber")
        XCTAssertEqual(result[1].merchant, "Starbucks")
        XCTAssertEqual(result[2].merchant, "McDonald's")
        XCTAssertEqual(result[3].merchant, "Best Buy")
        XCTAssertEqual(result[4].merchant, "Amazon")
    }
    
    // MARK: - Category Sorting Tests
    
    func testSort_CategoryAscending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .categoryAscending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify category order: Food (McDonald's, Starbucks), Shopping (Amazon, Best Buy), Transportation (Uber)
        let categories = result.map { $0.category?.name ?? "" }
        let expectedOrder = ["Food", "Food", "Shopping", "Shopping", "Transportation"]
        XCTAssertEqual(categories, expectedOrder)
    }
    
    func testSort_CategoryDescending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .categoryDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify reverse category order: Transportation, Shopping, Food
        let firstCategory = result.first?.category?.name
        XCTAssertEqual(firstCategory, "Transportation")
    }
    
    // MARK: - Payment Method Sorting Tests
    
    func testSort_PaymentMethodAscending_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .paymentMethodAscending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Verify payment method order: Cash, Credit Card, Credit Card, Credit Card, Debit Card
        let paymentMethods = result.map { $0.paymentMethod ?? "" }
        XCTAssertEqual(paymentMethods[0], "Cash")
        XCTAssertEqual(paymentMethods.last, "Debit Card")
    }
    
    // MARK: - Recurring Sorting Tests
    
    func testSort_RecurringFirst_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .recurringFirst)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // First expenses should be recurring
        XCTAssertTrue(result[0].isRecurring)
        XCTAssertTrue(result[1].isRecurring)
        
        // Remaining should be non-recurring
        for i in 2..<result.count {
            XCTAssertFalse(result[i].isRecurring)
        }
    }
    
    func testSort_NonRecurringFirst_ReturnsSortedExpenses() {
        // When
        let result = sortService.sort(testExpenses, by: .nonRecurringFirst)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // First expenses should be non-recurring
        XCTAssertFalse(result[0].isRecurring)
        XCTAssertFalse(result[1].isRecurring)
        XCTAssertFalse(result[2].isRecurring)
        
        // Last expenses should be recurring
        XCTAssertTrue(result[3].isRecurring)
        XCTAssertTrue(result[4].isRecurring)
    }
    
    // MARK: - Multi-Level Sorting Tests
    
    func testSort_MultiLevel_PrimaryAndSecondary() {
        // When - Sort by category first, then by amount descending
        let result = sortService.sort(testExpenses, by: .categoryAscending, then: .amountDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        
        // Within Food category, McDonald's (25.99) should come before Starbucks (15.50)
        let foodExpenses = result.filter { $0.category?.name == "Food" }
        XCTAssertEqual(foodExpenses.count, 2)
        XCTAssertEqual(foodExpenses[0].merchant, "McDonald's")
        XCTAssertEqual(foodExpenses[1].merchant, "Starbucks")
        
        // Within Shopping category, Amazon (75.25) should come before Best Buy (50.00)
        let shoppingExpenses = result.filter { $0.category?.name == "Shopping" }
        XCTAssertEqual(shoppingExpenses.count, 2)
        XCTAssertEqual(shoppingExpenses[0].merchant, "Amazon")
        XCTAssertEqual(shoppingExpenses[1].merchant, "Best Buy")
    }
    
    // MARK: - Async Sorting Tests
    
    func testSortAsync_SmallDataset_UsesSyncSort() async {
        // When
        let result = await sortService.sortAsync(testExpenses, by: .dateDescending)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        XCTAssertEqual(result[0].merchant, "Amazon") // Most recent
    }
    
    func testSortAsync_LargeDataset_UsesAsyncSort() async {
        // Given - Create a larger dataset
        var largeDataset = testExpenses
        for i in 0..<200 {
            let expense = Expense(context: testContext)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(value: Double(i))
            expense.merchant = "Merchant \(i)"
            expense.date = Date()
            largeDataset.append(expense)
        }
        
        // When
        let result = await sortService.sortAsync(largeDataset, by: .amountDescending)
        
        // Then
        XCTAssertEqual(result.count, largeDataset.count)
        // Verify first item has highest amount
        XCTAssertEqual(result[0].merchant, "Merchant 199")
    }
    
    // MARK: - Sort Option Tests
    
    func testSortOption_DisplayNames() {
        XCTAssertEqual(ExpenseSortService.SortOption.dateAscending.displayName, "Date (Oldest First)")
        XCTAssertEqual(ExpenseSortService.SortOption.dateDescending.displayName, "Date (Newest First)")
        XCTAssertEqual(ExpenseSortService.SortOption.amountAscending.displayName, "Amount (Low to High)")
        XCTAssertEqual(ExpenseSortService.SortOption.amountDescending.displayName, "Amount (High to Low)")
    }
    
    func testSortOption_IconNames() {
        XCTAssertEqual(ExpenseSortService.SortOption.dateAscending.iconName, "calendar")
        XCTAssertEqual(ExpenseSortService.SortOption.amountAscending.iconName, "dollarsign.circle")
        XCTAssertEqual(ExpenseSortService.SortOption.merchantAscending.iconName, "building.2")
        XCTAssertEqual(ExpenseSortService.SortOption.categoryAscending.iconName, "folder")
    }
    
    func testSortOption_IsAscending() {
        XCTAssertTrue(ExpenseSortService.SortOption.dateAscending.isAscending)
        XCTAssertFalse(ExpenseSortService.SortOption.dateDescending.isAscending)
        XCTAssertTrue(ExpenseSortService.SortOption.amountAscending.isAscending)
        XCTAssertFalse(ExpenseSortService.SortOption.amountDescending.isAscending)
    }
    
    func testSortOption_DefaultAndCommon() {
        let defaultOption = ExpenseSortService.defaultSortOption
        XCTAssertEqual(defaultOption, ExpenseSortService.SortOption.dateDescending)
        
        let commonOptions = ExpenseSortService.commonSortOptions
        XCTAssertTrue(commonOptions.contains(ExpenseSortService.SortOption.dateDescending))
        XCTAssertTrue(commonOptions.contains(ExpenseSortService.SortOption.amountDescending))
        XCTAssertTrue(commonOptions.contains(ExpenseSortService.SortOption.merchantAscending))
    }
    
    func testSortOption_GroupedOptions() {
        let grouped = ExpenseSortService.SortOption.groupedOptions
        
        XCTAssertNotNil(grouped["Date"])
        XCTAssertNotNil(grouped["Amount"])
        XCTAssertNotNil(grouped["Merchant"])
        XCTAssertNotNil(grouped["Category"])
        XCTAssertNotNil(grouped["Payment"])
        XCTAssertNotNil(grouped["Type"])
        
        XCTAssertEqual(grouped["Date"]?.count, 2)
        XCTAssertEqual(grouped["Amount"]?.count, 2)
    }
    
    // MARK: - Error Handling Tests
    
    func testSort_WithCorruptedData_ReturnsOriginalArray() {
        // Given - Create an expense with nil merchant (simulating corrupted data)
        let corruptedExpense = Expense(context: testContext)
        corruptedExpense.id = UUID()
        corruptedExpense.amount = NSDecimalNumber(string: "10.00")
        corruptedExpense.merchant = "" // Empty merchant
        corruptedExpense.date = Date()
        
        var expensesWithCorrupted = testExpenses
        expensesWithCorrupted.append(corruptedExpense)
        
        // When
        let result = sortService.sort(expensesWithCorrupted, by: .merchantAscending)
        
        // Then - Should still return all expenses, handling the corrupted data gracefully
        XCTAssertEqual(result.count, expensesWithCorrupted.count)
    }
    
    // MARK: - Performance Tests
    
    func testSort_PerformanceWithLargeDataset() {
        // Given - Create a large dataset
        var largeDataset: [Expense] = []
        for i in 0..<1000 {
            let expense = Expense(context: testContext)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(value: Double.random(in: 1...1000))
            expense.merchant = "Merchant \(i)"
            expense.date = Date().addingTimeInterval(TimeInterval(-i * 3600)) // Different dates
            largeDataset.append(expense)
        }
        
        // When/Then - Measure performance
        measure {
            _ = sortService.sort(largeDataset, by: .dateDescending)
        }
    }
}