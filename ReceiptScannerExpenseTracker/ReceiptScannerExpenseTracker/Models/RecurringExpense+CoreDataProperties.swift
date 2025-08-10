import Foundation
import CoreData

extension RecurringExpense: Identifiable {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecurringExpense> {
        return NSFetchRequest<RecurringExpense>(entityName: "RecurringExpense")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var currencyCode: String
    @NSManaged public var merchant: String
    @NSManaged public var notes: String?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var isActive: Bool
    @NSManaged public var createdDate: Date
    @NSManaged public var lastGeneratedDate: Date?
    @NSManaged public var category: Category?
    @NSManaged public var pattern: RecurringPatternEntity?
    @NSManaged public var generatedExpenses: NSSet?
    @NSManaged public var tags: NSSet?
    
    // Convenience methods
    func formattedAmount() -> String {
        guard !isDeleted, managedObjectContext != nil else {
            return "$0.00"
        }
        
        do {
            return CurrencyService.shared.formatAmount(amount, currencyCode: currencyCode)
        } catch {
            return "$0.00"
        }
    }
    
    /// Safe category name with fallback
    var safeCategoryName: String {
        return self.category?.name ?? "Uncategorized"
    }
    
    /// Safe tags array
    var safeTags: [Tag] {
        return self.tags?.allObjects as? [Tag] ?? []
    }
    
    /// Safe generated expenses array
    var safeGeneratedExpenses: [Expense] {
        return self.generatedExpenses?.allObjects as? [Expense] ?? []
    }
}

// MARK: Generated accessors for generatedExpenses
extension RecurringExpense {
    
    @objc(addGeneratedExpensesObject:)
    @NSManaged public func addToGeneratedExpenses(_ value: Expense)
    
    @objc(removeGeneratedExpensesObject:)
    @NSManaged public func removeFromGeneratedExpenses(_ value: Expense)
    
    @objc(addGeneratedExpenses:)
    @NSManaged public func addToGeneratedExpenses(_ values: NSSet)
    
    @objc(removeGeneratedExpenses:)
    @NSManaged public func removeFromGeneratedExpenses(_ values: NSSet)
}

// MARK: Generated accessors for tags
extension RecurringExpense {
    
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)
    
    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)
    
    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)
    
    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}