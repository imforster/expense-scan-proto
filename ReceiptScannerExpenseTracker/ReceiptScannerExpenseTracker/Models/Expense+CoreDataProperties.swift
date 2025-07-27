import Foundation
import CoreData

extension Expense {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Expense> {
        return NSFetchRequest<Expense>(entityName: "Expense")
    }

    @NSManaged public var id: UUID
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var date: Date
    @NSManaged public var merchant: String
    @NSManaged public var notes: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var isRecurring: Bool
    @NSManaged public var category: Category?
    @NSManaged public var items: NSSet?
    @NSManaged public var receipt: Receipt?
    @NSManaged public var tags: NSSet?
    
    // Convenience methods
    func formattedAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: amount) ?? "$0.00"
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: Generated accessors for items
extension Expense {
    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ExpenseItem)
    
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ExpenseItem)
    
    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)
    
    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)
}

// MARK: Generated accessors for tags
extension Expense {
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

// MARK: - Temporary implementation for preview and testing
extension Expense {
    static func createSampleExpense(context: NSManagedObjectContext) -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "42.99")
        expense.date = Date()
        expense.merchant = "Sample Merchant"
        expense.notes = "Sample expense for testing"
        expense.paymentMethod = "Credit Card"
        expense.isRecurring = false
        
        // Get a default category
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name == %@", "Food")
        fetchRequest.fetchLimit = 1
        
        do {
            let categories = try context.fetch(fetchRequest)
            if let category = categories.first {
                expense.category = category
            }
        } catch {
            print("Error fetching category: \(error)")
        }
        
        return expense
    }
    
    static func createSampleExpenses(context: NSManagedObjectContext, count: Int = 5) -> [Expense] {
        var expenses: [Expense] = []
        
        // Fetch available categories
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        var availableCategories: [Category] = []
        
        do {
            availableCategories = try context.fetch(fetchRequest)
        } catch {
            print("Error fetching categories: \(error)")
        }
        
        guard !availableCategories.isEmpty else {
            print("No categories available for sample expenses")
            return []
        }
        
        let merchants = ["Grocery Store", "Gas Station", "Movie Theater", "Electric Company", "Department Store"]
        
        for i in 0..<count {
            let expense = Expense(context: context)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(value: Double.random(in: 10...200))
            expense.date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) ?? Date()
            expense.merchant = merchants[i % merchants.count]
            expense.notes = "Sample expense \(i+1)"
            expense.paymentMethod = i % 2 == 0 ? "Credit Card" : "Cash"
            expense.isRecurring = i % 3 == 0
            expense.category = availableCategories[i % availableCategories.count]
            
            expenses.append(expense)
        }
        
        return expenses
    }
}
