import Foundation
import CoreData

extension Tag {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var expenses: NSSet?
    @NSManaged public var recurringExpenses: NSSet?
    
    // Convenience properties
    public var safeExpenses: [Expense] {
        let expenseSet = expenses as? Set<Expense> ?? []
        return Array(expenseSet)
    }
    
    public var safeRecurringExpenses: [RecurringExpense] {
        let recurringExpenseSet = recurringExpenses as? Set<RecurringExpense> ?? []
        return Array(recurringExpenseSet)
    }
    
    public var safeName: String {
        return name
    }
}

// MARK: Generated accessors for expenses
extension Tag {

    @objc(addExpensesObject:)
    @NSManaged public func addToExpenses(_ value: Expense)

    @objc(removeExpensesObject:)
    @NSManaged public func removeFromExpenses(_ value: Expense)

    @objc(addExpenses:)
    @NSManaged public func addToExpenses(_ values: NSSet)

    @objc(removeExpenses:)
    @NSManaged public func removeFromExpenses(_ values: NSSet)

}

// MARK: Generated accessors for recurringExpenses
extension Tag {

    @objc(addRecurringExpensesObject:)
    @NSManaged public func addToRecurringExpenses(_ value: RecurringExpense)

    @objc(removeRecurringExpensesObject:)
    @NSManaged public func removeFromRecurringExpenses(_ value: RecurringExpense)

    @objc(addRecurringExpenses:)
    @NSManaged public func addToRecurringExpenses(_ values: NSSet)

    @objc(removeRecurringExpenses:)
    @NSManaged public func removeFromRecurringExpenses(_ values: NSSet)

}