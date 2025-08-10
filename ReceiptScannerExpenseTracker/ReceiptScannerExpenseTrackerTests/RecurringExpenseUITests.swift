//
//  RecurringExpenseUITests.swift
//  ReceiptScannerExpenseTrackerTests
//
//  Created by Kiro on 8/9/25.
//

import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class RecurringExpenseUITests: CoreDataTestCase {
    
    var recurringExpenseService: RecurringExpenseService!
    
    override func setUp() {
        super.setUp()
        recurringExpenseService = RecurringExpenseService(context: testContext)
    }
    
    // MARK: - SimpleRecurringSetupView Tests
    
    func testSimpleRecurringSetupView_CreatesNewRecurringExpense() throws {
        // Given: An expense without recurring template
        let expense = createTestExpense(merchant: "Test Merchant", amount: NSDecimalNumber(string: "50.00"))
        
        // When: We simulate creating a recurring expense through the setup view
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: expense.amount,
            currencyCode: expense.currencyCode,
            merchant: expense.merchant,
            notes: expense.notes,
            paymentMethod: expense.paymentMethod,
            category: expense.category,
            tags: expense.safeTags,
            patternType: .monthly,
            interval: 1,
            dayOfMonth: nil,
            dayOfWeek: nil,
            startDate: expense.date
        )
        
        // Link the expense to the recurring template
        expense.recurringTemplate = recurringExpense
        
        try testContext.save()
        
        // Then: The expense should be linked to a recurring template
        XCTAssertNotNil(expense.recurringTemplate)
        XCTAssertEqual(expense.recurringTemplate?.merchant, "Test Merchant")
        XCTAssertEqual(expense.recurringTemplate?.amount, NSDecimalNumber(string: "50.00"))
        XCTAssertTrue(expense.recurringTemplate?.isActive ?? false)
    }
    
    func testSimpleRecurringSetupView_UpdatesExistingRecurringExpense() throws {
        // Given: An expense with an existing recurring template
        let expense = createTestExpense(merchant: "Test Merchant", amount: NSDecimalNumber(string: "50.00"))
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: expense.amount,
            currencyCode: expense.currencyCode,
            merchant: expense.merchant,
            notes: expense.notes,
            paymentMethod: expense.paymentMethod,
            category: expense.category,
            tags: expense.safeTags,
            patternType: .monthly,
            interval: 1,
            dayOfMonth: nil,
            dayOfWeek: nil,
            startDate: expense.date
        )
        expense.recurringTemplate = recurringExpense
        try testContext.save()
        
        // When: We update the recurring expense
        recurringExpense.amount = NSDecimalNumber(string: "75.00")
        recurringExpense.pattern?.interval = 2
        try testContext.save()
        
        // Then: The changes should be persisted
        XCTAssertEqual(expense.recurringTemplate?.amount, NSDecimalNumber(string: "75.00"))
        XCTAssertEqual(expense.recurringTemplate?.pattern?.interval, 2)
    }
    
    func testSimpleRecurringSetupView_RemovesRecurringExpense() throws {
        // Given: An expense with a recurring template
        let expense = createTestExpense(merchant: "Test Merchant", amount: NSDecimalNumber(string: "50.00"))
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: expense.amount,
            currencyCode: expense.currencyCode,
            merchant: expense.merchant,
            notes: expense.notes,
            paymentMethod: expense.paymentMethod,
            category: expense.category,
            tags: expense.safeTags,
            patternType: .monthly,
            interval: 1,
            dayOfMonth: nil,
            dayOfWeek: nil,
            startDate: expense.date
        )
        expense.recurringTemplate = recurringExpense
        try testContext.save()
        
        // When: We remove the recurring setting
        expense.recurringTemplate = nil
        recurringExpenseService.deactivateRecurringExpense(recurringExpense)
        try testContext.save()
        
        // Then: The expense should no longer be linked to a recurring template
        XCTAssertNil(expense.recurringTemplate)
        XCTAssertFalse(recurringExpense.isActive)
    }
    
    // MARK: - SimpleRecurringListView Tests
    
    func testSimpleRecurringListView_LoadsActiveRecurringExpenses() throws {
        // Given: Multiple recurring expenses, some active and some inactive
        let activeRecurring = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Active Merchant",
            patternType: .monthly,
            interval: 1
        )
        
        let inactiveRecurring = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Inactive Merchant",
            patternType: .weekly,
            interval: 1
        )
        recurringExpenseService.deactivateRecurringExpense(inactiveRecurring)
        
        try testContext.save()
        
        // When: We load active recurring expenses
        let activeExpenses = recurringExpenseService.getActiveRecurringExpenses()
        
        // Then: Only active recurring expenses should be returned
        XCTAssertEqual(activeExpenses.count, 1)
        XCTAssertEqual(activeExpenses.first?.merchant, "Active Merchant")
        XCTAssertTrue(activeExpenses.first?.isActive ?? false)
    }
    
    func testSimpleRecurringListView_GeneratesDueExpenses() throws {
        // Given: A recurring expense that is due
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Due Merchant",
            patternType: .monthly,
            interval: 1,
            startDate: Calendar.current.date(byAdding: .month, value: -2, to: Date())! // Make it due
        )
        
        // Set the next due date to yesterday to make it due
        recurringExpense.pattern?.nextDueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        try testContext.save()
        
        // When: We generate due expenses
        let generatedExpenses = recurringExpenseService.generateDueExpenses()
        try testContext.save()
        
        // Then: A new expense should be generated
        XCTAssertEqual(generatedExpenses.count, 1)
        XCTAssertEqual(generatedExpenses.first?.merchant, "Due Merchant")
        XCTAssertEqual(generatedExpenses.first?.amount, NSDecimalNumber(string: "100.00"))
        XCTAssertNotNil(generatedExpenses.first?.recurringTemplate)
        XCTAssertEqual(generatedExpenses.first?.recurringTemplate, recurringExpense)
    }
    
    // MARK: - ExpenseDetailView Tests
    
    func testExpenseDetailView_ShowsRecurringTemplateInfo() throws {
        // Given: An expense generated from a recurring template
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            currencyCode: "USD",
            merchant: "Template Merchant",
            patternType: .weekly,
            interval: 2
        )
        
        let generatedExpense = recurringExpense.generateExpense(context: testContext)
        try testContext.save()
        
        // Then: The expense should show it was generated from a recurring template
        XCTAssertNotNil(generatedExpense?.recurringTemplate)
        XCTAssertEqual(generatedExpense?.recurringTemplate, recurringExpense)
        XCTAssertFalse(generatedExpense?.isRecurring ?? true) // Generated expenses are not recurring themselves
    }
    
    func testExpenseDetailView_ShowsLegacyRecurringInfo() throws {
        // Given: An expense with legacy recurring info in notes
        let expense = createTestExpense(merchant: "Legacy Merchant", amount: NSDecimalNumber(string: "25.00"))
        expense.isRecurring = true
        expense.notes = "Some notes [Recurring: monthly, interval:1] here"
        try testContext.save()
        
        // Then: The expense should show legacy recurring info
        XCTAssertTrue(expense.isRecurring)
        XCTAssertNotNil(expense.recurringInfo)
        XCTAssertEqual(expense.recurringInfo?.pattern, .monthly)
        XCTAssertEqual(expense.recurringInfo?.interval, 1)
    }
    
    // MARK: - Visual Indicators Tests
    
    func testVisualIndicators_DistinguishRecurringTemplateVsGeneratedExpense() throws {
        // Given: A recurring template and a generated expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Template Merchant",
            patternType: .monthly,
            interval: 1
        )
        
        let generatedExpense = recurringExpense.generateExpense(context: testContext)
        try testContext.save()
        
        // Then: We should be able to distinguish between template and generated expense
        XCTAssertTrue(recurringExpense.isActive) // Template is active
        XCTAssertNotNil(generatedExpense?.recurringTemplate) // Generated expense has template reference
        XCTAssertFalse(generatedExpense?.isRecurring ?? true) // Generated expense is not recurring itself
        
        // The UI should show different indicators:
        // - RecurringExpense entities should show as "Recurring Template"
        // - Expenses with recurringTemplate should show as "Generated from Recurring"
        // - Expenses with isRecurring=true should show as "Recurring Expense (Legacy)"
    }
    
    // MARK: - Migration Integration Tests
    
    func testMigrationIntegration_ConvertsLegacyToNewFormat() throws {
        // Given: An expense with legacy recurring info
        let legacyExpense = createTestExpense(merchant: "Legacy Merchant", amount: NSDecimalNumber(string: "50.00"))
        legacyExpense.isRecurring = true
        legacyExpense.notes = "Test notes [Recurring: monthly, interval:1, day:15] more notes"
        try testContext.save()
        
        // When: We perform migration
        let migrationService = RecurringExpenseMigrationService(context: testContext)
        let result = migrationService.migrateAllRecurringExpenses()
        
        // Then: The legacy expense should be converted to use new Core Data entities
        XCTAssertEqual(result.successCount, 1)
        XCTAssertEqual(result.failedCount, 0)
        
        // Refresh the expense
        testContext.refresh(legacyExpense, mergeChanges: true)
        
        XCTAssertNotNil(legacyExpense.recurringTemplate)
        XCTAssertFalse(legacyExpense.isRecurring) // Should be cleared after migration
        XCTAssertEqual(legacyExpense.recurringTemplate?.merchant, "Legacy Merchant")
        XCTAssertEqual(legacyExpense.recurringTemplate?.pattern?.patternType, "Monthly")
        XCTAssertEqual(legacyExpense.recurringTemplate?.pattern?.interval, 1)
        XCTAssertEqual(legacyExpense.recurringTemplate?.pattern?.dayOfMonth, 15)
        
        // Notes should be cleaned
        XCTAssertFalse(legacyExpense.notes?.contains("[Recurring:") ?? false)
        XCTAssertEqual(legacyExpense.notes, "Test notes more notes")
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense(merchant: String, amount: NSDecimalNumber) -> Expense {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.merchant = merchant
        expense.amount = amount
        expense.date = Date()
        expense.currencyCode = "USD"
        expense.isRecurring = false
        return expense
    }
}