import Foundation
import CoreData

extension ReceiptItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ReceiptItem> {
        return NSFetchRequest<ReceiptItem>(entityName: "ReceiptItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var quantity: Int32
    @NSManaged public var unitPrice: NSDecimalNumber?
    @NSManaged public var totalPrice: NSDecimalNumber
    @NSManaged public var receipt: Receipt?
    @NSManaged public var expenseItem: ExpenseItem?
    
    // Convenience methods
    func formattedTotalPrice() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: totalPrice) ?? "$0.00"
    }
    
    func formattedUnitPrice() -> String? {
        guard let unitPrice = unitPrice else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: unitPrice)
    }
}