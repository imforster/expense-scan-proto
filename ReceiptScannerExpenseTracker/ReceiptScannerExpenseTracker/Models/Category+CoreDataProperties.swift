import Foundation
import CoreData
import SwiftUI

extension Category {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var colorHex: String
    @NSManaged public var icon: String
    @NSManaged public var isDefault: Bool
    @NSManaged public var expenses: NSSet?
    @NSManaged public var expenseItems: NSSet?
    @NSManaged public var parentCategory: Category?
    @NSManaged public var subcategories: NSSet?
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
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

// MARK: - Color Extension for Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        self.init(
            .sRGB,
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0,
            opacity: 1.0
        )
    }
}