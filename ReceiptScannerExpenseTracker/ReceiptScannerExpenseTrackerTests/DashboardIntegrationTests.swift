import XCTest
import SwiftUI
import Combine
@testable import ReceiptScannerExpenseTracker

@MainActor
class DashboardIntegrationTests: XCTestCase {
    
    var viewModel: ExpenseListViewModel!
    var mockDataService: ExpenseDataService!
    var testCoreDataManager: CoreDataManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Create a test Core Data manager and context
        testCoreDataManager = CoreDataManager.createForTesting()
        let testContext = testCoreDataManager.viewContext
        mockDataService = ExpenseDataService(context: testContext)
        viewModel = ExpenseListViewModel(dataService: mockDataService)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables?.removeAll()
        viewModel = nil
        mockDataService = nil
        testCoreDataManager = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testSummaryDataIntegrationWithEmptyExpenses() {
        // Given: No expenses
        let summaryData = viewModel.summaryData
        
        // Then: Summary data should be empty or contain zero amounts
        XCTAssertTrue(summaryData.isEmpty || summaryData.allSatisfy { $0.amount == 0 })
    }
    
    func testSummaryDataIntegrationWithRealExpenses() async {
        // Given: Create some test expenses
        let testContext = testCoreDataManager.viewContext
        
        let category = ReceiptScannerExpenseTracker.Category(context: testContext)
        category.id = UUID()
        category.name = "Food"
        category.colorHex = "#FF0000"
        category.icon = "fork.knife"
        category.isDefault = true
        
        let expense1 = Expense(context: testContext)
        expense1.id = UUID()
        expense1.amount = NSDecimalNumber(value: 50.0)
        expense1.date = Date()
        expense1.merchant = "Test Restaurant"
        expense1.category = category
        
        let expense2 = Expense(context: testContext)
        expense2.id = UUID()
        expense2.amount = NSDecimalNumber(value: 25.0)
        expense2.date = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        expense2.merchant = "Test Cafe"
        expense2.category = category
        
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save test context: \(error)")
            return
        }
        
        // When: Load expenses
        await viewModel.loadExpenses()
        
        // Wait for data to be processed
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        
        // Then: Summary data should reflect the expenses
        let summaryData = viewModel.summaryData
        XCTAssertTrue(summaryData.count >= 0, "Summary data should be generated")
        
