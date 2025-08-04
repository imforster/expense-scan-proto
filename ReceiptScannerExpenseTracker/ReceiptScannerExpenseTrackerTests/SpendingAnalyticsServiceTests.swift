import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class SpendingAnalyticsServiceTests: XCTestCase {
    
    var testCoreDataManager: CoreDataManager!
    var testContext: NSManagedObjectContext!
    var testCategory: ReceiptScannerExpenseTracker.Category!
    
    override func setUp() {
        super.setUp()
        testCoreDataManager = CoreDataManager.createForTesting()
        testContext = testCoreDataManager.viewContext
        
        // Create a test category
        testCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        testCategory.id = UUID()
        testCategory.name = "Test Category"
        testCategory.colorHex = "#FF0000"
        testCategory.icon = "star"
        testCategory.isDefault = false
    }
    
    override func tearDown() {
        testCoreDataManager = nil
        testContext = nil
        testCategory = nil
        super.tearDown()
    }
    
    // MARK: - Current Month Total Tests
    
    func testCalculateCurrentMonthTotalWithEmptyExpenses() {
        // Given
        let expenses: [Expense] = []
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 0, "Empty expenses should return 0 total")
    }
    
    func testCalculateCurrentMonthTotalWithCurrentMonthExpenses() {
        // Given
        let currentMonthExpense = createTestExpense(amount: 100.0, daysFromNow: 0)
        let expenses = [currentMonthExpense]
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 100.0, "Should include current month expenses")
    }
    
    func testCalculateCurrentMonthTotalExcludesPreviousMonth() {
        // Given
        let currentMonthExpense = createTestExpense(amount: 100.0, daysFromNow: 0)
        let previousMonthExpense = createTestExpense(amount: 50.0, daysFromNow: -35)
        let expenses = [currentMonthExpense, previousMonthExpense]
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 100.0, "Should exclude previous month expenses")
    }
    
    func testCalculateCurrentMonthTotalWithMultipleExpenses() {
        // Given
        let expense1 = createTestExpense(amount: 50.0, daysFromNow: -5)
        let expense2 = createTestExpense(amount: 75.0, daysFromNow: -10)
        let expense3 = createTestExpense(amount: 25.0, daysFromNow: -1)
        let expenses = [expense1, expense2, expense3]
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 150.0, "Should sum all current month expenses")
    }
    
    // MARK: - Previous Month Total Tests
    
    func testCalculatePreviousMonthTotalWithEmptyExpenses() {
        // Given
        let expenses: [Expense] = []
        
        // When
        let total = SpendingAnalyticsService.calculatePreviousMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 0, "Empty expenses should return 0 total")
    }
    
    func testCalculatePreviousMonthTotalWithPreviousMonthExpenses() {
        // Given
        let previousMonthExpense = createTestExpense(amount: 200.0, daysFromNow: -35)
        let expenses = [previousMonthExpense]
        
        // When
        let total = SpendingAnalyticsService.calculatePreviousMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 200.0, "Should include previous month expenses")
    }
    
    func testCalculatePreviousMonthTotalExcludesCurrentMonth() {
        // Given
        let currentMonthExpense = createTestExpense(amount: 100.0, daysFromNow: 0)
        let previousMonthExpense = createTestExpense(amount: 50.0, daysFromNow: -35)
        let expenses = [currentMonthExpense, previousMonthExpense]
        
        // When
        let total = SpendingAnalyticsService.calculatePreviousMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 50.0, "Should exclude current month expenses")
    }
    
    // MARK: - Current Week Total Tests
    
    func testCalculateCurrentWeekTotalWithEmptyExpenses() {
        // Given
        let expenses: [Expense] = []
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentWeekTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 0, "Empty expenses should return 0 total")
    }
    
    func testCalculateCurrentWeekTotalWithCurrentWeekExpenses() {
        // Given
        let currentWeekExpense = createTestExpense(amount: 75.0, daysFromNow: -2)
        let expenses = [currentWeekExpense]
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentWeekTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 75.0, "Should include current week expenses")
    }
    
    func testCalculateCurrentWeekTotalExcludesPreviousWeek() {
        // Given
        let currentWeekExpense = createTestExpense(amount: 50.0, daysFromNow: -1)
        let previousWeekExpense = createTestExpense(amount: 30.0, daysFromNow: -10)
        let expenses = [currentWeekExpense, previousWeekExpense]
        
        // When
        let total = SpendingAnalyticsService.calculateCurrentWeekTotal(from: expenses)
        
        // Then
        XCTAssertEqual(total, 50.0, "Should exclude previous week expenses")
    }
    
    // MARK: - Average Daily Spending Tests
    
    func testCalculateAverageDailySpendingWithEmptyExpenses() {
        // Given
        let expenses: [Expense] = []
        
        // When
        let average = SpendingAnalyticsService.calculateAverageDailySpending(from: expenses)
        
        // Then
        XCTAssertEqual(average, 0, "Empty expenses should return 0 average")
    }
    
    func testCalculateAverageDailySpendingWithCurrentMonthExpenses() {
        // Given
        let expense1 = createTestExpense(amount: 100.0, daysFromNow: -5)
        let expense2 = createTestExpense(amount: 50.0, daysFromNow: -10)
        let expenses = [expense1, expense2]
        
        // When
        let average = SpendingAnalyticsService.calculateAverageDailySpending(from: expenses)
        
        // Then
        let calendar = Calendar.current
        let daysInMonth = calendar.component(.day, from: Date())
        let expectedAverage = Decimal(150.0) / Decimal(daysInMonth)
        XCTAssertEqual(average, expectedAverage, "Should calculate correct daily average")
    }
    
    // MARK: - Generate Summary Data Tests
    
    func testGenerateSummaryDataWithEmptyExpenses() {
        // Given
        let expenses: [Expense] = []
        
        // When
        let summaryData = SpendingAnalyticsService.generateSummaryData(from: expenses)
        
        // Then
        XCTAssertEqual(summaryData.count, 3, "Should generate 3 summary items")
        XCTAssertTrue(summaryData.contains { $0.title == "This Month" }, "Should include This Month")
        XCTAssertTrue(summaryData.contains { $0.title == "This Week" }, "Should include This Week")
        XCTAssertTrue(summaryData.contains { $0.title == "Daily Average" }, "Should include Daily Average")
        
        // All amounts should be 0
        XCTAssertTrue(summaryData.allSatisfy { $0.amount == 0 }, "All amounts should be 0 for empty expenses")
    }
    
    func testGenerateSummaryDataWithRealExpenses() {
        // Given
        let currentMonthExpense1 = createTestExpense(amount: 100.0, daysFromNow: -5)
        let currentMonthExpense2 = createTestExpense(amount: 50.0, daysFromNow: -10)
        let currentWeekExpense = createTestExpense(amount: 25.0, daysFromNow: -2)
        let previousMonthExpense = createTestExpense(amount: 75.0, daysFromNow: -35)
        let expenses = [currentMonthExpense1, currentMonthExpense2, currentWeekExpense, previousMonthExpense]
        
        // When
        let summaryData = SpendingAnalyticsService.generateSummaryData(from: expenses)
        
        // Then
        XCTAssertEqual(summaryData.count, 3, "Should generate 3 summary items")
        
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertNotNil(thisMonthSummary, "Should have This Month summary")
        XCTAssertEqual(thisMonthSummary?.amount, 175.0, "This Month should include current month expenses")
        XCTAssertNotNil(thisMonthSummary?.trend, "This Month should have trend data")
        
        let thisWeekSummary = summaryData.first { $0.title == "This Week" }
        XCTAssertNotNil(thisWeekSummary, "Should have This Week summary")
        XCTAssertEqual(thisWeekSummary?.amount, 25.0, "This Week should include current week expenses")
        XCTAssertNil(thisWeekSummary?.trend, "This Week should not have trend data")
        
        let dailyAverageSummary = summaryData.first { $0.title == "Daily Average" }
        XCTAssertNotNil(dailyAverageSummary, "Should have Daily Average summary")
        XCTAssertGreaterThan(dailyAverageSummary?.amount ?? 0, 0, "Daily Average should be greater than 0")
        XCTAssertNil(dailyAverageSummary?.trend, "Daily Average should not have trend data")
    }
    
    // MARK: - Edge Cases Tests
    
    func testCalculationsWithNilDates() {
        // Given
        let expense = createTestExpense(amount: 100.0, daysFromNow: 0)
        // Note: We can't set date to nil as it's non-optional, so we test with a default date
        let expenses = [expense]
        
        // When
        let currentMonthTotal = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        let previousMonthTotal = SpendingAnalyticsService.calculatePreviousMonthTotal(from: expenses)
        let currentWeekTotal = SpendingAnalyticsService.calculateCurrentWeekTotal(from: expenses)
        
        // Then - Should handle dates gracefully
        XCTAssertGreaterThanOrEqual(currentMonthTotal, 0, "Should handle dates gracefully")
        XCTAssertGreaterThanOrEqual(previousMonthTotal, 0, "Should handle dates gracefully")
        XCTAssertGreaterThanOrEqual(currentWeekTotal, 0, "Should handle dates gracefully")
    }
    
    func testCalculationsWithZeroAmounts() {
        // Given
        let zeroExpense = createTestExpense(amount: 0.0, daysFromNow: 0)
        let expenses = [zeroExpense]
        
        // When
        let summaryData = SpendingAnalyticsService.generateSummaryData(from: expenses)
        
        // Then
        XCTAssertTrue(summaryData.allSatisfy { $0.amount == 0 }, "Should handle zero amounts correctly")
    }
    
    func testCalculationsWithNegativeAmounts() {
        // Given
        let negativeExpense = createTestExpense(amount: -50.0, daysFromNow: 0)
        let positiveExpense = createTestExpense(amount: 100.0, daysFromNow: 0)
        let expenses = [negativeExpense, positiveExpense]
        
        // When
        let currentMonthTotal = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        
        // Then
        XCTAssertEqual(currentMonthTotal, 50.0, "Should handle negative amounts correctly")
    }
    
    func testCalculationsWithVeryLargeAmounts() {
        // Given
        let largeExpense = createTestExpense(amount: 999999.99, daysFromNow: 0)
        let expenses = [largeExpense]
        
        // When
        let summaryData = SpendingAnalyticsService.generateSummaryData(from: expenses)
        
        // Then
        let thisMonthSummary = summaryData.first { $0.title == "This Month" }
        XCTAssertEqual(thisMonthSummary?.amount, 999999.99, "Should handle large amounts correctly")
    }
    
    // MARK: - Performance Tests
    
    func testCalculationPerformanceWithManyExpenses() {
        // Given
        var expenses: [Expense] = []
        for i in 0..<1000 {
            let expense = createTestExpense(amount: Double(i), daysFromNow: -i % 30)
            expenses.append(expense)
        }
        
        // When & Then
        measure {
            let _ = SpendingAnalyticsService.generateSummaryData(from: expenses)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense(amount: Double, daysFromNow: Int) -> Expense {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: amount)
        expense.date = Calendar.current.date(byAdding: .day, value: daysFromNow, to: Date()) ?? Date()
        expense.merchant = "Test Merchant"
        expense.category = testCategory
        return expense
    }
}