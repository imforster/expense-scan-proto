import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class RecurringExpenseDeleteTests: CoreDataTestCase {
    
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
    
    func testDeleteRecurringExpenseBasic() throws {
        // Create recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Verify it exists
        let initialExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(initialExpenses.count, 1)
        
        // Delete it
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: false)
        
        try testContext.save()
        
        // Verify it's deleted
        let remainingExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(remainingExpenses.count, 0)
    }
    
    func testBulkDeleteRecurringExpenses() throws {
        // Create multiple recurring expenses
        let expense1 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "25.00"),
            currencyCode: "USD",
            merchant: "Merchant 1",
            category: testCategory,
            patternType: .weekly,
            startDate: Date()
        )
        
        let expense2 = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Merchant 2",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Verify they exist
        let initialExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(initialExpenses.count, 2)
        
        // Bulk delete
        recurringExpenseService.deleteRecurringExpenses([expense1, expense2], deleteGeneratedExpenses: false)
        
        try testContext.save()
        
        // Verify they're deleted
        let remainingExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(remainingExpenses.count, 0)
    }
    
    func testDeleteAlreadyDeletedExpense() throws {
        // Create recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Delete it once
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: false)
        try testContext.save()
        
        // Verify it's deleted
        let remainingExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(remainingExpenses.count, 0)
        
        // Try to delete it again - should not crash
        recurringExpenseService.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: false)
        
        // Should still be 0
        let finalExpenses = recurringExpenseService.getActiveRecurringExpenses()
        XCTAssertEqual(finalExpenses.count, 0)
    }
}