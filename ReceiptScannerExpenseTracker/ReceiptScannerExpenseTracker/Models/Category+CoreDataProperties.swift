import Foundation
import CoreData
import SwiftUI

extension Category {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var colorHex: String
    @NSManaged public var icon: String
    @NSManaged public var id: UUID
    @NSManaged public var isDefault: Bool
    @NSManaged public var name: String
    @NSManaged public var expenseItems: NSSet?
    @NSManaged public var expenses: NSSet?
    @NSManaged public var parentCategory: Category?
    @NSManaged public var subcategories: NSSet?
    
    // Convenience properties
    public var safeIcon: String {
        return icon
    }
    
    public var safeName: String {
        return name
    }
    
    public var safeExpenses: [Expense] {
        let expenseSet = expenses as? Set<Expense> ?? []
        return Array(expenseSet)
    }
    
    public var safeExpenseItems: [ExpenseItem] {
        let itemSet = expenseItems as? Set<ExpenseItem> ?? []
        return Array(itemSet)
    }
    
    public var safeSubcategories: [Category] {
        let subcategorySet = subcategories as? Set<Category> ?? []
        return Array(subcategorySet)
    }
}

// MARK: Generated accessors for expenseItems
extension Category {

    @objc(addExpenseItemsObject:)
    @NSManaged public func addToExpenseItems(_ value: ExpenseItem)

    @objc(removeExpenseItemsObject:)
    @NSManaged public func removeFromExpenseItems(_ value: ExpenseItem)

    @objc(addExpenseItems:)
    @NSManaged public func addToExpenseItems(_ values: NSSet)

    @objc(removeExpenseItems:)
    @NSManaged public func removeFromExpenseItems(_ values: NSSet)

}

// MARK: Generated accessors for expenses
extension Category {

    @objc(addExpensesObject:)
    @NSManaged public func addToExpenses(_ value: Expense)

    @objc(removeExpensesObject:)
    @NSManaged public func removeFromExpenses(_ value: Expense)

    @objc(addExpenses:)
    @NSManaged public func addToExpenses(_ values: NSSet)

    @objc(removeExpenses:)
    @NSManaged public func removeFromExpenses(_ values: NSSet)

}

// MARK: Generated accessors for subcategories
extension Category {

    @objc(addSubcategoriesObject:)
    @NSManaged public func addToSubcategories(_ value: Category)

    @objc(removeSubcategoriesObject:)
    @NSManaged public func removeFromSubcategories(_ value: Category)

    @objc(addSubcategories:)
    @NSManaged public func addToSubcategories(_ values: NSSet)

    @objc(removeSubcategories:)
    @NSManaged public func removeFromSubcategories(_ values: NSSet)

}