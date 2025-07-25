import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerReceipt)
public class Receipt: NSManagedObject {
    // Convenience methods
    func formattedTotalAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: totalAmount as NSNumber) ?? "$0.00"
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}