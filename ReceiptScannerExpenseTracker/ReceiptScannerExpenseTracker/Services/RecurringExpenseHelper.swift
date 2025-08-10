//
//  RecurringExpenseHelper.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Kiro on 8/4/25.
//

import Foundation
import CoreData

/// Simple helper for recurring expense operations
/// @deprecated This class is deprecated. Use RecurringExpenseService instead for new Core Data entity-based recurring expenses.
/// This class remains for backward compatibility with legacy notes-based recurring expenses.
class RecurringExpenseHelper {
    
    /// Generate a new expense from a recurring template
    static func generateNextExpense(from template: Expense, context: NSManagedObjectContext) -> Expense? {
        guard template.isRecurring,
              let recurringInfo = template.recurringInfo,
              let nextDate = template.nextRecurringDate else {
            return nil
        }
        
        // Check if an expense already exists for this date to prevent duplicates
        if hasExpenseForDate(nextDate, merchant: template.merchant, amount: template.amount, context: context) {
            return nil
        }
        
        // Create new expense
        let newExpense = Expense(context: context)
        newExpense.id = UUID()
        newExpense.amount = template.amount
        newExpense.date = nextDate
        newExpense.merchant = template.merchant
        newExpense.paymentMethod = template.paymentMethod
        newExpense.category = template.category
        newExpense.isRecurring = false // Generated expenses are not recurring themselves
        
        // Copy tags
        if let templateTags = template.tags {
            newExpense.tags = templateTags
        }
        
        // Set notes indicating this was generated
        let originalNotes = template.notes?.replacingOccurrences(of: "\\[Recurring:.*?\\]", with: "", options: .regularExpression) ?? ""
        newExpense.notes = "Generated from recurring expense. \(originalNotes)".trimmingCharacters(in: .whitespaces)
        
        return newExpense
    }
    
    /// Check if an expense already exists for the given date/merchant/amount
    private static func hasExpenseForDate(_ date: Date, merchant: String, amount: NSDecimalNumber, context: NSManagedObjectContext) -> Bool {
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
    
    /// Get all recurring expenses
    static func getRecurringExpenses(context: NSManagedObjectContext) -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isRecurring == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching recurring expenses: \(error)")
            return []
        }
    }
    
    /// Get recurring expenses that are due for generation
    static func getDueRecurringExpenses(context: NSManagedObjectContext) -> [Expense] {
        let recurringExpenses = getRecurringExpenses(context: context)
        let now = Date()
        
        return recurringExpenses.filter { expense in
            guard let nextDate = expense.nextRecurringDate else { return false }
            return nextDate <= now
        }
    }
}