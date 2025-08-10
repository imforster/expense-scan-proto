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
}