import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerExpenseItem)
public class ExpenseItem: NSManagedObject {
    // Convenience methods
    func formattedAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSNumber) ?? "$0.00"
    }
}