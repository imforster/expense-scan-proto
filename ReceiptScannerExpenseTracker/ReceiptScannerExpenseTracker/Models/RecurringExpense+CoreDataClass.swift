import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerRecurringExpense)
public class RecurringExpense: NSManagedObject {
    
    /// Generate the next due date based on the pattern
    func calculateNextDueDate() -> Date {
        guard let pattern = self.pattern else {
            return Date()
        }
        
        let baseDate = lastGeneratedDate ?? createdDate
        return pattern.calculateNextDate(from: baseDate)
    }
    
    /// Check if this recurring expense is due for generation
    var isDue: Bool {
        guard isActive else { return false }
        return pattern?.nextDueDate ?? Date() <= Date()
    }
    
    /// Update the next due date after generating an expense
    func updateNextDueDate() {
        pattern?.nextDueDate = calculateNextDueDate()
        lastGeneratedDate = Date()
    }
    
    /// Create a new expense from this recurring template
    func generateExpense(context: NSManagedObjectContext) -> Expense? {
        guard isActive, isDue else { return nil }
        
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = self.amount
        expense.currencyCode = self.currencyCode
        expense.merchant = self.merchant
        expense.notes = self.notes
        expense.paymentMethod = self.paymentMethod
        expense.category = self.category
        expense.isRecurring = false
        expense.recurringTemplate = self
        expense.date = pattern?.nextDueDate ?? Date()
        
        // Copy tags
        if let tags = self.tags {
            expense.tags = tags
        }
        
        // Update tracking
        updateNextDueDate()
        
        return expense
    }
}