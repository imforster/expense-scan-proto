import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseReportingServiceTests: XCTestCase {
    
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
    
}