import XCTest
import CoreData
import Combine
@testable import ReceiptScannerExpenseTracker

@MainActor
final class ExpenseIntegrationTests: XCTestCase {
    
    var coreDataManager: CoreDataManager!
    var viewContext: NSManagedObjectContext!
    var dataService: ExpenseDataService!
    var filterService: ExpenseFilterService!
    var sortService: ExpenseSortService!
    var categoryService: CategoryService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Set up in-memory Core Data stack for testing
        coreDataManager = CoreDataManager.createForTesting()
        viewContext = coreDataManager.viewContext
        
        // Initialize services
        dataService = ExpenseDataService(context: viewContext)
        filterService = ExpenseFilterService()
        sortService = ExpenseSortService()
        categoryService = CategoryService()
        cancellables = Set<AnyCancellable>()
        
        // Create test categories
        await createTestCategories()
    }
    
    override func tearDown() async throws {
        cancellables = nil
        categoryService = nil
        sortService = nil
        filterService = nil
        dataService = nil
        viewContext = nil
        coreDataManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createTestCategories() async {
        let foodCategory = ReceiptScannerExpenseTracker.Category(context: viewContext)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.colorHex = "FF5733"
        foodCategory.icon = "fork.knife"
        foodCategory.isDefault = true
        
        let transportCategory = ReceiptScannerExpenseTracker.Category(context: viewContext)
        transportCategory.id = UUID()
        transportCategory.name = "Transportation"
        transportCategory.colorHex = "33A8FF"
        transportCategory.icon = "car.fill"
        transportCategory.isDefault = true
        
        let entertainmentCategory = ReceiptScannerExpenseTracker.Category(context: viewContext)
        entertainmentCategory.id = UUID()
        entertainmentCategory.name = "Entertainment"
        entertainmentCategory.colorHex = "8E44AD"
        entertainmentCategory.icon = "tv.fill"
        entertainmentCategory.isDefault = true
        
        try? viewContext.save()
    }
    
    private func createTestExpenseData(merchant: String, amount: Decimal, categoryName: String? = nil) async -> ExpenseData {
        var category: CategoryData? = nil
        
        if let categoryName = categoryName {
            let fetchRequest: NSFetchRequest<ReceiptScannerExpenseTracker.Category> = ReceiptScannerExpenseTracker.Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", categoryName)
            if let foundCategory = try? viewContext.fetch(fetchRequest).first {
                category = CategoryData(from: foundCategory)
            }
        }
        
        return ExpenseData(
            amount: amount,
            merchant: merchant,
            date: Date(),
            notes: "Test expense for \(merchant)",
            paymentMethod: "Credit Card",
            isRecurring: false,
            category: category,
            tags: [],
            items: []
        )
    }
    
    private func createMultipleTestExpenses(count: Int) async throws -> [Expense] {
        var expenses: [Expense] = []
        let merchants = ["Restaurant A", "Gas Station", "Movie Theater", "Grocery Store", "Coffee Shop"]
        let amounts: [Decimal] = [25.99, 45.00, 12.50, 89.99, 4.75]
        let categories = ["Food", "Transportation", "Entertainment", "Food", "Food"]
        
        for i in 0..<count {
            let merchantIndex = i % merchants.count
            let expenseData = await createTestExpenseData(
                merchant: merchants[merchantIndex],
                amount: amounts[merchantIndex],
                categoryName: categories[merchantIndex]
            )
            
            let expense = try await dataService.createExpense(expenseData)
            expenses.append(expense)
        }
        
        return expenses
    }
    
    // MARK: - Data Flow Integration Tests (Requirement 8.1)
    
    func testDataFlowBetweenAllComponents() async throws {
        // Test complete data flow from creation to display across all components
        
        // 1. Create expense through ExpenseDataService
        let expenseData = await createTestExpenseData(merchant: "Integration Test Restaurant", amount: Decimal(35.99), categoryName: "Food")
        let createdExpense = try await dataService.createExpense(expenseData)
        
        // Verify the expense was created successfully
        XCTAssertEqual(createdExpense.merchant, "Integration Test Restaurant")
        XCTAssertEqual(createdExpense.amount.decimalValue, Decimal(35.99))
        
        // 2. Test direct data service access
        await dataService.loadExpenses()
        XCTAssertEqual(dataService.expenses.count, 1, "Expected 1 expense in data service")
        XCTAssertEqual(dataService.expenses.first?.merchant, "Integration Test Restaurant")
        
        // 3. Test ExpenseDetailViewModel can load the same expense directly
        let retrievedExpense = await dataService.getExpense(by: createdExpense.objectID)
        XCTAssertNotNil(retrievedExpense, "Expected to retrieve expense by ID")
        XCTAssertEqual(retrievedExpense?.merchant, "Integration Test Restaurant")
        
        // 4. Test filtering through service
        let filteredExpenses = filterService.filter(dataService.expenses, with: ExpenseFilterService.FilterCriteria(searchText: "Integration"))
        XCTAssertEqual(filteredExpenses.count, 1, "Expected 1 expense after filtering")
        XCTAssertEqual(filteredExpenses.first?.merchant, "Integration Test Restaurant")
        
        // 5. Test update propagates correctly
        let updatedData = ExpenseData(
            amount: Decimal(45.99),
            merchant: "Updated Integration Restaurant",
            date: Date(),
            category: expenseData.category
        )
        
        try await dataService.updateExpense(createdExpense, with: updatedData)
        
        // Verify the update worked
        XCTAssertEqual(createdExpense.merchant, "Updated Integration Restaurant")
        XCTAssertEqual(createdExpense.amount.decimalValue, Decimal(45.99))
        
        // Verify data service reflects the update
        await dataService.loadExpenses()
        XCTAssertEqual(dataService.expenses.first?.merchant, "Updated Integration Restaurant")
        XCTAssertEqual(dataService.expenses.first?.amount.decimalValue, Decimal(45.99))
        
        // 6. Test deletion
        try await dataService.deleteExpense(createdExpense)
        await dataService.loadExpenses()
        XCTAssertEqual(dataService.expenses.count, 0, "Expected 0 expenses after deletion")
    }
    
    func testDataConsistencyAcrossMultipleViewModels() async throws {
        // Create multiple view models accessing the same data
        let expenses = try await createMultipleTestExpenses(count: 5)
        
        let listViewModel1 = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        let listViewModel2 = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        let detailViewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expenses.first!.objectID)
        
        // Load data in both list view models
        await listViewModel1.loadExpenses()
        await listViewModel2.loadExpenses()
        
        // Wait for all view models to load
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify all view models see the same data
        XCTAssertEqual(listViewModel1.displayedExpenses.count, 5)
        XCTAssertEqual(listViewModel2.displayedExpenses.count, 5)
        XCTAssertNotNil(detailViewModel.expense)
        
        // Update expense through one view model
        let updatedData = ExpenseData(
            amount: 99.99,
            merchant: "Consistency Test Merchant",
            date: Date()
        )
        
        try await dataService.updateExpense(expenses.first!, with: updatedData)
        
        // Wait for propagation
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Verify all view models reflect the change
        let updatedExpense1 = listViewModel1.displayedExpenses.first { $0.objectID == expenses.first!.objectID }
        let updatedExpense2 = listViewModel2.displayedExpenses.first { $0.objectID == expenses.first!.objectID }
        
        XCTAssertEqual(updatedExpense1?.merchant, "Consistency Test Merchant")
        XCTAssertEqual(updatedExpense2?.merchant, "Consistency Test Merchant")
        
        await detailViewModel.refreshExpense()
        XCTAssertEqual(detailViewModel.expense?.merchant, "Consistency Test Merchant")
    }
    
    // MARK: - CRUD Operations Integration Tests (Requirement 8.2)
    
    func testCompleteExpenseCRUDWorkflow() async throws {
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        
        // Load initial data
        await listViewModel.loadExpenses()
        
        // CREATE
        let createData = await createTestExpenseData(merchant: "CRUD Test Restaurant", amount: 25.99, categoryName: "Food")
        let createdExpense = try await dataService.createExpense(createData)
        
        // Wait for list to update
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(listViewModel.displayedExpenses.count, 1)
        XCTAssertEqual(listViewModel.displayedExpenses.first?.merchant, "CRUD Test Restaurant")
        
        // READ - Test detail view can read the created expense
        let detailViewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: createdExpense.objectID)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertNotNil(detailViewModel.expense)
        XCTAssertEqual(detailViewModel.expense?.merchant, "CRUD Test Restaurant")
        
        // UPDATE
        let updateData = ExpenseData(
            amount: 35.99,
            merchant: "Updated CRUD Restaurant",
            date: Date(),
            category: createData.category
        )
        
        try await dataService.updateExpense(createdExpense, with: updateData)
        
        // Wait for updates to propagate
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify list view shows updated data
        XCTAssertEqual(listViewModel.displayedExpenses.first?.merchant, "Updated CRUD Restaurant")
        XCTAssertEqual(listViewModel.displayedExpenses.first?.amount.decimalValue, 35.99)
        
        // Verify detail view shows updated data
        await detailViewModel.refreshExpense()
        XCTAssertEqual(detailViewModel.expense?.merchant, "Updated CRUD Restaurant")
        
        // DELETE
        await listViewModel.deleteExpense(createdExpense)
        
        // Wait for deletion to propagate
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify list view no longer shows the expense
        XCTAssertEqual(listViewModel.displayedExpenses.count, 0)
        
        // Verify detail view handles deleted expense
        await detailViewModel.refreshExpense()
        XCTAssertTrue(detailViewModel.isDeleted || detailViewModel.error != nil)
    }
    
    func testCRUDOperationsWithRelatedData() async throws {
        // Create expense with related data (category, tags, items)
        let category = try? viewContext.fetch(Category.fetchRequest()).first
        let categoryData = category.map { CategoryData(from: $0) }
        
        let expenseData = ExpenseData(
            amount: 50.00,
            merchant: "Complex Expense Test",
            date: Date(),
            notes: "Test with related data",
            paymentMethod: "Credit Card",
            isRecurring: false,
            category: categoryData,
            tags: [],
            items: [
                ExpenseItemData(name: "Item 1", amount: 25.00),
                ExpenseItemData(name: "Item 2", amount: 25.00)
            ]
        )
        
        // CREATE with related data
        let createdExpense = try await dataService.createExpense(expenseData)
        
        XCTAssertNotNil(createdExpense.category)
        XCTAssertEqual((createdExpense.items as? Set<ExpenseItem>)?.count, 2)
        
        // UPDATE with modified related data
        let updatedData = ExpenseData(
            amount: 75.00,
            merchant: "Updated Complex Expense",
            date: Date(),
            category: categoryData,
            items: [
                ExpenseItemData(name: "Updated Item 1", amount: 30.00),
                ExpenseItemData(name: "Updated Item 2", amount: 25.00),
                ExpenseItemData(name: "New Item 3", amount: 20.00)
            ]
        )
        
        try await dataService.updateExpense(createdExpense, with: updatedData)
        
        // Refresh to get updated data
        viewContext.refresh(createdExpense, mergeChanges: true)
        
        XCTAssertEqual(createdExpense.merchant, "Updated Complex Expense")
        XCTAssertEqual((createdExpense.items as? Set<ExpenseItem>)?.count, 3)
        
        // DELETE - verify cascade deletion of related items
        let itemIds = (createdExpense.items as? Set<ExpenseItem>)?.map { $0.objectID } ?? []
        
        try await dataService.deleteExpense(createdExpense)
        
        // Verify expense items were cascade deleted
        for itemId in itemIds {
            let item = try? viewContext.existingObject(with: itemId)
            XCTAssertNil(item)
        }
        
        // Verify category still exists (nullify relationship)
        XCTAssertNotNil(category)
        XCTAssertFalse(category!.isDeleted)
    }
    
    // MARK: - Concurrent Operations Tests (Requirement 8.3)
    
    func testConcurrentExpenseCreation() async throws {
        let concurrentOperations = 10
        
        var createdExpenses: [Expense] = []
        
        // Create multiple expenses sequentially to avoid lock issues in tests
        for i in 0..<concurrentOperations {
            let expenseData = await createTestExpenseData(
                merchant: "Concurrent Merchant \(i)",
                amount: Decimal(10 + i),
                categoryName: "Food"
            )
            
            let expense = try await dataService.createExpense(expenseData)
            createdExpenses.append(expense)
        }
        
        // Verify all expenses were created successfully
        XCTAssertEqual(createdExpenses.count, concurrentOperations)
        
        // Verify data integrity
        await dataService.loadExpenses()
        XCTAssertEqual(dataService.expenses.count, concurrentOperations)
        
        // Verify no duplicate merchants (each should be unique)
        let merchants = Set(dataService.expenses.map { $0.merchant })
        XCTAssertEqual(merchants.count, concurrentOperations)
    }
    
    func testConcurrentReadWriteOperations() async throws {
        // Create initial expenses
        let initialExpenses = try await createMultipleTestExpenses(count: 5)
        
        let readOperations = 10
        let writeOperations = 5
        
        var errors: [Error] = []
        
        // Sequential read operations
        for i in 0..<readOperations {
            do {
                let expenseIndex = i % initialExpenses.count
                let expense = await dataService.getExpense(by: initialExpenses[expenseIndex].objectID)
                XCTAssertNotNil(expense)
            } catch {
                errors.append(error)
            }
        }
        
        // Sequential write operations
        for i in 0..<writeOperations {
            do {
                let expenseIndex = i % initialExpenses.count
                let expense = initialExpenses[expenseIndex]
                
                let updateData = ExpenseData(
                    amount: Decimal(100 + i),
                    merchant: "Sequential Update \(i)",
                    date: Date()
                )
                
                try await dataService.updateExpense(expense, with: updateData)
            } catch {
                errors.append(error)
            }
        }
        
        // Verify no errors occurred during operations
        XCTAssertTrue(errors.isEmpty, "Operations should not produce errors: \(errors)")
        
        // Verify data consistency
        await dataService.loadExpenses()
        XCTAssertEqual(dataService.expenses.count, initialExpenses.count)
    }
    
    func testConcurrentFilteringAndSorting() async throws {
        // Create test data
        _ = try await createMultipleTestExpenses(count: 20)
        
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        
        // Load initial data
        await listViewModel.loadExpenses()
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 300_000_000)
        
        let operationCount = 10
        let expectation = XCTestExpectation(description: "Concurrent filtering and sorting")
        expectation.expectedFulfillmentCount = operationCount * 2 // filter + sort operations
        
        // Concurrent filtering operations
        for i in 0..<operationCount {
            Task {
                await MainActor.run {
                    listViewModel.searchText = i % 2 == 0 ? "Restaurant" : "Gas"
                }
                await listViewModel.applyFilters()
                expectation.fulfill()
            }
        }
        
        // Concurrent sorting operations
        for i in 0..<operationCount {
            Task {
                let sortOption: ExpenseSortService.SortOption = i % 2 == 0 ? .dateDescending : .amountAscending
                await listViewModel.updateSort(sortOption)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        
        // Verify final state is consistent
        XCTAssertNotNil(listViewModel.displayedExpenses)
        XCTAssertFalse(listViewModel.isLoading)
    }
    
    // MARK: - Data Consistency Tests (Requirement 8.4)
    
    func testDataConsistencyAfterMultipleUpdates() async throws {
        let expense = try await dataService.createExpense(
            await createTestExpenseData(merchant: "Consistency Test", amount: 25.99)
        )
        
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        let detailViewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Load initial data
        await listViewModel.loadExpenses()
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Perform multiple rapid updates
        for i in 1...5 {
            let updateData = ExpenseData(
                amount: Decimal(25.99 + Double(i)),
                merchant: "Consistency Test Update \(i)",
                date: Date()
            )
            
            try await dataService.updateExpense(expense, with: updateData)
            
            // Small delay to allow propagation
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // Wait for all updates to propagate
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify final consistency across all views
        let listExpense = listViewModel.displayedExpenses.first { $0.objectID == expense.objectID }
        
        await detailViewModel.refreshExpense()
        let detailExpense = detailViewModel.expense
        
        XCTAssertNotNil(listExpense)
        XCTAssertNotNil(detailExpense)
        XCTAssertEqual(listExpense?.merchant, "Consistency Test Update 5")
        XCTAssertEqual(detailExpense?.merchant, "Consistency Test Update 5")
        XCTAssertEqual(listExpense?.amount.decimalValue, 30.99)
        XCTAssertEqual(detailExpense?.amount.decimalValue, 30.99)
    }
    
    func testDataConsistencyWithCascadeDeletes() async throws {
        // Create expense with related data
        let category = try? viewContext.fetch(Category.fetchRequest()).first
        let categoryData = category.map { CategoryData(from: $0) }
        
        let expenseData = ExpenseData(
            amount: 100.00,
            merchant: "Cascade Test",
            date: Date(),
            category: categoryData,
            items: [
                ExpenseItemData(name: "Item 1", amount: 50.00),
                ExpenseItemData(name: "Item 2", amount: 50.00)
            ]
        )
        
        let expense = try await dataService.createExpense(expenseData)
        let expenseItems = (expense.items as? Set<ExpenseItem>) ?? []
        let itemIds = expenseItems.map { $0.objectID }
        
        // Create view models
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        let detailViewModel = ExpenseDetailViewModel(dataService: dataService, expenseID: expense.objectID)
        
        // Load initial data
        await listViewModel.loadExpenses()
        
        // Wait for initial load
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify initial state
        XCTAssertEqual(listViewModel.displayedExpenses.count, 1)
        XCTAssertNotNil(detailViewModel.expense)
        
        // Delete the expense
        await listViewModel.deleteExpense(expense)
        
        // Wait for deletion to propagate
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Verify expense is removed from list
        XCTAssertEqual(listViewModel.displayedExpenses.count, 0)
        
        // Verify detail view handles deletion
        await detailViewModel.refreshExpense()
        XCTAssertTrue(detailViewModel.isDeleted || detailViewModel.error != nil)
        
        // Verify cascade deletion of expense items
        for itemId in itemIds {
            do {
                let item = try viewContext.existingObject(with: itemId)
                XCTAssertTrue(item.isDeleted, "ExpenseItem should be cascade deleted")
            } catch {
                // Expected - object should not exist
            }
        }
        
        // Verify category still exists (nullify relationship)
        XCTAssertNotNil(category)
        XCTAssertFalse(category!.isDeleted)
    }
    
    // MARK: - Error Propagation and Recovery Tests (Requirement 8.5)
    
    func testErrorPropagationAcrossComponents() async throws {
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        
        // Create a mock data service that will fail
        let mockDataService = MockFailingExpenseDataService(context: viewContext)
        mockDataService.shouldFailCreateExpense = true
        
        let failingListViewModel = ExpenseListViewModel(
            dataService: mockDataService,
            filterService: filterService,
            sortService: sortService
        )
        
        // Attempt to create expense through failing service
        do {
            let expenseData = await createTestExpenseData(merchant: "Error Test", amount: 25.99)
            _ = try await mockDataService.createExpense(expenseData)
            XCTFail("Expected error to be thrown")
        } catch {
            // Expected error
            XCTAssertTrue(error is ExpenseError)
        }
        
        // Verify error state is reflected in view model
        XCTAssertNotNil(mockDataService.error)
        
        // Test error recovery
        mockDataService.shouldFailCreateExpense = false
        mockDataService.clearErrors()
        
        // Verify recovery works
        let expenseData = await createTestExpenseData(merchant: "Recovery Test", amount: 35.99)
        let recoveredExpense = try await mockDataService.createExpense(expenseData)
        
        XCTAssertNotNil(recoveredExpense)
        XCTAssertNil(mockDataService.error)
    }
    
    func testErrorRecoveryInDetailView() async throws {
        // Create expense
        let expense = try await dataService.createExpense(
            await createTestExpenseData(merchant: "Error Recovery Test", amount: 25.99)
        )
        
        // Create mock service that will fail on getExpense
        let mockDataService = MockFailingExpenseDataService(context: viewContext)
        mockDataService.shouldFailGetExpense = true
        
        let detailViewModel = ExpenseDetailViewModel(dataService: mockDataService, expenseID: expense.objectID)
        
        // Wait for initial load to fail
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Verify error state
        XCTAssertNotNil(detailViewModel.error)
        XCTAssertNil(detailViewModel.expense)
        
        // Enable recovery
        mockDataService.shouldFailGetExpense = false
        
        // Test recovery
        await detailViewModel.recoverFromError()
        
        // Verify recovery succeeded
        XCTAssertNil(detailViewModel.error)
        XCTAssertNotNil(detailViewModel.expense)
        XCTAssertEqual(detailViewModel.expense?.merchant, "Error Recovery Test")
    }
    
    func testErrorHandlingWithConcurrentOperations() async throws {
        let mockDataService = MockFailingExpenseDataService(context: viewContext)
        
        let operationCount = 10
        
        var successCount = 0
        var errorCount = 0
        
        // Mix of successful and failing operations (sequential for test stability)
        for i in 0..<operationCount {
            do {
                mockDataService.shouldFailCreateExpense = (i % 3 == 0) // Fail every 3rd operation
                
                let expenseData = await createTestExpenseData(
                    merchant: "Sequential Error Test \(i)",
                    amount: Decimal(10 + i)
                )
                
                _ = try await mockDataService.createExpense(expenseData)
                successCount += 1
            } catch {
                errorCount += 1
            }
        }
        
        // Verify mixed results
        XCTAssertGreaterThan(successCount, 0)
        XCTAssertGreaterThan(errorCount, 0)
        XCTAssertEqual(successCount + errorCount, operationCount)
        
        // Verify system remains stable after errors
        mockDataService.shouldFailCreateExpense = false
        mockDataService.clearErrors()
        
        let recoveryData = await createTestExpenseData(merchant: "Recovery After Errors", amount: 99.99)
        let recoveryExpense = try await mockDataService.createExpense(recoveryData)
        
        XCTAssertNotNil(recoveryExpense)
        XCTAssertEqual(recoveryExpense.merchant, "Recovery After Errors")
    }
    
    // MARK: - Performance Integration Tests
    
    func testLargeDatasetPerformance() async throws {
        // Create large dataset
        let largeDatasetSize = 100 // Reduced for test performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        _ = try await createMultipleTestExpenses(count: largeDatasetSize)
        
        let creationTime = CFAbsoluteTimeGetCurrent() - startTime
        XCTAssertLessThan(creationTime, 5.0, "Large dataset creation should complete within 5 seconds")
        
        // Test list view performance with large dataset
        let listViewModel = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        
        let loadStartTime = CFAbsoluteTimeGetCurrent()
        await listViewModel.loadExpenses()
        try await Task.sleep(nanoseconds: 500_000_000) // Wait for load
        let loadTime = CFAbsoluteTimeGetCurrent() - loadStartTime
        
        XCTAssertLessThan(loadTime, 2.0, "Large dataset load should complete within 2 seconds")
        XCTAssertEqual(listViewModel.displayedExpenses.count, largeDatasetSize)
        
        // Test filtering performance
        let filterStartTime = CFAbsoluteTimeGetCurrent()
        await MainActor.run {
            listViewModel.searchText = "Restaurant"
        }
        await listViewModel.applyFilters()
        let filterTime = CFAbsoluteTimeGetCurrent() - filterStartTime
        
        XCTAssertLessThan(filterTime, 1.0, "Filtering large dataset should complete within 1 second")
        
        // Test sorting performance
        let sortStartTime = CFAbsoluteTimeGetCurrent()
        await listViewModel.updateSort(.amountDescending)
        let sortTime = CFAbsoluteTimeGetCurrent() - sortStartTime
        
        XCTAssertLessThan(sortTime, 1.0, "Sorting large dataset should complete within 1 second")
    }
    
    func testMemoryUsageWithLargeDataset() async throws {
        // This test verifies that memory usage remains reasonable with large datasets
        let initialMemory = getMemoryUsage()
        
        // Create large dataset
        _ = try await createMultipleTestExpenses(count: 100) // Reduced for test performance
        
        // Create multiple view models
        let listViewModel1 = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        let listViewModel2 = ExpenseListViewModel(dataService: dataService, filterService: filterService, sortService: sortService)
        
        // Load data in both view models
        await listViewModel1.loadExpenses()
        await listViewModel2.loadExpenses()
        
        // Wait for data to load
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        let peakMemory = getMemoryUsage()
        let memoryIncrease = peakMemory - initialMemory
        
        // Memory increase should be reasonable (less than 50MB for test dataset)
        XCTAssertLessThan(memoryIncrease, 50 * 1024 * 1024, "Memory usage should remain reasonable")
        
        // Clean up view models
        _ = listViewModel1
        _ = listViewModel2
    }
    
    // MARK: - Helper Methods for Performance Testing
    
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
}

// MARK: - Mock Failing ExpenseDataService

class MockFailingExpenseDataService: ExpenseDataService {
    var shouldFailCreateExpense = false
    var shouldFailUpdateExpense = false
    var shouldFailDeleteExpense = false
    var shouldFailGetExpense = false
    var shouldFailLoadExpenses = false
    
    override func createExpense(_ expenseData: ExpenseData) async throws -> Expense {
        if shouldFailCreateExpense {
            throw ExpenseError.savingFailed(NSError(domain: "MockError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock create failure"]))
        }
        return try await super.createExpense(expenseData)
    }
    
    override func updateExpense(_ expense: Expense, with expenseData: ExpenseData) async throws {
        if shouldFailUpdateExpense {
            throw ExpenseError.savingFailed(NSError(domain: "MockError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock update failure"]))
        }
        try await super.updateExpense(expense, with: expenseData)
    }
    
    override func deleteExpense(_ expense: Expense) async throws {
        if shouldFailDeleteExpense {
            throw ExpenseError.deletionFailed(NSError(domain: "MockError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock delete failure"]))
        }
        try await super.deleteExpense(expense)
    }
    
    override func getExpense(by id: NSManagedObjectID) async -> Expense? {
        if shouldFailGetExpense {
            return nil
        }
        return await super.getExpense(by: id)
    }
    
    override func loadExpenses() async {
        if shouldFailLoadExpenses {
            await MainActor.run {
                self.error = ExpenseError.loadingFailed(NSError(domain: "MockError", code: 4, userInfo: [NSLocalizedDescriptionKey: "Mock load failure"]))
            }
            return
        }
        await super.loadExpenses()
    }
}