import Foundation
import CoreData

extension ExpenseItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ExpenseItem> {
        return NSFetchRequest<ExpenseItem>(entityName: "ExpenseItem")
    }

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var amount: NSDecimalNumber
    @NSManaged public var category: Category?
    @NSManaged public var expense: Expense?
    @NSManaged public var receiptItem: ReceiptItem?
    
    // Convenience methods
    func formattedAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD" // This should be configurable in a real app
        return formatter.string(from: amount) ?? "$0.00"
    }
}