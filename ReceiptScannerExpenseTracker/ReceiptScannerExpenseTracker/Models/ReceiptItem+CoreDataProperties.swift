import Foundation
import CoreData

extension ReceiptItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReceiptItem> {
        return NSFetchRequest<ReceiptItem>(entityName: "ReceiptItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var quantity: Int32
    @NSManaged public var totalPrice: NSDecimalNumber
    @NSManaged public var unitPrice: NSDecimalNumber?
    @NSManaged public var expenseItem: ExpenseItem?
    @NSManaged public var receipt: Receipt?
    
    // Convenience properties
    public var safeName: String {
        return name
    }
}