import Foundation
import CoreData

extension Receipt {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Receipt> {
        return NSFetchRequest<Receipt>(entityName: "Receipt")
    }

    @NSManaged public var id: UUID
    @NSManaged public var imageURL: URL
    @NSManaged public var processedImageURL: URL?
    @NSManaged public var dateProcessed: Date
    @NSManaged public var rawTextContent: String?
    @NSManaged public var merchantName: String
    @NSManaged public var date: Date
    @NSManaged public var totalAmount: NSDecimalNumber
    @NSManaged public var taxAmount: NSDecimalNumber?
    @NSManaged public var paymentMethod: String?
    @NSManaged public var receiptNumber: String?
    @NSManaged public var confidence: Float
    @NSManaged public var expense: Expense?
    @NSManaged public var items: NSSet?
    
    // Convenience methods
    func formattedTotalAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: totalAmount) ?? "$0.00"
    }
    
    func formattedTaxAmount() -> String? {
        guard let taxAmount = taxAmount else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: taxAmount)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func confidencePercentage() -> String {
        return "\(Int(confidence * 100))%"
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