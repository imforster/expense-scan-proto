import XCTest
import CoreData
import Combine
@testable import ReceiptScannerExpenseTracker

final class ExpenseFilterServiceTests: XCTestCase {
    
    var filterService: ExpenseFilterService!
    var testContext: NSManagedObjectContext!
    var testExpenses: [Expense] = []
    var cancellables: Set<AnyCancellable> = []
    
    override func setUp() async throws {
        try await super.setUp()
        
        filterService = ExpenseFilterService()
        
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
        filterService.clearCache()
        filterService = nil
        testContext = nil
        testExpenses = []
        cancellables.removeAll()
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestData() async {
        // Create test categories
        let foodCategory = Category(context: testContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.colorHex = "FF5733"
        
        let transportCategory = Category(context: testContext)
        transportCategory.id = UUID()
        transportCategory.name = "Transportation"
        transportCategory.colorHex = "33A8FF"
        
        // Create test tags
        let businessTag = Tag(context: testContext)
        businessTag.id = UUID()
        businessTag.name = "Business"
        
        let personalTag = Tag(context: testContext)
        personalTag.id = UUID()
        personalTag.name = "Personal"
        
        // Create test expenses
        let expense1 = Expense(context: testContext)
        expense1.id = UUID()
        expense1.amount = NSDecimalNumber(string: "25.99")
        expense1.merchant = "McDonald's"
        expense1.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        expense1.notes = "Quick lunch"
        expense1.paymentMethod = "Credit Card"
        expense1.isRecurring = false
        expense1.category = foodCategory
        expense1.addToTags(personalTag)
        
        let expense2 = Expense(context: testContext)
        expense2.id = UUID()
        expense2.amount = NSDecimalNumber(string: "45.50")
        expense2.merchant = "Uber"
        expense2.date = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        expense2.notes = "Ride to airport"
        expense2.paymentMethod = "Credit Card"
        expense2.isRecurring = false
        expense2.category = transportCategory
        expense2.addToTags(businessTag)
        
        let expense3 = Expense(context: testContext)
        expense3.id = UUID()
        expense3.amount = NSDecimalNumber(string: "15.00")
        expense3.merchant = "Starbucks"
        expense3.date = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        expense3.notes = "Morning coffee"
        expense3.paymentMethod = "Cash"
        expense3.isRecurring = true
        expense3.category = foodCategory
        expense3.addToTags(personalTag)
        
        let expense4 = Expense(context: testContext)
        expense4.id = UUID()
        expense4.amount = NSDecimalNumber(string: "100.00")
        expense4.merchant = "Shell Gas Station"
        expense4.date = Calendar.current.date(byAdding: .day, value: -4, to: Date()) ?? Date()
        expense4.notes = "Gas for road trip"
        expense4.paymentMethod = "Debit Card"
        expense4.isRecurring = false
        expense4.category = transportCategory
        expense4.addToTags(personalTag)
        
        // Create receipt for one expense
        let receipt = Receipt(context: testContext)
        receipt.id = UUID()
        receipt.expense = expense1
        if let url = URL(string: "file:///test.jpg") {
            receipt.imageURL = url
        } else {
            // Use a valid file URL as fallback
            receipt.imageURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.jpg")
        }
        receipt.date = expense1.date
        
        try? testContext.save()
        
        testExpenses = [expense1, expense2, expense3, expense4]
    }
    
    // MARK: - Basic Filtering Tests
    
    func testFilter_EmptyCriteria_ReturnsAllExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria()
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, testExpenses.count)
        XCTAssertTrue(criteria.isEmpty)
    }
    
