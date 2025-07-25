import Foundation
import CoreData

extension ExpenseItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExpenseItem> {
        return NSFetchRequest<ExpenseItem>(entityName: "ExpenseItem")
    }

    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var category: Category?
    @NSManaged public var expense: Expense?
    @NSManaged public var receiptItem: ReceiptItem?
    
    // Convenience properties
    public var safeName: String {
        return name
    }
}