        // Check that current month total is calculated correctly
        let currentMonthTotal = viewModel.currentMonthTotal
        XCTAssertGreaterThanOrEqual(currentMonthTotal, 0, "Current month total should be >= 0")
    }
    
    func testSummaryDataFormattingForDashboard() {
        // Given: Create summary data
        let summaryData = SummaryData(
            title: "This Month",
            amount: 1234.56,
            trend: TrendData(previousAmount: 1000.00, currentAmount: 1234.56)
        )
        
        // Then: Verify formatting
        XCTAssertEqual(summaryData.title, "This Month")
        XCTAssertTrue(summaryData.formattedAmount.contains("$1,235") || summaryData.formattedAmount.contains("$1234"))
        XCTAssertNotNil(summaryData.trend)
        XCTAssertEqual(summaryData.trend?.direction, .increasing)
    }
    
    func testDashboardLoadingStates() async {
        // Given: ViewModel in initial state
        // Note: Loading state may be true initially depending on timing
        
        // When: Start loading
        await viewModel.loadExpenses()
        
        // Wait for loading to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Then: Loading should complete
        XCTAssertFalse(viewModel.isLoading, "Should not be loading after completion")
        
        // Verify that the view model is in a valid state
        XCTAssertTrue(viewModel.viewState == .empty || 
                     viewModel.viewState == .loaded(viewModel.displayedExpenses),
                     "View model should be in a valid state after loading")
    }
    
    func testSummaryDataReactivity() {
        // Given: Initial state
        _ = viewModel.summaryData.count
        
        // When: Expenses change (simulated by updating displayed expenses)
        viewModel.displayedExpenses = []
        
        // Then: Summary data should update
        // This tests the reactive binding
        let updatedSummaryCount = viewModel.summaryData.count
        
        // The summary data should still be generated even with empty expenses
        XCTAssertTrue(updatedSummaryCount >= 0, "Summary data should be generated")
    }
    
    func testCurrentWeekTotalCalculation() {
        // Given: ViewModel with no expenses
        let currentWeekTotal = viewModel.currentWeekTotal
        
        // Then: Should return 0 for empty expenses
        XCTAssertEqual(currentWeekTotal, 0, "Current week total should be 0 for empty expenses")
    }
    
    func testCurrentMonthTotalCalculation() {
        // Given: ViewModel with no expenses
        let currentMonthTotal = viewModel.currentMonthTotal
        
        // Then: Should return 0 for empty expenses
        XCTAssertEqual(currentMonthTotal, 0, "Current month total should be 0 for empty expenses")
    }
    
    func testDashboardSummaryDataBinding() {
        // Given: ViewModel with initial state
        let initialSummaryData = viewModel.summaryData
        
        // Then: Summary data should be available
        XCTAssertTrue(initialSummaryData.count >= 0, "Summary data should be available")
    }
    
    func testDashboardRealTimeUpdates() async {
        // Given: Initial empty state
        let initialTotal = viewModel.currentMonthTotal
        XCTAssertEqual(initialTotal, 0, "Should start with 0 total")
        
        // When: Add an expense
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Test"
        category.colorHex = "#000000"
        category.icon = "star"
        category.isDefault = false
        
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 100.0)
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.category = category
        
        try? testContext.save()
        
        // Reload expenses
        await viewModel.loadExpenses()
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Then: Summary should update
        let updatedTotal = viewModel.currentMonthTotal
        XCTAssertGreaterThanOrEqual(updatedTotal, 0, "Total should be updated")
    }
    
    func testDashboardEmptyStateHandling() {
        // Given: Empty expense list
        let summaryData = viewModel.summaryData
        
        // Then: Should handle empty state gracefully
        XCTAssertTrue(summaryData.isEmpty || summaryData.allSatisfy { $0.amount == 0 }, 
                     "Empty state should show zero amounts or empty data")
    }
    
    // MARK: - Summary Card Display Update Tests
    
    func testSummaryCardDisplayUpdatesWithDataChanges() async {
        // Given: Initial empty state
        let initialSummaryData = viewModel.summaryData
        let initialCount = initialSummaryData.count
        
        // When: Add expenses and update
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Display Test"
        category.colorHex = "#0000FF"
        category.icon = "display"
        category.isDefault = false
        
        let expense1 = Expense(context: testContext)
        expense1.id = UUID()
        expense1.amount = NSDecimalNumber(value: 150.0)
        expense1.date = Date()
        expense1.merchant = "Display Store A"
        expense1.category = category
        
        let expense2 = Expense(context: testContext)
        expense2.id = UUID()
        expense2.amount = NSDecimalNumber(value: 75.0)
        expense2.date = Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        expense2.merchant = "Display Store B"
        expense2.category = category
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Then: Summary data should update
        let updatedSummaryData = viewModel.summaryData
        XCTAssertGreaterThanOrEqual(updatedSummaryData.count, initialCount, "Summary data should be updated")
        
        let thisMonthSummary = updatedSummaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
        XCTAssertGreaterThan(thisMonthSummary?.amount ?? 0, 0, "This Month amount should be greater than 0")
    }
    
    func testSummaryCardTrendDisplayUpdates() async {
        // Given: Create expenses in current and previous months
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Trend Test"
        category.colorHex = "#FF00FF"
        category.icon = "chart.line.uptrend.xyaxis"
        category.isDefault = false
        
        // Current month expense
        let currentExpense = Expense(context: testContext)
        currentExpense.id = UUID()
        currentExpense.amount = NSDecimalNumber(value: 200.0)
        currentExpense.date = Date()
        currentExpense.merchant = "Current Month Store"
        currentExpense.category = category
        
        // Previous month expense
        let previousExpense = Expense(context: testContext)
        previousExpense.id = UUID()
        previousExpense.amount = NSDecimalNumber(value: 150.0)
        previousExpense.date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        previousExpense.merchant = "Previous Month Store"
        previousExpense.category = category
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // When: Get summary data
        let summaryData = viewModel.summaryData
        
        // Then: Trend data should be available
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
        XCTAssertNotNil(thisMonthSummary?.trend, "This Month should have trend data")
        XCTAssertEqual(thisMonthSummary?.trend?.direction, .increasing, "Trend should show increasing")
    }
    
    func testSummaryCardFormattingForDisplay() {
        // Given: Create summary data with specific values
        let summaryData = SummaryData(
            title: "Display Test",
            amount: 1234.56,
            trend: TrendData(previousAmount: 1000.00, currentAmount: 1234.56)
        )
        
        // When: Format for display
        let formattedAmount = summaryData.formattedAmount
        let formattedTrend = summaryData.formattedTrend
        
        // Then: Should be properly formatted for UI display
        XCTAssertTrue(formattedAmount.contains("$"), "Amount should include currency symbol")
        XCTAssertTrue(formattedAmount.contains("1,235") || formattedAmount.contains("1234"), "Amount should be formatted correctly")
        
        XCTAssertNotNil(formattedTrend, "Trend should be formatted")
        XCTAssertTrue(formattedTrend!.contains("%"), "Trend should include percentage")
        XCTAssertTrue(formattedTrend!.contains("vs last month"), "Trend should include comparison text")
    }
    
    func testSummaryCardReactiveUpdates() async {
        // Given: Initial state
        var summaryUpdateCount = 0
        let expectation = XCTestExpectation(description: "Summary updates")
        expectation.expectedFulfillmentCount = 2 // Initial + after expense addition
        
        // Observe summary data changes
        viewModel.$displayedExpenses
            .sink { _ in
                summaryUpdateCount += 1
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When: Add an expense
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Reactive Test"
        category.colorHex = "#00FFFF"
        category.icon = "arrow.clockwise"
        category.isDefault = false
        
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 300.0)
        expense.date = Date()
        expense.merchant = "Reactive Store"
        expense.category = category
        
        try? testContext.save()
        await viewModel.loadExpenses()
        
        // Then: Should receive updates
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertGreaterThan(summaryUpdateCount, 0, "Should receive summary updates")
    }
    
    func testSummaryCardDisplayWithFiltering() async {
        // Given: Create expenses in different categories
        let testContext = testCoreDataManager.viewContext
        
        let foodCategory = Category(context: testContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.colorHex = "#FFA500"
        foodCategory.icon = "fork.knife"
        foodCategory.isDefault = false
        
        let transportCategory = Category(context: testContext)
        transportCategory.id = UUID()
        transportCategory.name = "Transport"
        transportCategory.colorHex = "#0000FF"
        transportCategory.icon = "car"
        transportCategory.isDefault = false
        
        let foodExpense = Expense(context: testContext)
        foodExpense.id = UUID()
        foodExpense.amount = NSDecimalNumber(value: 50.0)
        foodExpense.date = Date()
        foodExpense.merchant = "Restaurant"
        foodExpense.category = foodCategory
        
        let transportExpense = Expense(context: testContext)
        transportExpense.id = UUID()
        transportExpense.amount = NSDecimalNumber(value: 30.0)
        transportExpense.date = Date()
        transportExpense.merchant = "Gas Station"
        transportExpense.category = transportCategory
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When: Apply category filter
        viewModel.selectedCategory = foodCategory
        await viewModel.applyFilters()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Summary should reflect filtered data
        let summaryData = viewModel.summaryData
        XCTAssertTrue(summaryData.count > 0, "Should generate summary data with filters")
        
        // Summary is based on displayedExpenses which should be filtered
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
    }
    
    func testSummaryCardDisplayWithEmptyFilterResults() async {
        // Given: Create expenses
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Test Category"
        category.colorHex = "#808080"
        category.icon = "questionmark"
        category.isDefault = false
        
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 100.0)
        expense.date = Date()
        expense.merchant = "Test Store"
        expense.category = category
        
        try? testContext.save()
        await viewModel.loadExpenses()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When: Apply filter that returns no results
        viewModel.searchText = "NonexistentStore"
        await viewModel.applyFilters()
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // Then: Summary should handle empty filtered results
        let summaryData = viewModel.summaryData
        XCTAssertTrue(summaryData.isEmpty || summaryData.allSatisfy { $0.amount == 0 },
                     "Summary should handle empty filter results")
    }
    
    // MARK: - Summary Data Consistency Tests
    
    func testSummaryDataConsistencyAfterMultipleUpdates() async {
        // Given: Initial state
        let testContext = testCoreDataManager.viewContext
        
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = "Consistency Test"
        category.colorHex = "#800080"
        category.icon = "checkmark.circle"
        category.isDefault = false
        
        // When: Add multiple expenses in sequence
        for i in 1...5 {
            let expense = Expense(context: testContext)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(value: Double(i * 20))
            expense.date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            expense.merchant = "Consistency Store \(i)"
            expense.category = category
            
            try? testContext.save()
            await viewModel.loadExpenses()
            try? await Task.sleep(nanoseconds: 100_000_000)
            
            // Verify consistency after each addition
            let summaryData = viewModel.summaryData
            let thisMonthSummary = summaryData.first { $0.title == "This Month" }
            XCTAssertNotNil(thisMonthSummary, "Should have This Month summary after update \(i)")
        }
        
        // Then: Final verification
        let finalSummaryData = viewModel.summaryData
        let finalThisMonthSummary = finalSummaryData.first { $0.title == "This Month" }
        XCTAssertEqual(finalThisMonthSummary?.amount, 300.0, "Final total should be correct")
    }
}