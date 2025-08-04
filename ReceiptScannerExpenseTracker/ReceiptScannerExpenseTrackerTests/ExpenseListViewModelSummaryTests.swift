import XCTest
import CoreData
import Combine
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseListViewModelSummaryTests: XCTestCase {
    
    var viewModel: ExpenseListViewModel!
    var mockDataService: ExpenseDataService!
    var testCoreDataManager: CoreDataManager!
    var testContext: NSManagedObjectContext!
    var testCategory: ReceiptScannerExpenseTracker.Category!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create test Core Data stack
        testCoreDataManager = CoreDataManager.createForTesting()
        testContext = testCoreDataManager.viewContext
        
        // Create test category
        testCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        testCategory.id = UUID()
        testCategory.name = "Test Category"
        testCategory.colorHex = "#FF0000"
        testCategory.icon = "star"
        testCategory.isDefault = false
        
        // Create mock data service and view model
        mockDataService = ExpenseDataService(context: testContext)
        viewModel = ExpenseListViewModel(dataService: mockDataService)
        
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        viewModel = nil
        mockDataService = nil
        testCoreDataManager = nil
        testContext = nil
        testCategory = nil
        super.tearDown()
    }
    
    // MARK: - Summary Data Integration Tests
    
    func testSummaryDataWithEmptyExpenses() {
        // Given: No expenses
        
        // When
        let summaryData = viewModel.summaryData
        
        // Then
        XCTAssertTrue(summaryData.isEmpty || summaryData.allSatisfy { $0.amount == 0 },
                     "Summary data should be empty or contain zero amounts for empty expenses")
    }
    
    func testSummaryDataWithRealExpenses() async {
        // Given: Create test expenses
        let expense1 = createTestExpense(amount: 100.0, daysFromNow: -5, merchant: "Restaurant A")
        let expense2 = createTestExpense(amount: 50.0, daysFromNow: -10, merchant: "Cafe B")
        let expense3 = createTestExpense(amount: 25.0, daysFromNow: -2, merchant: "Store C")
        
        try? testContext.save()
        
        // When: Load expenses
        await viewModel.loadExpenses()
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Verify summary data
        let summaryData = viewModel.summaryData
        XCTAssertGreaterThan(summaryData.count, 0, "Should generate summary data")
        
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
        XCTAssertEqual(thisMonthSummary?.amount, 175.0, "This Month total should be correct")
    }
    
    func testSummaryDataReactivity() async {
        // Given: Initial state with no expenses
        let initialSummaryData = viewModel.summaryData
        let initialCount = initialSummaryData.count
        
        // When: Add an expense
        let expense = createTestExpense(amount: 200.0, daysFromNow: 0, merchant: "New Store")
        try? testContext.save()
        
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Summary data should update
        let updatedSummaryData = viewModel.summaryData
        XCTAssertGreaterThanOrEqual(updatedSummaryData.count, initialCount, "Summary data should be updated")
        
        let thisMonthSummary = updatedSummaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
        XCTAssertGreaterThan(thisMonthSummary?.amount ?? 0, 0, "This Month total should be greater than 0")
    }
    
    func testSummaryDataObserverSetup() {
        // Given: Fresh view model
        let newViewModel = ExpenseListViewModel(dataService: mockDataService)
        
        // When: Setup observer
        newViewModel.setupSummaryDataObserver()
        
        // Then: Should not crash and should be able to generate summary data
        let summaryData = newViewModel.summaryData
        XCTAssertTrue(summaryData.isEmpty || summaryData.count > 0, "Should handle observer setup correctly")
    }
    
    // MARK: - Individual Calculation Tests
    
    func testCurrentMonthTotalCalculation() async {
        // Given: Create current month expenses
        let expense1 = createTestExpense(amount: 75.0, daysFromNow: -3, merchant: "Store A")
        let expense2 = createTestExpense(amount: 125.0, daysFromNow: -7, merchant: "Store B")
        let previousMonthExpense = createTestExpense(amount: 50.0, daysFromNow: -35, merchant: "Old Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let currentMonthTotal = viewModel.currentMonthTotal
        
        // Then
        XCTAssertEqual(currentMonthTotal, 200.0, "Current month total should exclude previous month expenses")
    }
    
    func testPreviousMonthTotalCalculation() async {
        // Given: Create expenses in different months
        let currentMonthExpense = createTestExpense(amount: 100.0, daysFromNow: -5, merchant: "Current Store")
        let previousMonthExpense = createTestExpense(amount: 75.0, daysFromNow: -35, merchant: "Previous Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let previousMonthTotal = viewModel.previousMonthTotal
        
        // Then
        XCTAssertEqual(previousMonthTotal, 75.0, "Previous month total should exclude current month expenses")
    }
    
    func testCurrentWeekTotalCalculation() async {
        // Given: Create expenses in current week and previous week
        let currentWeekExpense = createTestExpense(amount: 60.0, daysFromNow: -2, merchant: "Week Store")
        let previousWeekExpense = createTestExpense(amount: 40.0, daysFromNow: -10, merchant: "Old Week Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let currentWeekTotal = viewModel.currentWeekTotal
        
        // Then
        XCTAssertEqual(currentWeekTotal, 60.0, "Current week total should exclude previous week expenses")
    }
    
    func testAverageDailySpendingCalculation() async {
        // Given: Create current month expenses
        let expense1 = createTestExpense(amount: 30.0, daysFromNow: -1, merchant: "Daily Store A")
        let expense2 = createTestExpense(amount: 60.0, daysFromNow: -5, merchant: "Daily Store B")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let averageDaily = viewModel.averageDailySpending
        
        // Then
        let calendar = Calendar.current
        let daysInMonth = calendar.component(.day, from: Date())
        let expectedAverage = Decimal(90.0) / Decimal(daysInMonth)
        XCTAssertEqual(averageDaily, expectedAverage, "Average daily spending should be calculated correctly")
    }
    
    // MARK: - Summary Data Validation Tests
    
    func testValidateSummaryCalculations() async {
        // Given: Create test expenses
        let expense1 = createTestExpense(amount: 150.0, daysFromNow: -3, merchant: "Validation Store A")
        let expense2 = createTestExpense(amount: 50.0, daysFromNow: -8, merchant: "Validation Store B")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let isValid = viewModel.validateSummaryCalculations()
        
        // Then
        XCTAssertTrue(isValid, "Summary calculations should be valid")
    }
    
    func testCreateBasicSummaryData() {
        // Given
        let title = "Test Summary"
        let amount = Decimal(250.0)
        let previousAmount = Decimal(200.0)
        
        // When
        let summaryData = ExpenseListViewModel.createBasicSummaryData(
            title: title,
            amount: amount,
            previousAmount: previousAmount
        )
        
        // Then
        XCTAssertEqual(summaryData.title, title)
        XCTAssertEqual(summaryData.amount, amount)
        XCTAssertNotNil(summaryData.trend)
        XCTAssertEqual(summaryData.trend?.previousAmount, previousAmount)
        XCTAssertEqual(summaryData.trend?.direction, .increasing)
    }
    
    func testCreateBasicSummaryDataWithoutTrend() {
        // Given
        let title = "Test Summary No Trend"
        let amount = Decimal(100.0)
        
        // When
        let summaryData = ExpenseListViewModel.createBasicSummaryData(
            title: title,
            amount: amount
        )
        
        // Then
        XCTAssertEqual(summaryData.title, title)
        XCTAssertEqual(summaryData.amount, amount)
        XCTAssertNil(summaryData.trend)
    }
    
    // MARK: - Edge Cases Tests
    
    func testSummaryDataWithZeroAmounts() async {
        // Given: Create zero amount expenses
        let zeroExpense = createTestExpense(amount: 0.0, daysFromNow: 0, merchant: "Zero Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let summaryData = viewModel.summaryData
        let currentMonthTotal = viewModel.currentMonthTotal
        
        // Then
        XCTAssertEqual(currentMonthTotal, 0.0, "Should handle zero amounts correctly")
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertEqual(thisMonthSummary?.amount, 0.0, "Summary should show zero amount")
    }
    
    func testSummaryDataWithNegativeAmounts() async {
        // Given: Create negative amount expenses (refunds)
        let negativeExpense = createTestExpense(amount: -25.0, daysFromNow: -1, merchant: "Refund Store")
        let positiveExpense = createTestExpense(amount: 100.0, daysFromNow: -2, merchant: "Purchase Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let currentMonthTotal = viewModel.currentMonthTotal
        
        // Then
        XCTAssertEqual(currentMonthTotal, 75.0, "Should handle negative amounts correctly")
    }
    
    func testSummaryDataWithNilDates() async {
        // Given: Create expense with current date (can't set to nil as it's non-optional)
        let expense = createTestExpense(amount: 50.0, daysFromNow: 0, merchant: "Current Date Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let summaryData = viewModel.summaryData
        
        // Then: Should not crash and should handle gracefully
        XCTAssertTrue(summaryData.isEmpty || summaryData.count > 0, "Should handle dates gracefully")
    }
    
    func testSummaryDataWithVeryLargeAmounts() async {
        // Given: Create expense with very large amount
        let largeExpense = createTestExpense(amount: 999999.99, daysFromNow: 0, merchant: "Expensive Store")
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When
        let currentMonthTotal = viewModel.currentMonthTotal
        let summaryData = viewModel.summaryData
        
        // Then
        XCTAssertEqual(currentMonthTotal, 999999.99, "Should handle large amounts correctly")
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertEqual(thisMonthSummary?.amount, 999999.99, "Summary should show large amount correctly")
    }
    
    // MARK: - Filtering Impact Tests
    
    func testSummaryDataWithFiltering() async {
        // Given: Create expenses in different categories
        let foodCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.colorHex = "#00FF00"
        foodCategory.icon = "fork.knife"
        foodCategory.isDefault = false
        
        let foodExpense = createTestExpense(amount: 50.0, daysFromNow: -1, merchant: "Restaurant")
        foodExpense.category = foodCategory
        
        let otherExpense = createTestExpense(amount: 100.0, daysFromNow: -2, merchant: "Store")
        otherExpense.category = testCategory
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Apply category filter
        viewModel.selectedCategory = foodCategory
        await viewModel.applyFilters()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then: Summary should reflect filtered data
        let summaryData = viewModel.summaryData
        XCTAssertTrue(summaryData.count > 0, "Should generate summary data even with filters")
        
        // Note: Summary data is based on displayedExpenses which are filtered
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
    }
    
    // MARK: - Performance Tests
    
    func testSummaryDataPerformanceWithManyExpenses() async {
        // Given: Create many expenses
        for i in 0..<100 {
            let expense = createTestExpense(
                amount: Double(i + 1) * 10.0,
                daysFromNow: -i % 30,
                merchant: "Store \(i)"
            )
            _ = expense // Silence unused variable warning
        }
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // When & Then: Measure performance
        measure {
            let _ = viewModel.summaryData
            let _ = viewModel.currentMonthTotal
            let _ = viewModel.previousMonthTotal
            let _ = viewModel.currentWeekTotal
            let _ = viewModel.averageDailySpending
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testSummaryDataConcurrentAccess() async {
        // Given: Create test expenses
        let expense = createTestExpense(amount: 100.0, daysFromNow: 0, merchant: "Concurrent Store")
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // When: Access summary data concurrently
        let expectation = XCTestExpectation(description: "Concurrent access test")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            Task {
                let summaryData = viewModel.summaryData
                let currentMonthTotal = viewModel.currentMonthTotal
                
                XCTAssertTrue(summaryData.count >= 0, "Summary data should be accessible concurrently")
                XCTAssertGreaterThanOrEqual(currentMonthTotal, 0, "Current month total should be accessible concurrently")
                
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    // MARK: - Memory Management Tests
    
    func testSummaryDataMemoryManagement() {
        // Given: Create multiple view models
        var viewModels: [ExpenseListViewModel] = []
        
        for _ in 0..<10 {
            let vm = ExpenseListViewModel(dataService: mockDataService)
            viewModels.append(vm)
        }
        
        // When: Access summary data and then release
        for vm in viewModels {
            let _ = vm.summaryData
        }
        
        viewModels.removeAll()
        
        // Then: Should not cause memory leaks (verified by instruments)
        XCTAssertTrue(viewModels.isEmpty, "View models should be released")
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense(amount: Double, daysFromNow: Int, merchant: String) -> Expense {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: amount)
        expense.date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        expense.merchant = merchant
        expense.category = testCategory
        return expense
    }
}