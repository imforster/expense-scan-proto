import Foundation
import CoreData

/// Enum representing different types of template changes
enum TemplateChangeType {
    case amount(from: NSDecimalNumber, to: NSDecimalNumber)
    case merchant(from: String, to: String)
    case category(from: Category?, to: Category?)
    case notes(from: String?, to: String?)
    case paymentMethod(from: String?, to: String?)
    case currency(from: String, to: String)
    case tags(from: [Tag], to: [Tag])
    
    /// Get a string key for grouping changes by type
    var changeTypeKey: String {
        switch self {
        case .amount: return "amount"
        case .merchant: return "merchant"
        case .category: return "category"
        case .notes: return "notes"
        case .paymentMethod: return "paymentMethod"
        case .currency: return "currency"
        case .tags: return "tags"
        }
    }
}

/// Errors that can occur during recurring expense operations
enum RecurringExpenseError: Error, LocalizedError {
    case templateNotFound
    case invalidTemplate
    case synchronizationFailed(String)
    case conflictResolutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .templateNotFound:
            return "Recurring expense template not found"
        case .invalidTemplate:
            return "Invalid recurring expense template"
        case .synchronizationFailed(let message):
            return "Template synchronization failed: \(message)"
        case .conflictResolutionFailed(let message):
            return "Conflict resolution failed: \(message)"
        }
    }
}

