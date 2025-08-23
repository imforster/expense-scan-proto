import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - Supporting Types

// MARK: - Extensions

extension DateFormatter {
    func apply(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}

@MainActor
class ExpenseEditViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var date: Date = Date()
    @Published var merchant: String = ""
    @Published var selectedCategory: Category?
    @Published var notes: String = ""
    @Published var paymentMethod: String = ""
    @Published var tags: [Tag] = []
    @Published var expenseItems: [ExpenseItemEdit] = []
    @Published var expenseContexts: Set<ExpenseContext> = []
    @Published var currencyCode: String = ""
    @Published var selectedCurrencyInfo: CurrencyInfo?
    
    // Recurring template detection (read-only)
    @Published var hasRecurringTemplate: Bool = false
    @Published var recurringTemplateInfo: RecurringTemplateInfo?
    
    // Template update choice UI
    @Published var showingTemplateUpdateChoice: Bool = false
    @Published var pendingTemplateChanges: [TemplateChangeType] = []
    @Published var templateUpdateChoice: TemplateUpdateChoice?
    
    // Receipt splitting
    @Published var isReceiptSplitMode: Bool = false
    @Published var receiptSplits: [ReceiptSplit] = []
    @Published var originalReceiptAmount: Decimal = 0
    
    // UI State
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showingCategoryPicker: Bool = false
    @Published var showingTagPicker: Bool = false
    @Published var showingReceiptSplitView: Bool = false
    @Published var showingCurrencyPicker: Bool = false
    
    // Available data
    @Published var availableCategories: [Category] = []
    @Published var availableTags: [Tag] = []
    @Published var suggestedCategories: [Category] = []
    
    private let context: NSManagedObjectContext
    private let categoryService: CategoryServiceProtocol
    private let currencyService = CurrencyService.shared
    private let userSettingsService = UserSettingsService.shared
    private let recurringExpenseService: RecurringExpenseService
    var expense: Expense?
    private var cancellables = Set<AnyCancellable>()
    
    // Store original values for change detection
    private var originalAmount: String = ""
    private var originalMerchant: String = ""
    private var originalCategory: Category?
    private var originalNotes: String = ""
    private var originalPaymentMethod: String = ""
    private var originalCurrencyCode: String = ""
    private var originalTags: [Tag] = []
    
    // Payment method options
    let paymentMethods = ["Cash", "Credit Card", "MasterCard", "Visa", "AMEX","Debit Card", "Check", "Bank Transfer", "Digital Wallet", "Other"]
    
    init(context: NSManagedObjectContext, expense: Expense? = nil, categoryService: CategoryServiceProtocol = CategoryService()) {
        self.context = context
        self.expense = expense
        self.categoryService = categoryService
        self.recurringExpenseService = RecurringExpenseService(context: context)
        
        setupObservers()
        loadInitialData()
        initializeCurrency()
        
        if let expense = expense {
            populateFromExpense(expense)
            storeOriginalValues()
        }
    }
    
