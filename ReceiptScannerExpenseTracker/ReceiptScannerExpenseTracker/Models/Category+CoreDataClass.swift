import Foundation
import CoreData
import SwiftUI

@objc(Category)
public class Category: NSManagedObject {
    
    // MARK: - Convenience Initializers
    
    convenience init(context: NSManagedObjectContext, name: String, colorHex: String, icon: String) {
        self.init(context: context)
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.isDefault = false
    }
    
    // MARK: - Computed Properties
    
    var color: Color {
        return Color(hex: colorHex) ?? .blue
    }
    
    var safeName: String {
        return name ?? "Unknown Category"
    }
    
    var safeIcon: String {
        return icon ?? "tag.fill"
    }
    
    var expenseCount: Int {
        return expenses?.count ?? 0
    }
    
    // MARK: - Helper Methods
    
    func addExpense(_ expense: Expense) {
        addToExpenses(expense)
    }
    
    func removeExpense(_ expense: Expense) {
        removeFromExpenses(expense)
    }
}
