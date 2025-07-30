import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseReportingServiceBasicTests: XCTestCase {
    
    var reportingService: ExpenseReportingService!
    var coreDataManager: CoreDataManager!
    var context: NSManagedObjectContext!
    
    @MainActor
    override func setUp() {
        super.setUp()
        
        // Create in-memory Core Data stack for testing
        coreDataManager = CoreDataManager.createForTesting()
        context = coreDataManager.viewContext
        reportingService = ExpenseReportingService(context: context)
    }
    
    override func tearDown() {
        reportingService = nil
        coreDataManager = nil
        context = nil
        super.tearDown()
    }
    
    // MARK: - Basic Tests
    
    func testReportingServiceInitialization() {
        XCTAssertNotNil(reportingService)
        XCTAssertNotNil(context)
    }
    
    func testTimePeriodDateIntervals() {
        let now = Date()
        let calendar = Calendar.current
        
        // Test week interval
        let weekInterval = TimePeriod.week.dateInterval(for: now)
        let expectedWeekInterval = calendar.dateInterval(of: .weekOfYear, for: now)!
        XCTAssertEqual(weekInterval.start, expectedWeekInterval.start)
        XCTAssertEqual(weekInterval.end, expectedWeekInterval.end)
        
        // Test month interval
        let monthInterval = TimePeriod.month.dateInterval(for: now)
        let expectedMonthInterval = calendar.dateInterval(of: .month, for: now)!
        XCTAssertEqual(monthInterval.start, expectedMonthInterval.start)
        XCTAssertEqual(monthInterval.end, expectedMonthInterval.end)
    }
    
    func testEmptyDataHandling() {
        let expectation = XCTestExpectation(description: "Handle empty data")
        
        Task { @MainActor in
            do {
                let summary = try await self.reportingService.getSpendingSummary(for: .month)
                
                XCTAssertEqual(summary.totalAmount, 0)
                XCTAssertEqual(summary.transactionCount, 0)
                XCTAssertEqual(summary.averageTransaction, 0)
                XCTAssertTrue(summary.categoryBreakdown.isEmpty)
                XCTAssertTrue(summary.vendorBreakdown.isEmpty)
                
                expectation.fulfill()
            } catch {
                XCTFail("Should not throw error for empty data: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testSpendingSummaryWithSampleData() {
        let expectation = XCTestExpectation(description: "Generate spending summary with sample data")
        
        Task { @MainActor in
            do {
                // Create a sample category
                let category = Category(context: self.context)
                category.id = UUID()
                category.name = "Food"
                category.colorHex = "FF0000"
                category.icon = "fork.knife"
                category.isDefault = true
                
                // Create a sample expense
                let expense = Expense(context: self.context)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(string: "25.50")
                expense.date = Date()
                expense.merchant = "Test Restaurant"
                expense.category = category
                
                try self.context.save()
                
                let summary = try await self.reportingService.getSpendingSummary(for: .month)
                
                XCTAssertEqual(summary.totalAmount, Decimal(string: "25.50"))
                XCTAssertEqual(summary.transactionCount, 1)
                XCTAssertEqual(summary.averageTransaction, Decimal(string: "25.50"))
                XCTAssertEqual(summary.categoryBreakdown.count, 1)
                XCTAssertEqual(summary.vendorBreakdown.count, 1)
                
                expectation.fulfill()
            } catch {
                XCTFail("Should not throw error with sample data: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testCategorySpendingAnalysis() {
        let expectation = XCTestExpectation(description: "Generate category spending analysis")
        
        Task { @MainActor in
            do {
                let categoryAnalysis = try await self.reportingService.getCategorySpendingAnalysis(for: .month)
                
                // Should work even with empty data
                XCTAssertNotNil(categoryAnalysis)
                XCTAssertTrue(categoryAnalysis.isEmpty) // No data yet
                
                expectation.fulfill()
            } catch {
                XCTFail("Should not throw error for category analysis: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testVendorSpendingAnalysis() {
        let expectation = XCTestExpectation(description: "Generate vendor spending analysis")
        
        Task { @MainActor in
            do {
                let vendorAnalysis = try await self.reportingService.getVendorSpendingAnalysis(for: .month)
                
                // Should work even with empty data
                XCTAssertNotNil(vendorAnalysis)
                XCTAssertTrue(vendorAnalysis.isEmpty) // No data yet
                
                expectation.fulfill()
            } catch {
                XCTFail("Should not throw error for vendor analysis: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPeriodComparison() {
        let expectation = XCTestExpectation(description: "Compare periods")
        
        Task { @MainActor in
            do {
                let comparison = try await self.reportingService.comparePeriods(period: .month)
                
                // Should work even with empty data
                XCTAssertNotNil(comparison)
                XCTAssertEqual(comparison.currentPeriod.totalAmount, 0)
                XCTAssertEqual(comparison.previousPeriod.totalAmount, 0)
                XCTAssertEqual(comparison.changeAmount, 0)
                
                expectation.fulfill()
            } catch {
                XCTFail("Should not throw error for period comparison: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}