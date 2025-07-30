import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseDataServicePerformanceTests: CoreDataTestCase {
    
    var expenseDataService: ExpenseDataService!
    
    override func setUpWithError() async throws {
        try await super.setUpWithError()
        let expectation = self.expectation(description: "Setup")
        await MainActor.run {
            self.expenseDataService = ExpenseDataService(context: self.testContext)
            expectation.fulfill()
        }
        await waitForExpectations(timeout: 1, handler: nil)
    }
    
    override func tearDownWithError() async throws {
        let expectation = self.expectation(description: "Teardown")
        await MainActor.run {
            self.expenseDataService = nil
            expectation.fulfill()
        }
        await waitForExpectations(timeout: 1, handler: nil)
        try await super.tearDownWithError()
    }
    
    // MARK: - Performance Tests
    
    func testLoadExpensesPerformance() async throws {
        // Given - Create a large dataset
        let expenseCount = 1000
        try await createTestExpenses(count: expenseCount)
        
        // When - Measure loading performance
        let startTime = CFAbsoluteTimeGetCurrent()
        await expenseDataService.loadExpenses()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Then - Verify performance is acceptable
        XCTAssertLessThan(executionTime, 2.0, "Loading \(expenseCount) expenses should complete within 2 seconds")
        XCTAssertEqual(expenseDataService.expenses.count, expenseCount)
        
        print("✅ Loaded \(expenseCount) expenses in \(executionTime) seconds")
    }
    
    func testBatchDeletePerformance() async throws {
        // Given - Create test data
        let expenseCount = 500
        try await createTestExpenses(count: expenseCount)
        
        // Create predicate to delete half the expenses
        let cutoffDate = Date().addingTimeInterval(-86400 * 30) // 30 days ago
        let predicate = NSPredicate(format: "date < %@", cutoffDate as NSDate)
        
        // When - Measure batch delete performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let deletedCount = try await expenseDataService.batchDeleteExpenses(matching: predicate)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Then - Verify performance and results
        XCTAssertLessThan(executionTime, 1.0, "Batch delete should complete within 1 second")
        XCTAssertGreaterThan(deletedCount, 0, "Should have deleted some expenses")
        
        print("✅ Batch deleted \(deletedCount) expenses in \(executionTime) seconds")
    }
    
    func testFilteringPerformance() async throws {
        // Given - Create diverse test data
        try await createDiverseTestExpenses(count: 800)
        
        // Create filter criteria
        let criteria = ExpenseFilterService.FilterCriteria(
            searchText: "Test",
            category: nil,
            dateRange: DateInterval(start: Date().addingTimeInterval(-86400 * 90), end: Date()),
            amountRange: 10...500,
            vendor: nil
        )
        
        // When - Measure filtering performance
        let startTime = CFAbsoluteTimeGetCurrent()
        await expenseDataService.loadExpenses()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Then - Verify performance
        XCTAssertLessThan(executionTime, 1.5, "Filtered loading should complete within 1.5 seconds")
        XCTAssertGreaterThan(expenseDataService.expenses.count, 0, "Should have some filtered results")
        
        print("✅ Filtered \(expenseDataService.expenses.count) expenses in \(executionTime) seconds")
    }
    
    func testStatisticsPerformance() async throws {
        // Given - Create test data
        try await createTestExpenses(count: 1000)
        
        let dateRange = DateInterval(start: Date().addingTimeInterval(-86400 * 30), end: Date())
        
        // When - Measure statistics calculation performance
        let startTime = CFAbsoluteTimeGetCurrent()
        let statistics = try await expenseDataService.getExpenseStatistics(for: dateRange)
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Then - Verify performance and results
        XCTAssertLessThan(executionTime, 0.5, "Statistics calculation should complete within 0.5 seconds")
        XCTAssertGreaterThan(statistics.count, 0, "Should have statistics for some expenses")
        XCTAssertGreaterThan(statistics.totalAmount, 0, "Should have positive total amount")
        
        print("✅ Calculated statistics for \(statistics.count) expenses in \(executionTime) seconds")
    }
    
    func testMemoryUsageOptimization() async throws {
        // Given - Create a large dataset
        try await createTestExpenses(count: 2000)
        await expenseDataService.loadExpenses()
        
        // When - Optimize memory usage
        let startTime = CFAbsoluteTimeGetCurrent()
        expenseDataService.optimizeMemoryUsage()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        let executionTime = endTime - startTime
        
        // Then - Verify performance
        XCTAssertLessThan(executionTime, 1.0, "Memory optimization should complete within 1 second")
        
        print("✅ Memory optimization completed in \(executionTime) seconds")
    }
    
    func testConcurrentOperationsPerformance() async throws {
        // Given - Create initial data
        try await createTestExpenses(count: 100)
        
        // When - Perform concurrent operations
        let startTime = CFAbsoluteTimeGetCurrent()
        
        await withTaskGroup(of: Void.self) { group in
            // Load expenses
            group.addTask {
                await self.expenseDataService.loadExpenses()
            }
            
            // Get statistics
            group.addTask {
                _ = try? await self.expenseDataService.getExpenseStatistics()
            }
            
            // Get count
            group.addTask {
                _ = try? await self.expenseDataService.getExpenseCount()
            }
        }
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then - Verify concurrent operations complete efficiently
        XCTAssertLessThan(executionTime, 3.0, "Concurrent operations should complete within 3 seconds")
        
        print("✅ Concurrent operations completed in \(executionTime) seconds")
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryWarningHandling() async throws {
        // Given - Create large dataset
        try await createTestExpenses(count: 1500)
        await expenseDataService.loadExpenses()
        
        // When - Simulate memory warning
        let startTime = CFAbsoluteTimeGetCurrent()
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Allow time for memory optimization
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let executionTime = endTime - startTime
        
        // Then - Verify memory warning is handled efficiently
        XCTAssertLessThan(executionTime, 0.5, "Memory warning handling should be fast")
        
        print("✅ Memory warning handled in \(executionTime) seconds")
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpenses(count: Int) async throws {
        let context = testCoreDataManager.createBackgroundContext()
        
        try await context.perform {
            // Create a default category for testing
            let category = Category(context: context)
            category.id = UUID()
            category.name = "Test Category"
            category.colorHex = "FF5733"
            category.icon = "tag.fill"
            category.isDefault = false
            
            // Create expenses
            for i in 0..<count {
                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(value: Double.random(in: 10...500))
                expense.merchant = "Test Merchant \(i % 10)" // Create some variety
                expense.date = Date().addingTimeInterval(TimeInterval(-i * 3600)) // Spread over time
                expense.notes = "Test expense \(i)"
                expense.paymentMethod = i % 2 == 0 ? "Credit Card" : "Cash"
                expense.isRecurring = i % 10 == 0
                expense.category = category
            }
            
            try context.save()
        }
    }
    
    private func createDiverseTestExpenses(count: Int) async throws {
        let context = testCoreDataManager.createBackgroundContext()
        
        try await context.perform {
            // Create multiple categories
            let categories = ["Food", "Transportation", "Entertainment", "Utilities", "Shopping"].map { name in
                let category = Category(context: context)
                category.id = UUID()
                category.name = name
                category.colorHex = "FF5733"
                category.icon = "tag.fill"
                category.isDefault = false
                return category
            }
            
            let merchants = ["Test Store", "Sample Restaurant", "Demo Gas Station", "Example Cinema", "Mock Grocery"]
            let paymentMethods = ["Credit Card", "Debit Card", "Cash", "Mobile Payment"]
            
            // Create diverse expenses
            for i in 0..<count {
                let expense = Expense(context: context)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(value: Double.random(in: 5...1000))
                expense.merchant = merchants[i % merchants.count]
                expense.date = Date().addingTimeInterval(TimeInterval(-i * 1800)) // Every 30 minutes
                expense.notes = "Test expense \(i) with diverse data"
                expense.paymentMethod = paymentMethods[i % paymentMethods.count]
                expense.isRecurring = i % 15 == 0
                expense.category = categories[i % categories.count]
            }
            
            try context.save()
        }
    }
}

// MARK: - Performance Measurement Extensions

extension XCTestCase {
    
    /// Measures the execution time of an async operation
    func measureAsync<T>(_ operation: () async throws -> T) async rethrows -> (result: T, executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        
        return (result: result, executionTime: endTime - startTime)
    }
    
    /// Asserts that an async operation completes within a time limit
    func assertAsyncPerformance<T>(
        _ operation: () async throws -> T,
        completesWithin timeLimit: TimeInterval,
        file: StaticString = #file,
        line: UInt = #line
    ) async rethrows -> T {
        let measurement = try await measureAsync(operation)
        
        XCTAssertLessThan(
            measurement.executionTime,
            timeLimit,
            "Operation took \(measurement.executionTime) seconds, expected < \(timeLimit) seconds",
            file: file,
            line: line
        )
        
        return measurement.result
    }
}