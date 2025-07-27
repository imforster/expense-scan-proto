import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerReceiptItem)
public class ReceiptItem: NSManagedObject {
    // Convenience methods
    func formattedTotalPrice() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: totalPrice as NSNumber) ?? "$0.00"
    }
    
    func formattedUnitPrice() -> String {
        guard let unitPrice = unitPrice else { return "N/A" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: unitPrice as NSNumber) ?? "$0.00"
    }
}