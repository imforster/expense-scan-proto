import Foundation
import CoreData

extension Receipt {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Receipt> {
        return NSFetchRequest<Receipt>(entityName: "Receipt")
    }

    @NSManaged public var confidence: Float
    @NSManaged public var date: Date
    @NSManaged public var dateProcessed: Date
    @NSManaged public var id: UUID
    @NSManaged public var imageURL: URL
    @NSManaged public var merchantName: String
    @NSManaged public var paymentMethod: String?
    @NSManaged public var processedImageURL: URL?
    @NSManaged public var rawTextContent: String?
    @NSManaged public var receiptNumber: String?
    @NSManaged public var taxAmount: NSDecimalNumber?
    @NSManaged public var totalAmount: NSDecimalNumber
    @NSManaged public var expense: Expense?
    @NSManaged public var items: NSSet?
    
    // Convenience properties
    public var safeMerchantName: String {
        return merchantName
    }
    
    public var safePaymentMethod: String {
        return paymentMethod ?? "Unknown"
    }
    
    public var safeRawTextContent: String {
        return rawTextContent ?? ""
    }
    
    public var safeReceiptNumber: String {
        return receiptNumber ?? ""
    }
    
    public var safeItems: [ReceiptItem] {
        let itemSet = items as? Set<ReceiptItem> ?? []
        return Array(itemSet)
    }
}

// MARK: Generated accessors for items
extension Receipt {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: ReceiptItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: ReceiptItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}