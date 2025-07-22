import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class ExpenseEditViewModel: ObservableObject {
    @Published var amount: String = ""
    @Published var date: Date = Date()
    @Published var merchant: String = ""
    @Published var selectedCategory: Category?
    @Published var notes: String = ""
    @Published var paymentMethod: String = ""
    @Published var isRecurring: Bool = false
    @Published var recurringPattern: RecurringPattern = .monthly
    @Published var nextExpectedDate: Date? = nil
    @Published var tags: [Tag] = []
    @Published var expenseItems: [ExpenseItemEdit] = []
    
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
    
    // Available data
    @Published var availableCategories: [Category] = []
    @Published var availableTags: [Tag] = []
    @Published var suggestedCategories: [Category] = []
    
    private let context: NSManagedObjectContext
    private let categoryService: CategoryServiceProtocol
    var expense: Expense?
    private var cancellables = Set<AnyCancellable>()
    
    // Payment method options
    let paymentMethods = ["Cash", "Credit Card", "Debit Card", "Check", "Bank Transfer", "Digital Wallet", "Other"]
    
    init(context: NSManagedObjectContext, expense: Expense? = nil, categoryService: CategoryServiceProtocol = CategoryService()) {
        self.context = context
        self.expense = expense
        self.categoryService = categoryService
        
        setupObservers()
        loadInitialData()
        
        if let expense = expense {
            populateFromExpense(expense)
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
    }
    
    private func loadInitialData() {
        Task {
            do {
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
        isRecurring = expense.isRecurring
        
        // Extract recurring pattern information from notes if present
        if isRecurring {
            // Extract pattern
            if let patternRange = notes.range(of: "\\[Recurring: ([^\\]]+)\\]", options: .regularExpression) {
                let patternString = String(notes[patternRange])
                    .replacingOccurrences(of: "[Recurring: ", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                if let pattern = RecurringPattern.allCases.first(where: { $0.rawValue == patternString }) {
                    recurringPattern = pattern
                }
                
                // Clean up notes by removing the pattern info
                notes = notes.replacingOccurrences(of: "\\[Recurring: [^\\]]+\\]", with: "", options: .regularExpression)
            }
            
            // Extract next date
            if let nextDateRange = notes.range(of: "\\[Next: ([^\\]]+)\\]", options: .regularExpression) {
                let nextDateString = String(notes[nextDateRange])
                    .replacingOccurrences(of: "[Next: ", with: "")
                    .replacingOccurrences(of: "]", with: "")
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                
                if let parsedDate = dateFormatter.date(from: nextDateString) {
                    nextExpectedDate = parsedDate
                }
                
                // Clean up notes by removing the next date info
                notes = notes.replacingOccurrences(of: "\\[Next: [^\\]]+\\]", with: "", options: .regularExpression)
            }
            
            // Clean up any extra whitespace
            notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
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
    
    // MARK: - Recurring Expense Detection
    
    func detectRecurringExpense() async {
        guard !merchant.isEmpty else { return }
        
        do {
            let result = try await analyzeRecurringPattern()
            await MainActor.run {
                if result.isRecurring && !isRecurring {
                    // Show suggestion to mark as recurring
                    isRecurring = true
                    recurringPattern = result.pattern
                    nextExpectedDate = result.nextExpectedDate
                }
            }
        } catch {
            print("Failed to detect recurring expense: \(error)")
        }
    }
    
    private func analyzeRecurringPattern() async throws -> RecurringExpenseAnalysis {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Look for similar expenses from the same merchant
                let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "merchant == %@", self.merchant)
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                fetchRequest.fetchLimit = 10
                
                do {
                    let similarExpenses = try self.context.fetch(fetchRequest)
                    
                    // Check if there are at least 3 similar expenses
                    if similarExpenses.count >= 3 {
                        // Check for regular intervals (monthly pattern)
                        let dates = similarExpenses.map { $0.date }.sorted()
                        let intervals = zip(dates, dates.dropFirst()).map { Calendar.current.dateComponents([.day], from: $0, to: $1).day ?? 0 }
                        
                        // Check for different patterns
                        let weeklyIntervals = intervals.filter { abs($0 - 7) <= 2 }
                        let biweeklyIntervals = intervals.filter { abs($0 - 14) <= 3 }
                        let monthlyIntervals = intervals.filter { abs($0 - 30) <= 5 }
                        let quarterlyIntervals = intervals.filter { abs($0 - 90) <= 10 }
                        
                        // Determine the most likely pattern
                        var pattern: RecurringPattern = .none
                        var confidence: Float = 0.0
                        
                        if weeklyIntervals.count >= intervals.count / 2 {
                            pattern = .weekly
                            confidence = Float(weeklyIntervals.count) / Float(intervals.count)
                        } else if biweeklyIntervals.count >= intervals.count / 2 {
                            pattern = .biweekly
                            confidence = Float(biweeklyIntervals.count) / Float(intervals.count)
                        } else if monthlyIntervals.count >= intervals.count / 2 {
                            pattern = .monthly
                            confidence = Float(monthlyIntervals.count) / Float(intervals.count)
                        } else if quarterlyIntervals.count >= intervals.count / 2 {
                            pattern = .quarterly
                            confidence = Float(quarterlyIntervals.count) / Float(intervals.count)
                        }
                        
                        // Check for amount consistency
                        let amounts = similarExpenses.map { $0.amount.decimalValue }
                        let averageAmount = amounts.reduce(Decimal.zero, +) / Decimal(amounts.count)
                        let amountVariance = amounts.map { abs($0 - averageAmount) / averageAmount }
                        let isAmountConsistent = amountVariance.filter { $0 < 0.1 }.count >= amounts.count / 2
                        
                        // Calculate next expected date
                        var nextDate: Date? = nil
                        if pattern != .none {
                            let lastDate = dates.last ?? Date()
                            switch pattern {
                            case .weekly:
                                nextDate = Calendar.current.date(byAdding: .day, value: 7, to: lastDate)
                            case .biweekly:
                                nextDate = Calendar.current.date(byAdding: .day, value: 14, to: lastDate)
                            case .monthly:
                                nextDate = Calendar.current.date(byAdding: .month, value: 1, to: lastDate)
                            case .quarterly:
                                nextDate = Calendar.current.date(byAdding: .month, value: 3, to: lastDate)
                            case .none:
                                nextDate = nil
                            }
                        }
                        
                        let analysis = RecurringExpenseAnalysis(
                            isRecurring: pattern != .none,
                            pattern: pattern,
                            confidence: confidence,
                            isAmountConsistent: isAmountConsistent,
                            averageAmount: averageAmount,
                            nextExpectedDate: nextDate,
                            similarExpensesCount: similarExpenses.count
                        )
                        
                        continuation.resume(returning: analysis)
                    } else {
                        continuation.resume(returning: RecurringExpenseAnalysis(
                            isRecurring: false,
                            pattern: .none,
                            confidence: 0.0,
                            isAmountConsistent: false,
                            averageAmount: Decimal.zero,
                            nextExpectedDate: nil,
                            similarExpensesCount: similarExpenses.count
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
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
        let totalSplitAmount = receiptSplits.reduce(Decimal.zero) { total, split in
            total + (Decimal(string: split.amount) ?? 0)
        }
        
        // Update UI to show if splits match original amount
        // This could be used to show validation messages
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
                        newExpense.category = split.category
                        newExpense.notes = "Split from receipt: \(split.name)"
                        newExpense.paymentMethod = self.paymentMethod
                        newExpense.isRecurring = false
                        newExpense.receipt = self.expense?.receipt
                        
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
    
    private func populateExpense(_ expense: Expense) {
        expense.amount = NSDecimalNumber(string: amount)
        expense.date = date
        expense.merchant = merchant
        expense.category = selectedCategory
        expense.notes = notes.isEmpty ? nil : notes
        expense.paymentMethod = paymentMethod.isEmpty ? nil : paymentMethod
        expense.isRecurring = isRecurring
        
        // Store recurring pattern information in notes if recurring
        if isRecurring {
            var notesText = notes
            
            // Add recurring pattern info if not already present
            if !notesText.contains("[Recurring: ") {
                let patternInfo = "[Recurring: \(recurringPattern.rawValue)]"
                if notesText.isEmpty {
                    notesText = patternInfo
                } else {
                    notesText += "\n\n" + patternInfo
                }
                
                // Add next expected date if available
                if let nextDate = nextExpectedDate {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    notesText += " [Next: \(dateFormatter.string(from: nextDate))]"
                }
                
                expense.notes = notesText
            }
        } else {
            expense.notes = notes.isEmpty ? nil : notes
        }
        
        // Update tags
        expense.removeFromTags(expense.tags ?? NSSet())
        for tag in tags {
            expense.addToTags(tag)
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
            expenseItem.category = itemEdit.category
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

struct ExpenseItemEdit: Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var category: Category?
}

struct ReceiptSplit: Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var category: Category?
    var isSelected: Bool
}

// MARK: - Recurring Expense Models

enum RecurringPattern: String, CaseIterable {
    case none = "None"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
}

struct RecurringExpenseAnalysis {
    let isRecurring: Bool
    let pattern: RecurringPattern
    let confidence: Float
    let isAmountConsistent: Bool
    let averageAmount: Decimal
    let nextExpectedDate: Date?
    let similarExpensesCount: Int
}

// MARK: - Errors

enum ExpenseEditError: LocalizedError {
    case invalidInput
    case noSplitsSelected
    case splitAmountMismatch
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Please fill in all required fields with valid values."
        case .noSplitsSelected:
            return "Please select at least one split to create expenses."
        case .splitAmountMismatch:
            return "Split amounts don't match the original receipt total."
        }
    }
}