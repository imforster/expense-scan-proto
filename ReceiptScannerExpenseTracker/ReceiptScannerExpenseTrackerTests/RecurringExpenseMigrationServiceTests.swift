import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class RecurringExpenseMigrationServiceTests: CoreDataTestCase {
    
    var migrationService: RecurringExpenseMigrationService!
    var testCategory: ReceiptScannerExpenseTracker.Category!
    var testTag: Tag!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        migrationService = RecurringExpenseMigrationService(context: testContext)
        
        // Create test category
        testCategory = ReceiptScannerExpenseTracker.Category(context: testContext)
        testCategory.id = UUID()
        testCategory.name = "Test Category"
        testCategory.colorHex = "FF0000"
        testCategory.icon = "test.icon"
        
        // Create test tag
        testTag = Tag(context: testContext)
        testTag.id = UUID()
        testTag.name = "Test Tag"
        
        try testContext.save()
    }
    
    // MARK: - Migration Tests
    
    func testMigrateMonthlyRecurringExpense() throws {
        // Create an expense with notes-based recurring info
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            merchant: "Monthly Test Merchant",
            notes: "Test expense [Recurring: monthly, interval:1, day:15]",
            category: testCategory,
            tags: [testTag]
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.totalFound, 1)
        XCTAssertEqual(result.successfulMigrations.count, 1)
        XCTAssertEqual(result.skippedMigrations.count, 0)
        XCTAssertEqual(result.failedMigrations.count, 0)
        XCTAssertNil(result.saveError)
        
        let migratedExpense = result.successfulMigrations.first!
        XCTAssertEqual(migratedExpense.originalExpense, expense)
        
        let recurringExpense = migratedExpense.newRecurringExpense
        XCTAssertEqual(recurringExpense.amount, expense.amount)
        XCTAssertEqual(recurringExpense.merchant, expense.merchant)
        XCTAssertEqual(recurringExpense.category, expense.category)
        XCTAssertEqual(recurringExpense.pattern?.patternType, "Monthly")
        XCTAssertEqual(recurringExpense.pattern?.interval, 1)
        XCTAssertEqual(recurringExpense.pattern?.dayOfMonth, 15)
        XCTAssertTrue(recurringExpense.safeTags.contains(testTag))
        
        // Verify the original expense is linked and cleaned up
        XCTAssertEqual(expense.recurringTemplate, recurringExpense)
        XCTAssertFalse(expense.isRecurring)
        XCTAssertEqual(expense.notes, "Test expense") // Recurring info should be removed
    }
    
    func testMigrateWeeklyRecurringExpense() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "25.00"),
            merchant: "Weekly Test Merchant",
            notes: "Weekly expense [Recurring: weekly, interval:2]"
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.successfulMigrations.count, 1)
        
        let recurringExpense = result.successfulMigrations.first!.newRecurringExpense
        XCTAssertEqual(recurringExpense.pattern?.patternType, "Weekly")
        XCTAssertEqual(recurringExpense.pattern?.interval, 2)
        XCTAssertEqual(recurringExpense.pattern?.dayOfMonth, 0)
    }
    
    func testMigrateQuarterlyRecurringExpense() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "300.00"),
            merchant: "Quarterly Test Merchant",
            notes: "Quarterly payment [Recurring: quarterly, interval:1]"
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.successfulMigrations.count, 1)
        
        let recurringExpense = result.successfulMigrations.first!.newRecurringExpense
        XCTAssertEqual(recurringExpense.pattern?.patternType, "Quarterly")
        XCTAssertEqual(recurringExpense.pattern?.interval, 1)
    }
    
    func testMigrateMultipleRecurringExpenses() throws {
        // Create multiple expenses with different patterns
        let expense1 = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            merchant: "Monthly Merchant",
            notes: "Monthly [Recurring: monthly, interval:1, day:1]"
        )
        
        let expense2 = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "20.00"),
            merchant: "Weekly Merchant",
            notes: "Weekly [Recurring: weekly, interval:1]"
        )
        
        let expense3 = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            merchant: "Biweekly Merchant",
            notes: "Biweekly [Recurring: biweekly, interval:1]"
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.totalFound, 3)
        XCTAssertEqual(result.successfulMigrations.count, 3)
        XCTAssertEqual(result.skippedMigrations.count, 0)
        XCTAssertEqual(result.failedMigrations.count, 0)
        
        let merchants = result.successfulMigrations.map { $0.newRecurringExpense.merchant }.sorted()
        XCTAssertEqual(merchants, ["Biweekly Merchant", "Monthly Merchant", "Weekly Merchant"])
    }
    
    func testSkipExpenseWithoutRecurringInfo() throws {
        // Create a regular expense without recurring info
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "30.00")
        expense.merchant = "Regular Merchant"
        expense.notes = "Regular expense without recurring info"
        expense.date = Date()
        expense.currencyCode = "USD"
        expense.isRecurring = true // Marked as recurring but no valid info in notes
        
        try testContext.save()
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.totalFound, 1)
        XCTAssertEqual(result.successfulMigrations.count, 0)
        XCTAssertEqual(result.skippedMigrations.count, 1)
        XCTAssertEqual(result.failedMigrations.count, 0)
        
        let skippedMigration = result.skippedMigrations.first!
        XCTAssertEqual(skippedMigration.expense, expense)
        XCTAssertEqual(skippedMigration.reason, "No valid recurring info found in notes")
    }
    
    func testSkipExpenseWithExistingRecurringTemplate() throws {
        // Create a recurring expense first
        let recurringExpense = RecurringExpense(context: testContext)
        recurringExpense.id = UUID()
        recurringExpense.amount = NSDecimalNumber(string: "40.00")
        recurringExpense.merchant = "Existing Template Merchant"
        recurringExpense.currencyCode = "USD"
        recurringExpense.isActive = true
        recurringExpense.createdDate = Date()
        
        // Create an expense that already has a recurring template
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "40.00"),
            merchant: "Existing Template Merchant",
            notes: "Already migrated [Recurring: monthly, interval:1]"
        )
        expense.recurringTemplate = recurringExpense
        
        try testContext.save()
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.totalFound, 1)
        XCTAssertEqual(result.successfulMigrations.count, 0)
        XCTAssertEqual(result.skippedMigrations.count, 1)
        XCTAssertEqual(result.failedMigrations.count, 0)
        
        let skippedMigration = result.skippedMigrations.first!
        XCTAssertEqual(skippedMigration.reason, "Expense already has a recurring template")
    }
    
    func testSkipExpenseWithUnsupportedPattern() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "60.00"),
            merchant: "Unsupported Pattern Merchant",
            notes: "Unsupported [Recurring: daily, interval:1]" // Daily is not supported
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.totalFound, 1)
        XCTAssertEqual(result.successfulMigrations.count, 0)
        XCTAssertEqual(result.skippedMigrations.count, 1)
        XCTAssertEqual(result.failedMigrations.count, 0)
        
        let skippedMigration = result.skippedMigrations.first!
        XCTAssertTrue(skippedMigration.reason.contains("Unsupported recurring pattern"))
    }
    
    func testCleanNotesFromRecurringInfo() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "80.00"),
            merchant: "Clean Notes Merchant",
            notes: "Important notes before [Recurring: monthly, interval:1] and after"
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.successfulMigrations.count, 1)
        
        // Verify notes are cleaned but other content is preserved
        XCTAssertEqual(expense.notes, "Important notes before  and after")
    }
    
    func testCleanNotesWithOnlyRecurringInfo() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "90.00"),
            merchant: "Only Recurring Info Merchant",
            notes: "[Recurring: weekly, interval:1]"
        )
        
        let result = migrationService.migrateAllRecurringExpenses()
        
        XCTAssertEqual(result.successfulMigrations.count, 1)
        
        // Verify notes are set to nil when only recurring info was present
        XCTAssertNil(expense.notes)
    }
    
    // MARK: - Validation Tests
    
    func testValidationAfterSuccessfulMigration() throws {
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "120.00"),
            merchant: "Validation Test Merchant",
            notes: "Test [Recurring: monthly, interval:1]"
        )
        
        let migrationResult = migrationService.migrateAllRecurringExpenses()
        XCTAssertEqual(migrationResult.successfulMigrations.count, 1)
        
        let validationResult = migrationService.validateMigration()
        
        XCTAssertTrue(validationResult.isValid)
        XCTAssertEqual(validationResult.remainingNotesBasedExpenses, 0)
        XCTAssertEqual(validationResult.totalRecurringExpenses, 1)
        XCTAssertEqual(validationResult.orphanedRecurringExpenses, 1) // No generated expenses yet
        XCTAssertEqual(validationResult.conflictingExpenses, 0)
        XCTAssertTrue(validationResult.validationErrors.isEmpty)
    }
    
    func testValidationWithRemainingNotesBasedExpenses() throws {
        // Create an expense that won't be migrated (invalid pattern)
        let expense = createNotesBasedRecurringExpense(
            amount: NSDecimalNumber(string: "150.00"),
            merchant: "Invalid Pattern Merchant",
            notes: "Invalid [Recurring: invalid_pattern, interval:1]"
        )
        
        let migrationResult = migrationService.migrateAllRecurringExpenses()
        XCTAssertEqual(migrationResult.skippedMigrations.count, 1)
        
        let validationResult = migrationService.validateMigration()
        
        XCTAssertFalse(validationResult.isValid)
        XCTAssertEqual(validationResult.remainingNotesBasedExpenses, 1)
        XCTAssertEqual(validationResult.totalRecurringExpenses, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createNotesBasedRecurringExpense(
        amount: NSDecimalNumber,
        merchant: String,
        notes: String,
        category: ReceiptScannerExpenseTracker.Category? = nil,
        tags: [Tag] = []
    ) -> Expense {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = amount
        expense.merchant = merchant
        expense.notes = notes
        expense.date = Date()
        expense.currencyCode = "USD"
        expense.isRecurring = true
        expense.category = category
        
        for tag in tags {
            expense.addToTags(tag)
        }
        
        do {
            try testContext.save()
        } catch {
            XCTFail("Failed to save test expense: \(error)")
        }
        
        return expense
    }
}