    func testFilter_EmptyExpenseArray_ReturnsEmptyArray() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "test")
        
        // When
        let result = filterService.filter([], with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Search Text Filtering Tests
    
    func testFilter_SearchByMerchant_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "McDonald")
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.merchant, "McDonald's")
    }
    
    func testFilter_SearchByNotes_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "coffee")
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.merchant, "Starbucks")
    }
    
    func testFilter_SearchCaseInsensitive_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "UBER")
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.merchant, "Uber")
    }
    
    func testFilter_SearchNoMatch_ReturnsEmptyArray() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "NonExistentMerchant")
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Category Filtering Tests
    
    func testFilter_ByCategory_ReturnsMatchingExpenses() {
        // Given
        let foodCategory = testExpenses.first?.category
        let categoryData = CategoryData(from: foodCategory!)
        let criteria = ExpenseFilterService.FilterCriteria(category: categoryData)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 2) // McDonald's and Starbucks
        XCTAssertTrue(result.allSatisfy { $0.category?.name == "Food" })
    }
    
    // MARK: - Date Range Filtering Tests
    
    func testFilter_ByDateRange_ReturnsMatchingExpenses() {
        // Given
        let today = Date()
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today
        let dateRange = DateInterval(start: twoDaysAgo, end: today)
        let criteria = ExpenseFilterService.FilterCriteria(dateRange: dateRange)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 2) // McDonald's and Uber (within last 2 days)
    }
    
    func testFilter_TodayOnly_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria.today()
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        // Should return 0 since all test expenses are from previous days
        XCTAssertEqual(result.count, 0)
    }
    
    // MARK: - Amount Range Filtering Tests
    
    func testFilter_ByAmountRange_ReturnsMatchingExpenses() {
        // Given
        let amountRange: ClosedRange<Decimal> = 20.00...50.00
        let criteria = ExpenseFilterService.FilterCriteria(amountRange: amountRange)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 2) // McDonald's (25.99) and Uber (45.50)
    }
    
    func testFilter_AmountAbove_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria.amountAbove(50.00)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // Shell Gas Station (100.00)
    }
    
    func testFilter_AmountBelow_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria.amountBelow(20.00)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // Starbucks (15.00)
    }
    
    // MARK: - Payment Method Filtering Tests
    
    func testFilter_ByPaymentMethod_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(paymentMethod: "Credit Card")
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 2) // McDonald's and Uber
    }
    
    // MARK: - Recurring Filtering Tests
    
    func testFilter_RecurringOnly_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(isRecurring: true)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // Starbucks
        XCTAssertTrue(result.first?.isRecurring == true)
    }
    
    func testFilter_NonRecurringOnly_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(isRecurring: false)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 3) // All except Starbucks
        XCTAssertTrue(result.allSatisfy { !$0.isRecurring })
    }
    
    // MARK: - Receipt Filtering Tests
    
    func testFilter_WithReceipt_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(hasReceipt: true)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // McDonald's (has receipt)
    }
    
    func testFilter_WithoutReceipt_ReturnsMatchingExpenses() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(hasReceipt: false)
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 3) // All except McDonald's
    }
    
    // MARK: - Tag Filtering Tests
    
    func testFilter_ByTags_ReturnsMatchingExpenses() {
        // Given
        let personalTag = testExpenses.first?.tags?.allObjects.first as? Tag
        let tagData = TagData(from: personalTag!)
        let criteria = ExpenseFilterService.FilterCriteria(tags: [tagData])
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 3) // McDonald's, Starbucks, Shell (all have Personal tag)
    }
    
    // MARK: - Multiple Criteria Filtering Tests
    
    func testFilter_MultipleCriteria_ReturnsMatchingExpenses() {
        // Given
        let foodCategory = testExpenses.first?.category
        let categoryData = CategoryData(from: foodCategory!)
        let criteria = ExpenseFilterService.FilterCriteria(
            category: categoryData,
            paymentMethod: "Credit Card"
        )
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // Only McDonald's (Food category + Credit Card)
    }
    
    func testFilter_ComplexCriteria_ReturnsMatchingExpenses() {
        // Given
        let amountRange: ClosedRange<Decimal> = 10.00...30.00
        let criteria = ExpenseFilterService.FilterCriteria(
            searchText: "coffee",
            amountRange: amountRange,
            isRecurring: true
        )
        
        // When
        let result = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result.count, 1) // Starbucks (matches all criteria)
    }
    
    // MARK: - Debounced Filtering Tests
    
    func testDebounceFilter_DelaysExecution() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "McDonald")
        let expectation = XCTestExpectation(description: "Debounced filter")
        
        // When
        filterService.debounceFilter(testExpenses, with: criteria)
            .sink { result in
                XCTAssertEqual(result.count, 1)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Cache Tests
    
    func testFilter_UsesCaching() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "McDonald")
        
        // When - First call
        let result1 = filterService.filter(testExpenses, with: criteria)
        
        // When - Second call with same criteria
        let result2 = filterService.filter(testExpenses, with: criteria)
        
        // Then
        XCTAssertEqual(result1.count, result2.count)
        XCTAssertEqual(result1.first?.merchant, result2.first?.merchant)
        
        let cacheStats = filterService.cacheStatistics
        XCTAssertEqual(cacheStats.count, 1)
    }
    
    func testClearCache_RemovesCachedResults() {
        // Given
        let criteria = ExpenseFilterService.FilterCriteria(searchText: "McDonald")
        _ = filterService.filter(testExpenses, with: criteria)
        
        // When
        filterService.clearCache()
        
        // Then
        let cacheStats = filterService.cacheStatistics
        XCTAssertEqual(cacheStats.count, 0)
    }
    
    // MARK: - Filter Criteria Tests
    
    func testFilterCriteria_ActiveFiltersDescription() {
        // Given
        let foodCategory = testExpenses.first?.category
        let categoryData = CategoryData(from: foodCategory!)
        let criteria = ExpenseFilterService.FilterCriteria(
            searchText: "test",
            category: categoryData,
            paymentMethod: "Credit Card"
        )
        
        // When
        let description = criteria.activeFiltersDescription
        
        // Then
        XCTAssertTrue(description.contains("Search: test"))
        XCTAssertTrue(description.contains("Category: Food"))
        XCTAssertTrue(description.contains("Payment: Credit Card"))
    }
    
    func testFilterCriteria_IsEmpty() {
        // Given
        let emptyCriteria = ExpenseFilterService.FilterCriteria()
        let nonEmptyCriteria = ExpenseFilterService.FilterCriteria(searchText: "test")
        
        // Then
        XCTAssertTrue(emptyCriteria.isEmpty)
        XCTAssertFalse(nonEmptyCriteria.isEmpty)
    }
    
    // MARK: - Convenience Methods Tests
    
    func testFilterCriteria_ConvenienceMethods() {
        // Test thisMonth
        let thisMonth = ExpenseFilterService.FilterCriteria.thisMonth()
        XCTAssertNotNil(thisMonth.dateRange)
        
        // Test thisWeek
        let thisWeek = ExpenseFilterService.FilterCriteria.thisWeek()
        XCTAssertNotNil(thisWeek.dateRange)
        
        // Test today
        let today = ExpenseFilterService.FilterCriteria.today()
        XCTAssertNotNil(today.dateRange)
        
        // Test amount filters
        let amountAbove = ExpenseFilterService.FilterCriteria.amountAbove(50.00)
        XCTAssertNotNil(amountAbove.amountRange)
        XCTAssertEqual(amountAbove.amountRange?.lowerBound, 50.00)
        
        let amountBelow = ExpenseFilterService.FilterCriteria.amountBelow(100.00)
        XCTAssertNotNil(amountBelow.amountRange)
        XCTAssertEqual(amountBelow.amountRange?.upperBound, 100.00)
    }
}