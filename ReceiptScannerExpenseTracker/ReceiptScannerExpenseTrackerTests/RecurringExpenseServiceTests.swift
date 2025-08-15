import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class RecurringExpenseServiceTests: CoreDataTestCase {
    
    var recurringExpenseService: RecurringExpenseService!
    var testCategory: ReceiptScannerExpenseTracker.Category!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        recurringExpenseService = RecurringExpenseService(context: testContext)
        
        // Create test category
        testCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        testCategory.id = UUID()
        testCategory.name = "Test Category"
        testCategory.colorHex = "FF0000"
        testCategory.icon = "test.icon"
        
        try testContext.save()
    }
    
    func testCreateRecurringExpense() throws {
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            notes: "Test notes",
            paymentMethod: "Credit Card",
            category: testCategory,
            tags: [],
            patternType: .monthly,
            interval: 1,
            dayOfMonth: 15,
            dayOfWeek: nil,
            startDate: Date()
        )
        
        try testContext.save()
        
        XCTAssertNotNil(recurringExpense.id)
        XCTAssertEqual(recurringExpense.amount, NSDecimalNumber(string: "50.00"))
        XCTAssertEqual(recurringExpense.currencyCode, "USD")
        XCTAssertEqual(recurringExpense.merchant, "Test Merchant")
        XCTAssertEqual(recurringExpense.notes, "Test notes")
        XCTAssertEqual(recurringExpense.paymentMethod, "Credit Card")
        XCTAssertTrue(recurringExpense.isActive)
        XCTAssertNotNil(recurringExpense.createdDate)
        XCTAssertEqual(recurringExpense.category, testCategory)
        XCTAssertNotNil(recurringExpense.pattern)
        XCTAssertEqual(recurringExpense.pattern?.patternType, "Monthly")
        XCTAssertEqual(recurringExpense.pattern?.interval, 1)
        XCTAssertEqual(recurringExpense.pattern?.dayOfMonth, 15)
    }
    
    func testGetActiveRecurringExpenses() throws {
        // Create active recurring expense
        let activeExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Active Merchant",
            category: testCategory,
            patternType: .weekly,
            startDate: Date()
        )
        
        // Create inactive recurring expense
        let inactiveExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "200.00"),
            currencyCode: "USD",
            merchant: "Inactive Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        inactiveExpense.isActive = false
        
        try testContext.save()
        
        let activeExpenses = recurringExpenseService.getActiveRecurringExpenses()
        
        XCTAssertEqual(activeExpenses.count, 1)
        XCTAssertEqual(activeExpenses.first?.merchant, "Active Merchant")
        XCTAssertTrue(activeExpenses.first?.isActive ?? false)
    }
    
    func testGenerateExpenseFromRecurringTemplate() throws {
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            currencyCode: "USD",
            merchant: "Recurring Merchant",
            category: testCategory,
            patternType: .weekly,
            startDate: Date().addingTimeInterval(-7 * 24 * 60 * 60) // 1 week ago
        )
        
        try testContext.save()
        
        let generatedExpense = recurringExpenseService.generateExpense(from: recurringExpense)
        
        XCTAssertNotNil(generatedExpense)
        XCTAssertEqual(generatedExpense?.amount, NSDecimalNumber(string: "75.00"))
        XCTAssertEqual(generatedExpense?.merchant, "Recurring Merchant")
        XCTAssertEqual(generatedExpense?.category, testCategory)
        XCTAssertFalse(generatedExpense?.isRecurring ?? true)
        XCTAssertEqual(generatedExpense?.recurringTemplate, recurringExpense)
    }
    
    // MARK: - Delete Functionality Tests
    
    func testDeleteRecurringExpenseKeepingGeneratedExpenses() throws {
        // Create recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60) // 1 month ago
        )
        
        try testContext.save()
        
        // Generate an expense from the template
        let generatedExpense = recurringExpenseService.generateExpense(from: recurringExpense)
        XCTAssertNotNil(generatedExpense)
        
        try testContext.save()
        
        // Verify the relationship exists
        XCTAssertEqual(generatedExpense?.recurringTemplate, recurringExpense)
        XCTAssertEqual(recurringExpense.safeGeneratedExpenses.count, 1)
        
        // Delete the recurring expense but keep generated expenses
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: false)
        
        try testContext.save()
        
        // Verify the recurring expense is deleted
        let remainingRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertFalse(remainingRecurringExpenses.contains(recurringExpense))
        
        // Verify the generated expense still exists but relationship is cleared
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = try testContext.fetch(request)
        XCTAssertEqual(remainingExpenses.count, 1)
        XCTAssertNil(remainingExpenses.first?.recurringTemplate)
    }
    
    func testDeleteRecurringExpenseWithGeneratedExpenses() throws {
        // Create recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "150.00"),
            currencyCode: "USD",
            merchant: "Delete Test Merchant",
            category: testCategory,
            patternType: .weekly,
            startDate: Date().addingTimeInterval(-14 * 24 * 60 * 60) // 2 weeks ago
        )
        
        try testContext.save()
        
        // Generate multiple expenses from the template
        let expense1 = recurringExpenseService.generateExpense(from: recurringExpense)
        let expense2 = recurringExpenseService.generateExpense(from: recurringExpense)
        XCTAssertNotNil(expense1)
        XCTAssertNotNil(expense2)
        
        try testContext.save()
        
        // Verify relationships exist
        XCTAssertEqual(recurringExpense.safeGeneratedExpenses.count, 2)
        
        // Delete the recurring expense and all generated expenses
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: true)
        
        try testContext.save()
        
        // Verify everything is deleted
        let remainingRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertFalse(remainingRecurringExpenses.contains(recurringExpense))
        
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = try testContext.fetch(request)
        XCTAssertEqual(remainingExpenses.count, 0)
    }
    
    func testDeleteRecurringExpenseWithPatternCleanup() throws {
        // Create recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "200.00"),
            currencyCode: "USD",
            merchant: "Pattern Test Merchant",
            category: testCategory,
            patternType: .monthly,
            interval: 2,
            dayOfMonth: 15,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Verify pattern exists
        XCTAssertNotNil(recurringExpense.pattern)
        let patternId = recurringExpense.pattern?.id
        
        // Delete the recurring expense
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: false)
        
        try testContext.save()
        
        // Verify pattern is also deleted
        let patternRequest: NSFetchRequest<RecurringPatternEntity> = RecurringPatternEntity.fetchRequest()
        patternRequest.predicate = NSPredicate(format: "id == %@", patternId! as CVarArg)
        let remainingPatterns = try testContext.fetch(patternRequest)
        XCTAssertEqual(remainingPatterns.count, 0)
    }
    
    func testBulkDeleteRecurringExpenses() throws {
        // Create multiple recurring expenses
        let recurringExpense1 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Bulk Test 1",
            category: testCategory,
            patternType: .weekly,
            startDate: Date()
        )
        
        let recurringExpense2 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            currencyCode: "USD",
            merchant: "Bulk Test 2",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        let recurringExpense3 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Bulk Test 3",
            category: testCategory,
            patternType: .quarterly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Generate some expenses
        let _ = recurringExpenseService.generateExpense(from: recurringExpense1)
        let _ = recurringExpenseService.generateExpense(from: recurringExpense2)
        
        try testContext.save()
        
        // Verify initial state
        let initialRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(initialRecurringExpenses.count, 3)
        
        let initialExpenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let initialExpenses = try testContext.fetch(initialExpenseRequest)
        XCTAssertEqual(initialExpenses.count, 2)
        
        // Bulk delete first two recurring expenses, keeping generated expenses
        recurringExpenseService.deleteRecurringExpenses([recurringExpense1, recurringExpense2], deleteGeneratedExpenses: false)
        
        try testContext.save()
        
        // Verify results
        let remainingRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(remainingRecurringExpenses.count, 1)
        XCTAssertEqual(remainingRecurringExpenses.first?.merchant, "Bulk Test 3")
        
        let remainingExpenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = try testContext.fetch(remainingExpenseRequest)
        XCTAssertEqual(remainingExpenses.count, 2) // Generated expenses should still exist
        
        // Verify relationships are cleared
        for expense in remainingExpenses {
            XCTAssertNil(expense.recurringTemplate)
        }
    }
    
    func testBulkDeleteRecurringExpensesWithGeneratedExpenses() throws {
        // Create multiple recurring expenses
        let recurringExpense1 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "25.00"),
            currencyCode: "USD",
            merchant: "Bulk Delete 1",
            category: testCategory,
            patternType: .weekly,
            startDate: Date()
        )
        
        let recurringExpense2 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Bulk Delete 2",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Generate expenses from both templates
        let _ = recurringExpenseService.generateExpense(from: recurringExpense1)
        let _ = recurringExpenseService.generateExpense(from: recurringExpense2)
        
        try testContext.save()
        
        // Verify initial state
        let initialExpenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let initialExpenses = try testContext.fetch(initialExpenseRequest)
        XCTAssertEqual(initialExpenses.count, 2)
        
        // Bulk delete recurring expenses and their generated expenses
        recurringExpenseService.deleteRecurringExpenses([recurringExpense1, recurringExpense2], deleteGeneratedExpenses: true)
        
        try testContext.save()
        
        // Verify everything is deleted
        let remainingRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(remainingRecurringExpenses.count, 0)
        
        let remainingExpenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        let remainingExpenses = try testContext.fetch(remainingExpenseRequest)
        XCTAssertEqual(remainingExpenses.count, 0)
    }
}