    private func setupObservers() {
        // Watch for merchant changes to suggest categories
        $merchant
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] merchantName in
                if !merchantName.isEmpty {
                    Task {
                        await self?.suggestCategoriesForMerchant(merchantName)
                    }
                }
            }
            .store(in: &cancellables)
        
        // Watch for amount changes in split mode
        $receiptSplits
            .sink { [weak self] splits in
                self?.validateReceiptSplits()
            }
            .store(in: &cancellables)
        
        // Watch for currency code changes to update currency info
        $currencyCode
            .sink { [weak self] code in
                self?.updateSelectedCurrencyInfo(code)
            }
            .store(in: &cancellables)
    }
    
    private func initializeCurrency() {
        // Set default currency to user's preferred currency
        currencyCode = currencyService.getPreferredCurrencyCode()
        updateSelectedCurrencyInfo(currencyCode)
    }
    
    private func updateSelectedCurrencyInfo(_ code: String) {
        selectedCurrencyInfo = currencyService.getCurrencyInfo(for: code)
    }
    
    private func loadInitialData() {
        Task {
            do {
                // Clean up any duplicate categories first
                try await categoryService.cleanupDuplicateCategories()
                
                // Then load the clean categories
                availableCategories = try await categoryService.getAllCategories()
                availableTags = try await loadAllTags()
            } catch {
                errorMessage = "Failed to load data: \(error.localizedDescription)"
            }
        }
    }
    
    private func populateFromExpense(_ expense: Expense) {
        amount = expense.amount.stringValue
        date = expense.date
        merchant = expense.merchant
        selectedCategory = expense.category
        notes = expense.notes ?? ""
        paymentMethod = expense.paymentMethod ?? ""
        currencyCode = expense.currencyCode
        
        // Extract expense contexts from notes
        let (extractedContexts, cleanedNotes) = extractExpenseContexts(from: notes)
        expenseContexts = extractedContexts
        notes = cleanedNotes
        
        // Clean up any extra whitespace
        notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Load tags
        if let expenseTags = expense.tags?.allObjects as? [Tag] {
            tags = expenseTags
        }
        
        // Load expense items
        if let items = expense.items?.allObjects as? [ExpenseItem] {
            expenseItems = items.map { item in
                ExpenseItemEdit(
                    id: item.id,
                    name: item.name,
                    amount: item.amount.stringValue,
                    category: item.category
                )
            }
        }
        
        // Check if this expense can be split (has receipt with items)
        if let receipt = expense.receipt,
           let receiptItems = receipt.items?.allObjects as? [ReceiptItem],
           !receiptItems.isEmpty {
            originalReceiptAmount = receipt.totalAmount.decimalValue
            setupReceiptSplitsFromItems(receiptItems)
        }
        
        // Detect recurring template relationship
        detectRecurringTemplateRelationship(expense)
    }
    
    private func setupReceiptSplitsFromItems(_ receiptItems: [ReceiptItem]) {
        receiptSplits = receiptItems.map { item in
            ReceiptSplit(
                id: UUID(),
                name: item.name,
                amount: item.totalPrice.stringValue,
                category: nil,
                isSelected: false
            )
        }
    }
    
    // MARK: - Category Suggestions
    
    private func suggestCategoriesForMerchant(_ merchantName: String) async {
        do {
            if let suggestedCategory = try await categoryService.suggestCategory(for: merchantName, amount: Decimal(string: amount)) {
                await MainActor.run {
                    suggestedCategories = [suggestedCategory]
                }
            }
        } catch {
            await MainActor.run {
                print("Failed to suggest category: \(error)")
            }
        }
    }
    

    
    // MARK: - Recurring Template Detection
    
    private func detectRecurringTemplateRelationship(_ expense: Expense) {
        guard let recurringTemplate = expense.recurringTemplate else {
            hasRecurringTemplate = false
            recurringTemplateInfo = nil
            return
        }
        
        hasRecurringTemplate = true
        
        // Build template info
        let patternDescription = recurringTemplate.pattern?.description ?? "Unknown pattern"
        let nextDueDate = recurringTemplate.pattern?.nextDueDate
        let totalGenerated = recurringTemplate.safeGeneratedExpenses.count
        
        recurringTemplateInfo = RecurringTemplateInfo(
            templateId: recurringTemplate.id,
            patternDescription: patternDescription,
            nextDueDate: nextDueDate,
            isActive: recurringTemplate.isActive,
            lastGeneratedDate: recurringTemplate.lastGeneratedDate,
            totalGeneratedExpenses: totalGenerated
        )
    }
    
    func validateTemplateRelationship() -> Bool {
        guard hasRecurringTemplate,
              let templateInfo = recurringTemplateInfo,
              expense != nil else {
            return true // No template relationship to validate
        }
        
        // Basic validation - ensure the expense is still linked to an active template
        return templateInfo.isActive
    }
    
    // MARK: - Template Update Detection
    
    /// Store original values for change detection
    private func storeOriginalValues() {
        originalAmount = amount
        originalMerchant = merchant
        originalCategory = selectedCategory
        originalNotes = notes
        originalPaymentMethod = paymentMethod
        originalCurrencyCode = currencyCode
        originalTags = tags
    }
    
    /// Detect significant changes that should trigger template update choice
    func detectSignificantChanges() -> [TemplateChangeType] {
        guard hasRecurringTemplate else { return [] }
        
        var changes: [TemplateChangeType] = []
        
        // Check amount changes
        if amount != originalAmount {
            let originalDecimal = NSDecimalNumber(string: originalAmount.isEmpty ? "0" : originalAmount)
            let newDecimal = NSDecimalNumber(string: amount.isEmpty ? "0" : amount)
            changes.append(.amount(from: originalDecimal, to: newDecimal))
        }
        
        // Check merchant changes
        if merchant != originalMerchant {
            changes.append(.merchant(from: originalMerchant, to: merchant))
        }
        
        // Check category changes
        if selectedCategory?.id != originalCategory?.id {
            changes.append(.category(from: originalCategory, to: selectedCategory))
        }
        
        // Check notes changes (only if significant)
        let cleanedOriginalNotes = cleanNotesForComparison(originalNotes)
        let cleanedCurrentNotes = cleanNotesForComparison(notes)
        if cleanedOriginalNotes != cleanedCurrentNotes {
            changes.append(.notes(from: originalNotes, to: notes))
        }
        
        // Check payment method changes
        if paymentMethod != originalPaymentMethod {
            changes.append(.paymentMethod(from: originalPaymentMethod, to: paymentMethod))
        }
        
        // Check currency changes
        if currencyCode != originalCurrencyCode {
            changes.append(.currency(from: originalCurrencyCode, to: currencyCode))
        }
        
        // Check tag changes
        let originalTagIds = Set(originalTags.map { $0.id })
        let currentTagIds = Set(tags.map { $0.id })
        if originalTagIds != currentTagIds {
            changes.append(.tags(from: originalTags, to: tags))
        }
        
        return changes
    }
    
    /// Clean notes for comparison (remove context tags and whitespace)
    private func cleanNotesForComparison(_ notes: String) -> String {
        var cleaned = notes
        
        // Remove context tags
        let contextPattern = "\\[Context: ([^\\]]+)\\]"
        if let regex = try? NSRegularExpression(pattern: contextPattern) {
            cleaned = regex.stringByReplacingMatches(
                in: cleaned,
                range: NSRange(location: 0, length: cleaned.count),
                withTemplate: ""
            )
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Check if changes are significant enough to warrant template update choice
    func hasSignificantChanges() -> Bool {
        let changes = detectSignificantChanges()
        return !changes.isEmpty && hasRecurringTemplate
    }
    
    /// Handle template update choice from user
    func handleTemplateUpdateChoice(_ choice: TemplateUpdateChoice) {
        templateUpdateChoice = choice
        
        switch choice {
        case .updateTemplate:
            // Will be handled in saveExpense
            break
        case .updateExpenseOnly:
            // Will be handled in saveExpense
            break
        case .cancel:
            // Reset to original values
            resetToOriginalValues()
        }
        
        showingTemplateUpdateChoice = false
    }
    
    /// Reset fields to original values
    private func resetToOriginalValues() {
        amount = originalAmount
        merchant = originalMerchant
        selectedCategory = originalCategory
        notes = originalNotes
        paymentMethod = originalPaymentMethod
        currencyCode = originalCurrencyCode
        tags = originalTags
    }
    
    /// Update user preference for template updates
    func updateTemplateUpdatePreference(_ behavior: TemplateUpdateBehavior) {
        userSettingsService.setTemplateUpdateBehavior(behavior)
    }
    
    /// Check if we should show template update choice dialog
    func shouldShowTemplateUpdateChoice() -> Bool {
        guard hasSignificantChanges() else { return false }
        
        let behavior = userSettingsService.getTemplateUpdateBehavior()
        
        switch behavior {
        case .alwaysAsk:
            return true
        case .alwaysUpdateTemplate:
            templateUpdateChoice = .updateTemplate
            return false
        case .alwaysUpdateExpenseOnly:
            templateUpdateChoice = .updateExpenseOnly
            return false
        }
    }
    

    
    // MARK: - Receipt Splitting
    
    func enableReceiptSplitMode() {
        isReceiptSplitMode = true
        showingReceiptSplitView = true
    }
    
    func addReceiptSplit() {
        let newSplit = ReceiptSplit(
            id: UUID(),
            name: "",
            amount: "0.00",
            category: nil,
            isSelected: false
        )
        receiptSplits.append(newSplit)
    }
    
    func removeReceiptSplit(at index: Int) {
        guard index < receiptSplits.count else { return }
        receiptSplits.remove(at: index)
    }
    
    func validateReceiptSplits() {
        _ = receiptSplits.reduce(Decimal.zero) { total, split in
            total + (Decimal(string: split.amount) ?? 0)
        }
        
        // Update UI to show if splits match original amount
        // This could be used to show validation messages
    }
    
    func selectAllSplits() {
        for i in 0..<receiptSplits.count {
            receiptSplits[i].isSelected = true
        }
    }
    
    func deselectAllSplits() {
        for i in 0..<receiptSplits.count {
            receiptSplits[i].isSelected = false
        }
    }
    
    func distributeAmountEvenly() {
        let selectedSplits = receiptSplits.filter { $0.isSelected }
        guard !selectedSplits.isEmpty else { return }
        
        let splitCount = selectedSplits.count
        let amountPerSplit = originalReceiptAmount / Decimal(splitCount)
        let formattedAmount = String(format: "%.2f", NSDecimalNumber(decimal: amountPerSplit).doubleValue)
        
        // Update amounts for selected splits
        for i in 0..<receiptSplits.count {
            if receiptSplits[i].isSelected {
                receiptSplits[i].amount = formattedAmount
            }
        }
    }
    
    func suggestCategoriesForSplits() {
        Task {
            for i in 0..<receiptSplits.count {
                if receiptSplits[i].isSelected && receiptSplits[i].category == nil {
                    // Try to suggest a category based on the item name
                    if let suggestedCategory = try? await categoryService.suggestCategory(for: receiptSplits[i].name) {
                        await MainActor.run {
                            receiptSplits[i].category = suggestedCategory
                        }
                    }
                }
            }
        }
    }
    
    func createExpensesFromSplits() async throws -> [Expense] {
        let selectedSplits = receiptSplits.filter { $0.isSelected }
        guard !selectedSplits.isEmpty else {
            throw ExpenseEditError.noSplitsSelected
        }
        
        var createdExpenses: [Expense] = []
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    for split in selectedSplits {
                        let newExpense = Expense(context: self.context)
                        newExpense.id = UUID()
                        newExpense.amount = NSDecimalNumber(string: split.amount)
                        newExpense.date = self.date
                        newExpense.merchant = self.merchant
                        
                        // Fix for the context issue - fetch the category in the same context
                        if let splitCategory = split.category {
                            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "id == %@", splitCategory.id as CVarArg)
                            fetchRequest.fetchLimit = 1
                            
                            do {
                                let categories = try self.context.fetch(fetchRequest)
                                if let existingCategory = categories.first {
                                    newExpense.category = existingCategory
                                } else {
                                    // If category doesn't exist in this context, create a new one with the same ID
                                    let newCategory = Category(context: self.context)
                                    newCategory.id = splitCategory.id
                                    newCategory.name = splitCategory.name
                                    newCategory.icon = splitCategory.icon
                                    newCategory.colorHex = splitCategory.colorHex
                                    newCategory.isDefault = splitCategory.isDefault
                                    newExpense.category = newCategory
                                }
                            } catch {
                                print("Error fetching category for split: \(error)")
                            }
                        }
                        
                        // Add more detailed notes for the split
                        var splitNotes = "Split from receipt: \(split.name)"
                        
                        // Add original receipt info
                        if let receipt = self.expense?.receipt {
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateStyle = .medium
                            dateFormatter.timeStyle = .none
                            
                            splitNotes += "\n\nOriginal Receipt:"
                            splitNotes += "\nDate: \(dateFormatter.string(from: receipt.date))"
                            splitNotes += "\nMerchant: \(receipt.safeMerchantName)"
                            splitNotes += "\nTotal: \(receipt.formattedTotalAmount())"
                        }
                        
                        newExpense.notes = splitNotes
                        newExpense.paymentMethod = self.paymentMethod
                        newExpense.isRecurring = false
                        
                        // Fix for the context issue - fetch the receipt in the same context
                        if let originalReceipt = self.expense?.receipt {
                            let fetchRequest: NSFetchRequest<Receipt> = Receipt.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "id == %@", originalReceipt.id as CVarArg)
                            fetchRequest.fetchLimit = 1
                            
                            do {
                                let receipts = try self.context.fetch(fetchRequest)
                                if let existingReceipt = receipts.first {
                                    newExpense.receipt = existingReceipt
                                } else {
                                    // If receipt doesn't exist in this context, create a new one with the same ID
                                    let newReceipt = Receipt(context: self.context)
                                    newReceipt.id = originalReceipt.id
                                    newReceipt.date = originalReceipt.date
                                    newReceipt.merchantName = originalReceipt.merchantName
                                    newReceipt.totalAmount = originalReceipt.totalAmount
                                    newReceipt.imageURL = originalReceipt.imageURL
                                    newReceipt.dateProcessed = originalReceipt.dateProcessed
                                    newExpense.receipt = newReceipt
                                }
                            } catch {
                                print("Error fetching receipt in expense context: \(error)")
                            }
                        }
                        
                        // Copy any expense contexts
                        if !self.expenseContexts.isEmpty {
                            let contextNames = self.expenseContexts.map { $0.rawValue }.joined(separator: ", ")
                            newExpense.notes = (newExpense.notes ?? "") + "\n\n[Context: \(contextNames)]"
                        }
                        
                        createdExpenses.append(newExpense)
                    }
                    
                    try self.context.save()
                    continuation.resume(returning: createdExpenses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Tag Management
    
    func addTag(_ tagName: String) async throws {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        // Check if tag already exists
        if let existingTag = availableTags.first(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            if !tags.contains(existingTag) {
                tags.append(existingTag)
            }
            return
        }
        
        // Create new tag
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let newTag = Tag(context: self.context)
                newTag.id = UUID()
                newTag.name = trimmedName
                
                do {
                    try self.context.save()
                    
                    DispatchQueue.main.async {
                        self.availableTags.append(newTag)
                        self.tags.append(newTag)
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func removeTag(_ tag: Tag) {
        tags.removeAll { $0.id == tag.id }
    }
    
    // MARK: - Expense Items Management
    
    func addExpenseItem() {
        let newItem = ExpenseItemEdit(
            id: UUID(),
            name: "",
            amount: "0.00",
            category: nil
        )
        expenseItems.append(newItem)
    }
    
    func removeExpenseItem(at index: Int) {
        guard index < expenseItems.count else { return }
        expenseItems.remove(at: index)
    }
    
    // MARK: - Save Expense
    
    func saveExpense() async throws {
        guard validateInput() else {
            throw ExpenseEditError.invalidInput
        }
        
        // Check if we need to show template update choice
        if shouldShowTemplateUpdateChoice() {
            pendingTemplateChanges = detectSignificantChanges()
            showingTemplateUpdateChoice = true
            return // Don't save yet, wait for user choice
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let existingExpense = expense {
                try await updateExpense(existingExpense)
            } else {
                try await createNewExpense()
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    /// Save expense after template update choice has been made
    func saveExpenseWithChoice() async throws {
        guard validateInput() else {
            throw ExpenseEditError.invalidInput
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let existingExpense = expense {
                try await updateExpenseWithTemplateHandling(existingExpense)
            } else {
                try await createNewExpense()
            }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            throw error
        }
    }
    
    private func createNewExpense() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let newExpense = Expense(context: self.context)
                    newExpense.id = UUID()
                    
                    self.populateExpense(newExpense)
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func updateExpense(_ expense: Expense) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    self.populateExpense(expense)
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Update expense with template handling based on user choice
    private func updateExpenseWithTemplateHandling(_ expense: Expense) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Create template snapshot for rollback if needed
                var templateSnapshot: [String: Any]?
                if let template = expense.recurringTemplate {
                    templateSnapshot = self.recurringExpenseService.createTemplateSnapshot(template)
                }
                
                do {
                    
                    // Update the expense first
                    self.populateExpense(expense)
                    
                    // Handle template updates based on user choice
                    if let choice = self.templateUpdateChoice,
                       let template = expense.recurringTemplate,
                       !self.pendingTemplateChanges.isEmpty {
                        
                        switch choice {
                        case .updateTemplate:
                            // Validate changes before applying
                            if self.recurringExpenseService.validateTemplateSynchronization(template, changes: self.pendingTemplateChanges) {
                                try self.recurringExpenseService.updateTemplateFromExpense(template, with: self.pendingTemplateChanges)
                            } else {
                                // Rollback if validation fails
                                if let snapshot = templateSnapshot {
                                    try self.recurringExpenseService.rollbackTemplateSynchronization(template, originalValues: snapshot)
                                }
                                throw ExpenseEditError.templateSynchronizationFailed
                            }
                            
                        case .updateExpenseOnly:
                            // Keep the link but don't update the template
                            // This allows the user to diverge this specific expense from the template
                            break
                            
                        case .cancel:
                            // This should not happen as we reset values in handleTemplateUpdateChoice
                            break
                        }
                    }
                    
                    try self.context.save()
                    
                    // Clear the choice and changes after successful save
                    DispatchQueue.main.async {
                        self.templateUpdateChoice = nil
                        self.pendingTemplateChanges = []
                        // Update original values for future change detection
                        self.storeOriginalValues()
                    }
                    
                    continuation.resume()
                } catch {
                    // Rollback template changes if save fails
                    if let template = expense.recurringTemplate,
                       let snapshot = templateSnapshot {
                        try? self.recurringExpenseService.rollbackTemplateSynchronization(template, originalValues: snapshot)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Made internal for testing purposes
    func populateExpense(_ expense: Expense) {
        expense.amount = NSDecimalNumber(string: amount)
        expense.date = date
        expense.merchant = merchant
        expense.currencyCode = currencyCode
        
        // Handle category assignment with proper context safety
        if let selectedCategory = selectedCategory {
            // Check if the selected category is already in the same context as the expense
            if selectedCategory.managedObjectContext == expense.managedObjectContext {
                // Same context, safe to assign directly
                expense.category = selectedCategory
            } else {
                // Different contexts, need to fetch the category in the expense's context
                let expenseContext = expense.managedObjectContext!
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", selectedCategory.id as CVarArg)
                fetchRequest.fetchLimit = 1
                
                do {
                    let categories = try expenseContext.fetch(fetchRequest)
                    if let existingCategory = categories.first {
                        expense.category = existingCategory
                    } else {
                        // If category doesn't exist in this context, create a new one with the same ID
                        let newCategory = Category(context: expenseContext)
                        newCategory.id = selectedCategory.id
                        newCategory.name = selectedCategory.name
                        newCategory.icon = selectedCategory.icon
                        newCategory.colorHex = selectedCategory.colorHex
                        newCategory.isDefault = selectedCategory.isDefault
                        expense.category = newCategory
                    }
                } catch {
                    print("Error fetching category in expense context: \(error)")
                    // If we can't fetch the category, don't set it
                    expense.category = nil
                }
            }
        } else {
            expense.category = nil
        }
        
        expense.paymentMethod = paymentMethod.isEmpty ? nil : paymentMethod
        
        // Start with the user's notes
        var notesText = notes
        
        // Add expense contexts to notes
        notesText = addExpenseContextsToNotes(notesText)
        
        // Save the final notes
        expense.notes = notesText.isEmpty ? nil : notesText
        
        // Update tags
        expense.removeFromTags(expense.tags ?? NSSet())
        for tag in tags {
            // Fetch the tag in the expense's context
            let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", tag.id as CVarArg)
            fetchRequest.fetchLimit = 1
            
            do {
                let fetchedTags = try context.fetch(fetchRequest)
                if let fetchedTag = fetchedTags.first {
                    expense.addToTags(fetchedTag)
                } else {
                    // If tag doesn't exist in this context, create a new one with the same ID
                    let newTag = Tag(context: context)
                    newTag.id = tag.id
                    newTag.name = tag.name
                    expense.addToTags(newTag)
                }
            } catch {
                print("Error fetching tag in expense context: \(error)")
            }
        }
        
        // Update expense items
        if let existingItems = expense.items {
            expense.removeFromItems(existingItems)
        }
        
        for itemEdit in expenseItems {
            let expenseItem = ExpenseItem(context: context)
            expenseItem.id = itemEdit.id
            expenseItem.name = itemEdit.name
            expenseItem.amount = NSDecimalNumber(string: itemEdit.amount)
            
            // If the item has a category, fetch it in the same context
            if let itemCategory = itemEdit.category {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", itemCategory.id as CVarArg)
                fetchRequest.fetchLimit = 1
                
                do {
                    let categories = try context.fetch(fetchRequest)
                    if let existingCategory = categories.first {
                        expenseItem.category = existingCategory
                    } else {
                        // If category doesn't exist in this context, create a new one with the same ID
                        let newCategory = Category(context: context)
                        newCategory.id = itemCategory.id
                        newCategory.name = itemCategory.name
                        newCategory.icon = itemCategory.icon
                        newCategory.colorHex = itemCategory.colorHex
                        newCategory.isDefault = itemCategory.isDefault
                        expenseItem.category = newCategory
                    }
                } catch {
                    print("Error fetching category for expense item: \(error)")
                }
            }
            
            expense.addToItems(expenseItem)
        }
    }
    
    private func validateInput() -> Bool {
        guard !amount.isEmpty,
              Decimal(string: amount) != nil,
              !merchant.isEmpty else {
            return false
        }
        
        return true
    }
    
    // MARK: - Expense Context Methods
    
    func toggleExpenseContext(_ context: ExpenseContext) {
        if expenseContexts.contains(context) {
            expenseContexts.remove(context)
        } else {
            expenseContexts.insert(context)
        }
    }
    
    private func extractExpenseContexts(from notes: String) -> (Set<ExpenseContext>, String) {
        var extractedContexts: Set<ExpenseContext> = []
        var cleanedNotes = notes
        
        // Extract context tags from notes using regex
        let contextPattern = "\\[Context: ([^\\]]+)\\]"
        if let regex = try? NSRegularExpression(pattern: contextPattern) {
            let nsString = notes as NSString
            let matches = regex.matches(in: notes, range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let contextString = nsString.substring(with: match.range(at: 1))
                let contexts = contextString.components(separatedBy: ", ")
                
                for contextName in contexts {
                    if let context = ExpenseContext.allCases.first(where: { $0.rawValue == contextName }) {
                        extractedContexts.insert(context)
                    }
                }
                
                // Remove the context tag from notes
                cleanedNotes = cleanedNotes.replacingOccurrences(
                    of: "\\[Context: \(contextString)\\]",
                    with: "",
                    options: .regularExpression
                )
            }
        }
        
        // Clean up any extra whitespace
        cleanedNotes = cleanedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (extractedContexts, cleanedNotes)
    }
    
    private func addExpenseContextsToNotes(_ notes: String) -> String {
        guard !expenseContexts.isEmpty else { return notes }
        
        var updatedNotes = notes
        
        // Add context tag if not already present
        if !updatedNotes.contains("[Context:") {
            let contextNames = expenseContexts.map { $0.rawValue }.joined(separator: ", ")
            let contextTag = "[Context: \(contextNames)]"
            
            if updatedNotes.isEmpty {
                updatedNotes = contextTag
            } else {
                updatedNotes += "\n\n" + contextTag
            }
        }
        
        return updatedNotes
    }
    
    // MARK: - Helper Methods
    
    private func loadAllTags() async throws -> [Tag] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
                
                do {
                    let tags = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: tags)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    var isValid: Bool {
        !amount.isEmpty && 
        Decimal(string: amount) != nil && 
        !merchant.isEmpty
    }
    
    var totalExpenseItemsAmount: Decimal {
        expenseItems.reduce(Decimal.zero) { total, item in
            total + (Decimal(string: item.amount) ?? 0)
        }
    }
    

    
    var totalReceiptSplitsAmount: Decimal {
        receiptSplits.reduce(Decimal.zero) { total, split in
            total + (Decimal(string: split.amount) ?? 0)
        }
    }
}

// MARK: - Supporting Models
// Now using external model definitions from Models/ExpenseItemEdit.swift and Models/ReceiptSplit.swift



// MARK: - Errors

enum ExpenseEditError: LocalizedError {
    case invalidInput
    case noSplitsSelected
    case splitAmountMismatch
    case templateSynchronizationFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Please fill in all required fields with valid values."
        case .noSplitsSelected:
            return "Please select at least one split to create expenses."
        case .splitAmountMismatch:
            return "Split amounts don't match the original receipt total."
        case .templateSynchronizationFailed:
            return "Failed to synchronize changes with recurring template. Changes have been reverted."
        }
    }
}
