import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class TemplateUpdateChoiceTests: CoreDataTestCase {
    
    var viewModel: ExpenseEditViewModel!
    var recurringExpenseService: RecurringExpenseService!
    var userSettingsService: UserSettingsService!
    
    override func setUp() {
        super.setUp()
        recurringExpenseService = RecurringExpenseService(context: testContext)
        userSettingsService = UserSettingsService.shared
        
        // Reset user settings to default
        userSettingsService.resetToDefaults()
    }
    
    override func tearDown() {
        viewModel = nil
        recurringExpenseService = nil
        super.tearDown()
    }
    
    // MARK: - Template Update Behavior Tests
    
    func testUserSettingsTemplateUpdateBehavior() {
        // Test default behavior
        XCTAssertEqual(userSettingsService.getTemplateUpdateBehavior(), .alwaysAsk)
        XCTAssertTrue(userSettingsService.shouldAskAboutTemplateUpdates())
        XCTAssertFalse(userSettingsService.shouldAutoUpdateTemplates())
        XCTAssertFalse(userSettingsService.shouldOnlyUpdateExpenses())
        
        // Test setting to always update template
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateTemplate)
        XCTAssertEqual(userSettingsService.getTemplateUpdateBehavior(), .alwaysUpdateTemplate)
        XCTAssertFalse(userSettingsService.shouldAskAboutTemplateUpdates())
        XCTAssertTrue(userSettingsService.shouldAutoUpdateTemplates())
        XCTAssertFalse(userSettingsService.shouldOnlyUpdateExpenses())
        
        // Test setting to only update expenses
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateExpenseOnly)
        XCTAssertEqual(userSettingsService.getTemplateUpdateBehavior(), .alwaysUpdateExpenseOnly)
        XCTAssertFalse(userSettingsService.shouldAskAboutTemplateUpdates())
        XCTAssertFalse(userSettingsService.shouldAutoUpdateTemplates())
        XCTAssertTrue(userSettingsService.shouldOnlyUpdateExpenses())
    }
    
    func testTemplateUpdateBehaviorPersistence() {
        // Set a behavior
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateTemplate)
        
        // Create a new instance to test persistence
        let newSettingsService = UserSettingsService.shared
        XCTAssertEqual(newSettingsService.getTemplateUpdateBehavior(), .alwaysUpdateTemplate)
    }
    
    // MARK: - Change Detection Tests
    
    @MainActor func testDetectSignificantChangesWithoutTemplate() {
        // Create expense without template
        let expense = createTestExpense()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make changes
        viewModel.amount = "100.00"
        viewModel.merchant = "New Merchant"
        
        // Should not detect changes without template
        let changes = viewModel.detectSignificantChanges()
        XCTAssertTrue(changes.isEmpty)
        XCTAssertFalse(viewModel.hasSignificantChanges())
    }
    
    @MainActor func testDetectAmountChanges() {
        // Create expense with template
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Change amount
        viewModel.amount = "100.00"
        
        let changes = viewModel.detectSignificantChanges()
        XCTAssertEqual(changes.count, 1)
        
        if case .amount(let from, let to) = changes.first {
            XCTAssertEqual(from, NSDecimalNumber(value: 50.00))
            XCTAssertEqual(to, NSDecimalNumber(value: 100.00))
        } else {
            XCTFail("Expected amount change")
        }
    }
    
    @MainActor func testDetectMerchantChanges() {
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Change merchant
        viewModel.merchant = "New Merchant"
        
        let changes = viewModel.detectSignificantChanges()
        XCTAssertEqual(changes.count, 1)
        
        if case .merchant(let from, let to) = changes.first {
            XCTAssertEqual(from, "Test Merchant")
            XCTAssertEqual(to, "New Merchant")
        } else {
            XCTFail("Expected merchant change")
        }
    }
    
    @MainActor func testDetectCategoryChanges() {
        let (expense, _) = createExpenseWithTemplate()
        let newCategory = createTestCategory(name: "New Category")
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Change category
        viewModel.selectedCategory = newCategory
        
        let changes = viewModel.detectSignificantChanges()
        XCTAssertEqual(changes.count, 1)
        
        if case .category(let from, let to) = changes.first {
            XCTAssertEqual(from?.name, "Test Category")
            XCTAssertEqual(to?.name, "New Category")
        } else {
            XCTFail("Expected category change")
        }
    }
    
    @MainActor func testDetectMultipleChanges() {
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make multiple changes
        viewModel.amount = "100.00"
        viewModel.merchant = "New Merchant"
        viewModel.paymentMethod = "Credit Card"
        
        let changes = viewModel.detectSignificantChanges()
        XCTAssertEqual(changes.count, 3)
        
        let changeTypes = changes.map { $0.changeTypeKey }
        XCTAssertTrue(changeTypes.contains("amount"))
        XCTAssertTrue(changeTypes.contains("merchant"))
        XCTAssertTrue(changeTypes.contains("paymentMethod"))
    }
    
    // MARK: - Template Update Choice Tests
    
    @MainActor func testShouldShowTemplateUpdateChoiceWithAlwaysAsk() {
        userSettingsService.setTemplateUpdateBehavior(.alwaysAsk)
        
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make a change
        viewModel.amount = "100.00"
        
        XCTAssertTrue(viewModel.shouldShowTemplateUpdateChoice())
    }
    
    @MainActor func testShouldNotShowTemplateUpdateChoiceWithAlwaysUpdateTemplate() {
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateTemplate)
        
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make a change
        viewModel.amount = "100.00"
        
        XCTAssertFalse(viewModel.shouldShowTemplateUpdateChoice())
        XCTAssertEqual(viewModel.templateUpdateChoice, .updateTemplate)
    }
    
    @MainActor func testShouldNotShowTemplateUpdateChoiceWithAlwaysUpdateExpenseOnly() {
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateExpenseOnly)
        
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make a change
        viewModel.amount = "100.00"
        
        XCTAssertFalse(viewModel.shouldShowTemplateUpdateChoice())
        XCTAssertEqual(viewModel.templateUpdateChoice, .updateExpenseOnly)
    }
    
    @MainActor func testHandleTemplateUpdateChoiceUpdateTemplate() {
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make changes and handle choice
        viewModel.amount = "100.00"
        viewModel.pendingTemplateChanges = viewModel.detectSignificantChanges()
        
        viewModel.handleTemplateUpdateChoice(.updateTemplate)
        
        XCTAssertEqual(viewModel.templateUpdateChoice, .updateTemplate)
        XCTAssertFalse(viewModel.showingTemplateUpdateChoice)
    }
    
    @MainActor func testHandleTemplateUpdateChoiceUpdateExpenseOnly() {
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make changes and handle choice
        viewModel.amount = "100.00"
        viewModel.pendingTemplateChanges = viewModel.detectSignificantChanges()
        
        viewModel.handleTemplateUpdateChoice(.updateExpenseOnly)
        
        XCTAssertEqual(viewModel.templateUpdateChoice, .updateExpenseOnly)
        XCTAssertFalse(viewModel.showingTemplateUpdateChoice)
    }
    
    @MainActor func testHandleTemplateUpdateChoiceCancel() {
        let (expense, _) = createExpenseWithTemplate()
        viewModel = ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Store original values
        let originalAmount = viewModel.amount
        let originalMerchant = viewModel.merchant
        
        // Make changes
        viewModel.amount = "100.00"
        viewModel.merchant = "New Merchant"
        
        viewModel.handleTemplateUpdateChoice(.cancel)
        
        // Should reset to original values
        XCTAssertEqual(viewModel.amount, originalAmount)
        XCTAssertEqual(viewModel.merchant, originalMerchant)
        XCTAssertFalse(viewModel.showingTemplateUpdateChoice)
    }
    
    // MARK: - Template Synchronization Tests
    
    @MainActor func testUpdateTemplateFromExpenseChanges() async throws {
        let (expense, template) = createExpenseWithTemplate()
        
        // Modify expense
        expense.amount = NSDecimalNumber(value: 100.00)
        expense.merchant = "Updated Merchant"
        
        // Get changes and update template
        let changes = recurringExpenseService.getExpenseTemplateChanges(expense)
        try recurringExpenseService.updateTemplateFromExpense(template, with: changes)
        
        // Verify template was updated
        XCTAssertEqual(template.amount, NSDecimalNumber(value: 100.00))
        XCTAssertEqual(template.merchant, "Updated Merchant")
    }
    
    @MainActor func testSaveExpenseWithTemplateUpdate() async throws {
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateTemplate)
        
        let (expense, template) = createExpenseWithTemplate()
        viewModel = await ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Make changes
        viewModel.amount = "100.00"
        viewModel.merchant = "Updated Merchant"
        
        // Save with template update
        try await viewModel.saveExpenseWithChoice()
        
        // Verify both expense and template were updated
        XCTAssertEqual(expense.amount, NSDecimalNumber(value: 100.00))
        XCTAssertEqual(expense.merchant, "Updated Merchant")
        XCTAssertEqual(template.amount, NSDecimalNumber(value: 100.00))
        XCTAssertEqual(template.merchant, "Updated Merchant")
    }
    
    @MainActor func testSaveExpenseWithoutTemplateUpdate() async throws {
        userSettingsService.setTemplateUpdateBehavior(.alwaysUpdateExpenseOnly)
        
        let (expense, template) = createExpenseWithTemplate()
        viewModel = await ExpenseEditViewModel(context: testContext, expense: expense)
        
        // Store original template values
        let originalTemplateAmount = template.amount
        let originalTemplateMerchant = template.merchant
        
        // Make changes
        viewModel.amount = "100.00"
        viewModel.merchant = "Updated Merchant"
        
        // Save without template update
        try await viewModel.saveExpenseWithChoice()
        
        // Verify expense was updated but template was not
        XCTAssertEqual(expense.amount, NSDecimalNumber(value: 100.00))
        XCTAssertEqual(expense.merchant, "Updated Merchant")
        XCTAssertEqual(template.amount, originalTemplateAmount)
        XCTAssertEqual(template.merchant, originalTemplateMerchant)
    }
    
    // MARK: - Helper Methods
    
    private func createExpenseWithTemplate() -> (Expense, RecurringExpense) {
        let category = createTestCategory()
        
        // Create recurring template
        let template = recurringExpenseService.createRecurringExpense(
            amount: NSDecimalNumber(value: 50.00),
            currencyCode: "USD",
            merchant: "Test Merchant",
            notes: "Test notes",
            paymentMethod: "Cash",
            category: category,
            tags: [],
            patternType: .monthly,
            interval: 1,
            dayOfMonth: 15
        )
        
        // Create expense linked to template
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 50.00)
        expense.currencyCode = "USD"
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.notes = "Test notes"
        expense.paymentMethod = "Cash"
        expense.category = category
        expense.recurringTemplate = template
        
        // Add expense to template's generated expenses
        template.addToGeneratedExpenses(expense)
        
        try! testContext.save()
        
        return (expense, template)
    }
    
    private func createTestExpense() -> Expense {
        let category = createTestCategory()
        
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(value: 50.00)
        expense.currencyCode = "USD"
        expense.date = Date()
        expense.merchant = "Test Merchant"
        expense.category = category
        
        try! testContext.save()
        
        return expense
    }
    
    private func createTestCategory(name: String = "Test Category") -> ReceiptScannerExpenseTracker.Category {
        let category = Category(context: testContext)
        category.id = UUID()
        category.name = name
        category.icon = "folder"
        category.colorHex = "#007AFF"
        category.isDefault = false
        
        try! testContext.save()
        
        return category
    }
}