import Foundation
import CoreData

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