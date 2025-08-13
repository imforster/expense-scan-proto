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
    /// @deprecated This method is no longer functional. Use RecurringExpenseService instead.
    static func generateNextExpense(from template: Expense, context: NSManagedObjectContext) -> Expense? {
        // Legacy recurring expense functionality has been removed
        // Use RecurringExpenseService for new recurring expense functionality
        return nil
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
    /// @deprecated This method is no longer functional. Use RecurringExpenseService instead.
    static func getRecurringExpenses(context: NSManagedObjectContext) -> [Expense] {
        // Legacy recurring expense functionality has been removed
        // Use RecurringExpenseService for new recurring expense functionality
        return []
    }
    
    /// Get recurring expenses that are due for generation
    /// @deprecated This method is no longer functional. Use RecurringExpenseService instead.
    static func getDueRecurringExpenses(context: NSManagedObjectContext) -> [Expense] {
        // Legacy recurring expense functionality has been removed
        // Use RecurringExpenseService for new recurring expense functionality
        return []
    }
}