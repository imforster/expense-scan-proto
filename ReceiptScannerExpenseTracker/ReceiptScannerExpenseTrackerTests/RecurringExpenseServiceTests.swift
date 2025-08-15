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
    
    // MARK: - Template Synchronization Tests
    
    func testDetectTemplateLinkedExpenseModification() throws {
        // Create recurring expense template with a due date in the past
        let pastDate = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Original Merchant",
            notes: "Original notes",
            paymentMethod: "Credit Card",
            category: testCategory,
            patternType: .monthly,
            startDate: pastDate
        )
        
        // Manually set the next due date to be in the past to make it due for generation
        recurringExpense.pattern?.nextDueDate = pastDate
        
        try testContext.save()
        
        // Generate expense from template
        let generatedExpense = recurringExpenseService.generateExpense(from: recurringExpense)
        XCTAssertNotNil(generatedExpense, "Should be able to generate expense from due template")
        
        try testContext.save()
        
        // Initially, no modifications should be detected
        XCTAssertFalse(recurringExpenseService.detectTemplateLinkedExpenseModification(generatedExpense!))
        
        // Modify the expense
        generatedExpense!.amount = NSDecimalNumber(string: "150.00")
        generatedExpense!.merchant = "Modified Merchant"
        
        // Now modifications should be detected
        XCTAssertTrue(recurringExpenseService.detectTemplateLinkedExpenseModification(generatedExpense!))
    }
    
    func testGetExpenseTemplateChanges() throws {
        // Create recurring expense template with a due date in the past
        let pastDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "75.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            notes: "Test notes",
            paymentMethod: "Debit Card",
            category: testCategory,
            patternType: .weekly,
            startDate: pastDate
        )
        
        // Manually set the next due date to be in the past to make it due for generation
        recurringExpense.pattern?.nextDueDate = pastDate
        
        try testContext.save()
        
        // Generate expense from template
        let generatedExpense = recurringExpenseService.generateExpense(from: recurringExpense)
        XCTAssertNotNil(generatedExpense, "Should be able to generate expense from due template")
        
        try testContext.save()
        
        // Initially, no changes should be detected
        var changes = recurringExpenseService.getExpenseTemplateChanges(generatedExpense!)
        XCTAssertTrue(changes.isEmpty)
        
        // Modify multiple fields
        generatedExpense!.amount = NSDecimalNumber(string: "125.00")
        generatedExpense!.merchant = "Updated Merchant"
        generatedExpense!.notes = "Updated notes"
        generatedExpense!.currencyCode = "EUR"
        
        // Get changes
        changes = recurringExpenseService.getExpenseTemplateChanges(generatedExpense!)
        XCTAssertEqual(changes.count, 4)
        
        // Verify change types
        let changeTypes = changes.map { $0.changeTypeKey }
        XCTAssertTrue(changeTypes.contains("amount"))
        XCTAssertTrue(changeTypes.contains("merchant"))
        XCTAssertTrue(changeTypes.contains("notes"))
        XCTAssertTrue(changeTypes.contains("currency"))
    }
    
    func testUpdateTemplateFromExpense() throws {
        // Create recurring expense template
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Original Merchant",
            notes: "Original notes",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Create changes to apply
        let changes: [TemplateChangeType] = [
            .amount(from: NSDecimalNumber(string: "50.00"), to: NSDecimalNumber(string: "75.00")),
            .merchant(from: "Original Merchant", to: "Updated Merchant"),
            .notes(from: "Original notes", to: "Updated notes"),
            .currency(from: "USD", to: "EUR")
        ]
        
        // Apply changes to template
        try recurringExpenseService.updateTemplateFromExpense(recurringExpense, with: changes)
        
        // Verify changes were applied
        XCTAssertEqual(recurringExpense.amount, NSDecimalNumber(string: "75.00"))
        XCTAssertEqual(recurringExpense.merchant, "Updated Merchant")
        XCTAssertEqual(recurringExpense.notes, "Updated notes")
        XCTAssertEqual(recurringExpense.currencyCode, "EUR")
    }
    
    func testSynchronizeTemplateFromExpense() throws {
        // Create recurring expense template with a due date in the past
        let pastDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "200.00"),
            currencyCode: "USD",
            merchant: "Sync Test Merchant",
            notes: "Sync test notes",
            category: testCategory,
            patternType: .weekly,
            startDate: pastDate
        )
        
        // Manually set the next due date to be in the past to make it due for generation
        recurringExpense.pattern?.nextDueDate = pastDate
        
        try testContext.save()
        
        // Generate expense from template
        let generatedExpense = recurringExpenseService.generateExpense(from: recurringExpense)
        XCTAssertNotNil(generatedExpense, "Should be able to generate expense from due template")
        
        try testContext.save()
        
        // Modify the generated expense
        generatedExpense!.amount = NSDecimalNumber(string: "250.00")
        generatedExpense!.merchant = "Synchronized Merchant"
        generatedExpense!.notes = "Synchronized notes"
        
        // Synchronize template from expense
        try recurringExpenseService.synchronizeTemplateFromExpense(generatedExpense!)
        
        // Verify template was updated
        XCTAssertEqual(recurringExpense.amount, NSDecimalNumber(string: "250.00"))
        XCTAssertEqual(recurringExpense.merchant, "Synchronized Merchant")
        XCTAssertEqual(recurringExpense.notes, "Synchronized notes")
    }
    
    func testValidateTemplateNotOrphaned() throws {
        // Create recurring expense template
        let activeTemplate = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Active Template",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        // Create old inactive template
        let oldInactiveTemplate = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Old Inactive Template",
            category: testCategory,
            patternType: .monthly,
            startDate: Date().addingTimeInterval(-200 * 24 * 60 * 60) // ~7 months ago
        )
        oldInactiveTemplate.isActive = false
        
        try testContext.save()
        
        // Generate expense from active template
        let _ = recurringExpenseService.generateExpense(from: activeTemplate)
        
        try testContext.save()
        
        // Active template with generated expenses should not be orphaned
        XCTAssertTrue(recurringExpenseService.validateTemplateNotOrphaned(activeTemplate))
        
        // Old inactive template without generated expenses should be orphaned
        XCTAssertFalse(recurringExpenseService.validateTemplateNotOrphaned(oldInactiveTemplate))
    }
    
    func testFindOrphanedTemplates() throws {
        // Create active template with generated expense
        let activeTemplate = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Active Template",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        // Create orphaned template
        let orphanedTemplate = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "50.00"),
            currencyCode: "USD",
            merchant: "Orphaned Template",
            category: testCategory,
            patternType: .monthly,
            startDate: Date().addingTimeInterval(-200 * 24 * 60 * 60) // ~7 months ago
        )
        orphanedTemplate.isActive = false
        
        try testContext.save()
        
        // Generate expense from active template
        let _ = recurringExpenseService.generateExpense(from: activeTemplate)
        
        try testContext.save()
        
        // Find orphaned templates
        let orphanedTemplates = recurringExpenseService.findOrphanedTemplates()
        
        XCTAssertEqual(orphanedTemplates.count, 1)
        XCTAssertEqual(orphanedTemplates.first?.merchant, "Orphaned Template")
    }
    
    func testResolveTemplateUpdateConflicts() throws {
        // Create recurring expense template
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Conflict Test Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Create conflicting changes
        let conflictingChanges: [[TemplateChangeType]] = [
            [
                .amount(from: NSDecimalNumber(string: "100.00"), to: NSDecimalNumber(string: "150.00")),
                .merchant(from: "Conflict Test Merchant", to: "Updated Merchant A")
            ],
            [
                .amount(from: NSDecimalNumber(string: "100.00"), to: NSDecimalNumber(string: "150.00")), // Same amount
                .merchant(from: "Conflict Test Merchant", to: "Updated Merchant B")
            ],
            [
                .amount(from: NSDecimalNumber(string: "100.00"), to: NSDecimalNumber(string: "200.00")),
                .merchant(from: "Conflict Test Merchant", to: "Updated Merchant A") // Same merchant as first
            ]
        ]
        
        // Resolve conflicts
        let resolvedChanges = try recurringExpenseService.resolveTemplateUpdateConflicts(recurringExpense, conflictingChanges: conflictingChanges)
        
        XCTAssertEqual(resolvedChanges.count, 2) // Should have amount and merchant changes
        
        // Verify resolved changes
        let changeTypes = resolvedChanges.map { $0.changeTypeKey }
        XCTAssertTrue(changeTypes.contains("amount"))
        XCTAssertTrue(changeTypes.contains("merchant"))
        
        // Amount should be the most common (150.00 appears twice)
        let amountChange = resolvedChanges.first { $0.changeTypeKey == "amount" }
        if case .amount(_, let resolvedAmount) = amountChange {
            XCTAssertEqual(resolvedAmount, NSDecimalNumber(string: "150.00"))
        } else {
            XCTFail("Expected amount change")
        }
        
        // Merchant should be the most common ("Updated Merchant A" appears twice)
        let merchantChange = resolvedChanges.first { $0.changeTypeKey == "merchant" }
        if case .merchant(_, let resolvedMerchant) = merchantChange {
            XCTAssertEqual(resolvedMerchant, "Updated Merchant A")
        } else {
            XCTFail("Expected merchant change")
        }
    }
    
    func testTemplateUpdateWithInvalidTemplate() throws {
        // Create and then delete a recurring expense
        let recurringExpense = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(string: "100.00"),
            currencyCode: "USD",
            merchant: "Test Merchant",
            category: testCategory,
            patternType: .monthly,
            startDate: Date()
        )
        
        try testContext.save()
        
        // Delete the template
        testContext.delete(recurringExpense)
        try testContext.save()
        
        // Try to update the deleted template
        let changes: [TemplateChangeType] = [
            .amount(from: NSDecimalNumber(string: "100.00"), to: NSDecimalNumber(string: "150.00"))
        ]
        
        XCTAssertThrowsError(try recurringExpenseService.updateTemplateFromExpense(recurringExpense, with: changes)) { error in
            XCTAssertTrue(error is RecurringExpenseError)
            if case RecurringExpenseError.templateNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected templateNotFound error")
            }
        }
    }
    
    func testSynchronizeTemplateFromExpenseWithoutTemplate() throws {
        // Create a regular expense without a recurring template
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "100.00")
        expense.currencyCode = "USD"
        expense.merchant = "Regular Merchant"
        expense.date = Date()
        expense.category = testCategory
        expense.isRecurring = false
        
        try testContext.save()
        
        // Try to synchronize template from expense without template
        XCTAssertThrowsError(try recurringExpenseService.synchronizeTemplateFromExpense(expense)) { error in
            XCTAssertTrue(error is RecurringExpenseError)
            if case RecurringExpenseError.templateNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected templateNotFound error")
            }
        }
    }
}