/// Service for managing recurring expenses with proper Core Data entities
class RecurringExpenseService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Creating Recurring Expenses
    
    /// Create a new recurring expense template
    func createRecurringExpense(
        amount: NSDecimalNumber,
        currencyCode: String,
        merchant: String,
        notes: String? = nil,
        paymentMethod: String? = nil,
        category: Category? = nil,
        tags: [Tag] = [],
        patternType: RecurringFrequency,
        interval: Int32 = 1,
        dayOfMonth: Int32? = nil,
        dayOfWeek: Int32? = nil,
        startDate: Date = Date()
    ) -> RecurringExpense {
        
        let recurringExpense = RecurringExpense(context: context)
        recurringExpense.id = UUID()
        recurringExpense.amount = amount
        recurringExpense.currencyCode = currencyCode
        recurringExpense.merchant = merchant
        recurringExpense.notes = notes
        recurringExpense.paymentMethod = paymentMethod
        recurringExpense.category = category
        recurringExpense.isActive = true
        recurringExpense.createdDate = startDate
        
        // Add tags
        for tag in tags {
            recurringExpense.addToTags(tag)
        }
        
        // Create pattern
        let pattern = RecurringPatternEntity(context: context)
        pattern.id = UUID()
        pattern.patternType = patternType.rawValue
        pattern.interval = interval
        pattern.dayOfMonth = dayOfMonth ?? 0
        pattern.dayOfWeek = dayOfWeek ?? 0
        pattern.nextDueDate = calculateInitialDueDate(from: startDate, pattern: patternType, interval: interval, dayOfMonth: dayOfMonth)
        
        recurringExpense.pattern = pattern
        
        return recurringExpense
    }
    
    /// Convert an existing expense to a recurring template
    func convertExpenseToRecurring(
        expense: Expense,
        patternType: RecurringFrequency,
        interval: Int32 = 1,
        dayOfMonth: Int32? = nil,
        dayOfWeek: Int32? = nil
    ) -> RecurringExpense {
        
        return createRecurringExpense(
            amount: expense.amount,
            currencyCode: expense.currencyCode,
            merchant: expense.merchant,
            notes: expense.notes,
            paymentMethod: expense.paymentMethod,
            category: expense.category,
            tags: expense.safeTags,
            patternType: patternType,
            interval: interval,
            dayOfMonth: dayOfMonth,
            dayOfWeek: dayOfWeek,
            startDate: expense.date
        )
    }
    
    // MARK: - Querying Recurring Expenses
    
    /// Get all active recurring expenses
    func getActiveRecurringExpenses() -> [RecurringExpense] {
        let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.merchant, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching active recurring expenses: \(error)")
            return []
        }
    }
    
    /// Get recurring expenses that are due for generation
    func getDueRecurringExpenses() -> [RecurringExpense] {
        let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        request.predicate = NSPredicate(format: "isActive == YES AND pattern.nextDueDate <= %@", Date() as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.pattern!.nextDueDate, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching due recurring expenses: \(error)")
            return []
        }
    }
    
    /// Get recurring expenses by category
    func getRecurringExpenses(for category: Category) -> [RecurringExpense] {
        let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@ AND isActive == YES", category)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.merchant, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recurring expenses for category: \(error)")
            return []
        }
    }
    
    // MARK: - Generating Expenses
    
    /// Generate all due recurring expenses
    func generateDueExpenses() -> [Expense] {
        let dueRecurringExpenses = getDueRecurringExpenses()
        var generatedExpenses: [Expense] = []
        
        for recurringExpense in dueRecurringExpenses {
            if let expense = generateExpense(from: recurringExpense) {
                generatedExpenses.append(expense)
            }
        }
        
        return generatedExpenses
    }
    
    /// Generate a single expense from a recurring template
    func generateExpense(from recurringExpense: RecurringExpense) -> Expense? {
        guard recurringExpense.isActive,
              let pattern = recurringExpense.pattern,
              pattern.nextDueDate <= Date() else {
            return nil
        }
        
        // Check for duplicates
        if hasExpenseForDate(pattern.nextDueDate, merchant: recurringExpense.merchant, amount: recurringExpense.amount) {
            // Update the next due date even if we don't create a duplicate
            recurringExpense.updateNextDueDate()
            return nil
        }
        
        return recurringExpense.generateExpense(context: context)
    }
    
    // MARK: - Management Operations
    
    /// Deactivate a recurring expense
    func deactivateRecurringExpense(_ recurringExpense: RecurringExpense) {
        recurringExpense.isActive = false
    }
    
    /// Reactivate a recurring expense
    func reactivateRecurringExpense(_ recurringExpense: RecurringExpense) {
        recurringExpense.isActive = true
        // Update next due date
        if let pattern = recurringExpense.pattern {
            pattern.nextDueDate = recurringExpense.calculateNextDueDate()
        }
    }
    
    /// Delete a recurring expense and optionally its generated expenses
    func deleteRecurringExpense(_ recurringExpense: RecurringExpense, deleteGeneratedExpenses: Bool = false) {
        // Ensure the object is not deleted and has a valid context
        guard !recurringExpense.isDeleted, recurringExpense.managedObjectContext != nil else {
            print("Warning: Attempting to delete an already deleted or invalid RecurringExpense")
            return
        }
        
        // Handle generated expenses first
        if deleteGeneratedExpenses {
            // Get a copy of the generated expenses array to avoid mutation during iteration
            let generatedExpenses = Array(recurringExpense.safeGeneratedExpenses)
            for expense in generatedExpenses {
                if !expense.isDeleted && expense.managedObjectContext != nil {
                    context.delete(expense)
                }
            }
        } else {
            // Clear the relationship but keep the expenses
            let generatedExpenses = Array(recurringExpense.safeGeneratedExpenses)
            for expense in generatedExpenses {
                if !expense.isDeleted && expense.managedObjectContext != nil {
                    expense.recurringTemplate = nil
                }
            }
        }
        
        // Delete the pattern entity if it exists
        if let pattern = recurringExpense.pattern, !pattern.isDeleted, pattern.managedObjectContext != nil {
            context.delete(pattern)
        }
        
        // Finally delete the recurring expense itself
        context.delete(recurringExpense)
    }
    
    /// Delete multiple recurring expenses with the same deletion policy
    func deleteRecurringExpenses(_ recurringExpenses: [RecurringExpense], deleteGeneratedExpenses: Bool = false) {
        for recurringExpense in recurringExpenses {
            deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: deleteGeneratedExpenses)
        }
    }
    
    // MARK: - Duplicate Prevention
    
    /// Check if an expense already exists for the given date/merchant/amount
    private func hasExpenseForDate(_ date: Date, merchant: String, amount: NSDecimalNumber) -> Bool {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "merchant == %@ AND date >= %@ AND date < %@ AND amount == %@",
                                      merchant, startOfDay as CVarArg, endOfDay as CVarArg, amount)
        
        do {
            let existingExpenses = try context.fetch(request)
            return !existingExpenses.isEmpty
        } catch {
            print("Error checking for existing expense: \(error)")
            return false
        }
    }
    
    /// Advanced duplicate prevention with fuzzy matching
    func findPotentialDuplicates(for recurringExpense: RecurringExpense, within days: Int = 3) -> [Expense] {
        guard let pattern = recurringExpense.pattern else { return [] }
        
        let calendar = Calendar.current
        let targetDate = pattern.nextDueDate
        let startDate = calendar.date(byAdding: .day, value: -days, to: targetDate)!
        let endDate = calendar.date(byAdding: .day, value: days, to: targetDate)!
        
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startDate as CVarArg, endDate as CVarArg)
        
        do {
            let expenses = try context.fetch(request)
            return expenses.filter { expense in
                // Fuzzy matching logic
                let merchantSimilarity = calculateSimilarity(recurringExpense.merchant, expense.merchant)
                let amountDifference = abs(recurringExpense.amount.doubleValue - expense.amount.doubleValue)
                
                return merchantSimilarity > 0.8 && amountDifference < 5.0
            }
        } catch {
            print("Error finding potential duplicates: \(error)")
            return []
        }
    }
    
    // MARK: - Template Synchronization Methods
    
    /// Detect if an expense is linked to a recurring template and has been modified
    func detectTemplateLinkedExpenseModification(_ expense: Expense) -> Bool {
        guard let template = expense.recurringTemplate else { return false }
        
        // Check if key fields have been modified from the template
        return expense.amount != template.amount ||
               expense.merchant != template.merchant ||
               expense.category != template.category ||
               expense.notes != template.notes ||
               expense.paymentMethod != template.paymentMethod ||
               expense.currencyCode != template.currencyCode
    }
    
    /// Get the differences between an expense and its recurring template
    func getExpenseTemplateChanges(_ expense: Expense) -> [TemplateChangeType] {
        guard let template = expense.recurringTemplate else { return [] }
        
        var changes: [TemplateChangeType] = []
        
        if expense.amount != template.amount {
            changes.append(.amount(from: template.amount, to: expense.amount))
        }
        
        if expense.merchant != template.merchant {
            changes.append(.merchant(from: template.merchant, to: expense.merchant))
        }
        
        if expense.category != template.category {
            changes.append(.category(from: template.category, to: expense.category))
        }
        
        if expense.notes != template.notes {
            changes.append(.notes(from: template.notes, to: expense.notes))
        }
        
        if expense.paymentMethod != template.paymentMethod {
            changes.append(.paymentMethod(from: template.paymentMethod, to: expense.paymentMethod))
        }
        
        if expense.currencyCode != template.currencyCode {
            changes.append(.currency(from: template.currencyCode, to: expense.currencyCode))
        }
        
        // Check tags
        let expenseTags = Set(expense.tags?.allObjects as? [Tag] ?? [])
        let templateTags = Set(template.tags?.allObjects as? [Tag] ?? [])
        
        if expenseTags != templateTags {
            changes.append(.tags(from: Array(templateTags), to: Array(expenseTags)))
        }
        
        return changes
    }
    
    /// Update a recurring template from expense changes
    func updateTemplateFromExpense(_ template: RecurringExpense, with changes: [TemplateChangeType]) throws {
        guard !template.isDeleted, template.managedObjectContext != nil else {
            throw RecurringExpenseError.templateNotFound
        }
        
        for change in changes {
            switch change {
            case .amount(_, let newAmount):
                template.amount = newAmount
                
            case .merchant(_, let newMerchant):
                template.merchant = newMerchant
                
            case .category(_, let newCategory):
                template.category = newCategory
                
            case .notes(_, let newNotes):
                template.notes = newNotes
                
            case .paymentMethod(_, let newPaymentMethod):
                template.paymentMethod = newPaymentMethod
                
            case .currency(_, let newCurrency):
                template.currencyCode = newCurrency
                
            case .tags(_, let newTags):
                // Clear existing tags
                if let existingTags = template.tags {
                    template.removeFromTags(existingTags)
                }
                // Add new tags
                for tag in newTags {
                    template.addToTags(tag)
                }
            }
        }
    }
    
    /// Synchronize template from a specific expense
    func synchronizeTemplateFromExpense(_ expense: Expense) throws {
        guard let template = expense.recurringTemplate else {
            throw RecurringExpenseError.templateNotFound
        }
        
        let changes = getExpenseTemplateChanges(expense)
        guard !changes.isEmpty else { return }
        
        try updateTemplateFromExpense(template, with: changes)
    }
    
    /// Validate that a recurring template is not orphaned
    func validateTemplateNotOrphaned(_ template: RecurringExpense) -> Bool {
        // A template is considered orphaned if:
        // 1. It has no generated expenses AND
        // 2. It's been inactive for a long time OR
        // 3. Its next due date is far in the past without recent generation
        
        let generatedExpenses = template.safeGeneratedExpenses
        
        // If it has generated expenses, it's not orphaned
        if !generatedExpenses.isEmpty {
            return true
        }
        
        // Check if it's been inactive for more than 6 months
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        if template.createdDate < sixMonthsAgo && !template.isActive {
            return false
        }
        
        // Check if next due date is more than 3 months in the past
        if let pattern = template.pattern {
            let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
            if pattern.nextDueDate < threeMonthsAgo && template.lastGeneratedDate == nil {
                return false
            }
        }
        
        return true
    }
    
    /// Find and clean up orphaned templates
    func findOrphanedTemplates() -> [RecurringExpense] {
        let allTemplates = getActiveRecurringExpenses()
        return allTemplates.filter { !validateTemplateNotOrphaned($0) }
    }
    
    /// Resolve conflicts when multiple expenses from the same template have different changes
    func resolveTemplateUpdateConflicts(_ template: RecurringExpense, conflictingChanges: [[TemplateChangeType]]) throws -> [TemplateChangeType] {
        guard !conflictingChanges.isEmpty else { return [] }
        
        var resolvedChanges: [TemplateChangeType] = []
        var changesByType: [String: [TemplateChangeType]] = [:]
        
        // Group changes by type
        for changeSet in conflictingChanges {
            for change in changeSet {
                let key = change.changeTypeKey
                if changesByType[key] == nil {
                    changesByType[key] = []
                }
                changesByType[key]?.append(change)
            }
        }
        
        // Resolve conflicts for each change type
        for (changeType, changes) in changesByType {
            guard !changes.isEmpty else { continue }
            
            if changes.count == 1 {
                // No conflict, use the single change
                resolvedChanges.append(changes[0])
            } else {
                // Resolve conflict based on change type
                switch changeType {
                case "amount":
                    // Use the most recent or most common amount
                    resolvedChanges.append(resolveAmountConflict(changes))
                    
                case "merchant":
                    // Use the most common merchant name
                    resolvedChanges.append(resolveMerchantConflict(changes))
                    
                case "category":
                    // Use the most common category
                    resolvedChanges.append(resolveCategoryConflict(changes))
                    
                case "notes":
                    // Merge notes or use the longest one
                    resolvedChanges.append(resolveNotesConflict(changes))
                    
                case "paymentMethod":
                    // Use the most common payment method
                    resolvedChanges.append(resolvePaymentMethodConflict(changes))
                    
                case "currency":
                    // Use the most common currency
                    resolvedChanges.append(resolveCurrencyConflict(changes))
                    
                case "tags":
                    // Merge all unique tags
                    resolvedChanges.append(resolveTagsConflict(changes))
                    
                default:
                    // Default to first change if we don't have specific resolution logic
                    resolvedChanges.append(changes[0])
                }
            }
        }
        
        return resolvedChanges
    }
    
    // MARK: - Conflict Resolution Helpers
    
    private func resolveAmountConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        // Use the most common amount, or the latest one if all are different
        var amountCounts: [NSDecimalNumber: Int] = [:]
        
        for change in changes {
            if case .amount(_, let newAmount) = change {
                amountCounts[newAmount] = (amountCounts[newAmount] ?? 0) + 1
            }
        }
        
        let mostCommonAmount = amountCounts.max(by: { $0.value < $1.value })?.key
        return .amount(from: NSDecimalNumber.zero, to: mostCommonAmount ?? NSDecimalNumber.zero)
    }
    
    private func resolveMerchantConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var merchantCounts: [String: Int] = [:]
        
        for change in changes {
            if case .merchant(_, let newMerchant) = change {
                merchantCounts[newMerchant] = (merchantCounts[newMerchant] ?? 0) + 1
            }
        }
        
        let mostCommonMerchant = merchantCounts.max(by: { $0.value < $1.value })?.key
        return .merchant(from: "", to: mostCommonMerchant ?? "")
    }
    
    private func resolveCategoryConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var categoryCounts: [Category?: Int] = [:]
        
        for change in changes {
            if case .category(_, let newCategory) = change {
                categoryCounts[newCategory] = (categoryCounts[newCategory] ?? 0) + 1
            }
        }
        
        let mostCommonCategory = categoryCounts.max(by: { $0.value < $1.value })?.key
        return .category(from: nil, to: mostCommonCategory ?? nil)
    }
    
    private func resolveNotesConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var allNotes: [String] = []
        
        for change in changes {
            if case .notes(_, let newNotes) = change, let notes = newNotes, !notes.isEmpty {
                allNotes.append(notes)
            }
        }
        
        // Use the longest notes or merge unique ones
        let longestNotes = allNotes.max(by: { $0.count < $1.count })
        return .notes(from: nil, to: longestNotes)
    }
    
    private func resolvePaymentMethodConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var methodCounts: [String?: Int] = [:]
        
        for change in changes {
            if case .paymentMethod(_, let newMethod) = change {
                methodCounts[newMethod] = (methodCounts[newMethod] ?? 0) + 1
            }
        }
        
        let mostCommonMethod = methodCounts.max(by: { $0.value < $1.value })?.key
        return .paymentMethod(from: nil, to: mostCommonMethod ?? nil)
    }
    
    private func resolveCurrencyConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var currencyCounts: [String: Int] = [:]
        
        for change in changes {
            if case .currency(_, let newCurrency) = change {
                currencyCounts[newCurrency] = (currencyCounts[newCurrency] ?? 0) + 1
            }
        }
        
        let mostCommonCurrency = currencyCounts.max(by: { $0.value < $1.value })?.key
        return .currency(from: "", to: mostCommonCurrency ?? "USD")
    }
    
    private func resolveTagsConflict(_ changes: [TemplateChangeType]) -> TemplateChangeType {
        var allTags: Set<Tag> = []
        
        for change in changes {
            if case .tags(_, let newTags) = change {
                allTags.formUnion(newTags)
            }
        }
        
        return .tags(from: [], to: Array(allTags))
    }
    
    // MARK: - Helper Methods
    
    private func calculateInitialDueDate(from startDate: Date, pattern: RecurringFrequency, interval: Int32, dayOfMonth: Int32?) -> Date {
        let calendar = Calendar.current
        
        switch pattern {
        case .none:
            return startDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: Int(interval), to: startDate) ?? startDate
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * Int(interval), to: startDate) ?? startDate
        case .monthly:
            if let dayOfMonth = dayOfMonth, dayOfMonth > 0 {
                var components = calendar.dateComponents([.year, .month], from: startDate)
                components.day = Int(dayOfMonth)
                
                if let targetDate = calendar.date(from: components), targetDate > startDate {
                    return targetDate
                } else {
                    components.month = (components.month ?? 1) + Int(interval)
                    return calendar.date(from: components) ?? startDate
                }
            } else {
                return calendar.date(byAdding: .month, value: Int(interval), to: startDate) ?? startDate
            }
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3 * Int(interval), to: startDate) ?? startDate
        }
    }
    
    private func calculateSimilarity(_ string1: String, _ string2: String) -> Double {
        let longer = string1.count > string2.count ? string1 : string2
        let shorter = string1.count > string2.count ? string2 : string1
        
        if longer.isEmpty { return 1.0 }
        
        let editDistance = levenshteinDistance(longer, shorter)
        return (Double(longer.count) - Double(editDistance)) / Double(longer.count)
    }
    
    private func levenshteinDistance(_ string1: String, _ string2: String) -> Int {
        let string1Array = Array(string1)
        let string2Array = Array(string2)
        let string1Count = string1Array.count
        let string2Count = string2Array.count
        
        if string1Count == 0 { return string2Count }
        if string2Count == 0 { return string1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: string2Count + 1), count: string1Count + 1)
        
        for i in 0...string1Count {
            matrix[i][0] = i
        }
        
        for j in 0...string2Count {
            matrix[0][j] = j
        }
        
        for i in 1...string1Count {
            for j in 1...string2Count {
                let cost = string1Array[i - 1] == string2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[string1Count][string2Count]
    }
}