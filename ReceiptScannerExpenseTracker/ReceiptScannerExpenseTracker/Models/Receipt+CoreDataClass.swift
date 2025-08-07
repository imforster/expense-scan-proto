import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerReceipt)
public class Receipt: NSManagedObject {
    // Convenience methods
    func formattedTotalAmount() -> String {
        return CurrencyService.shared.formatAmount(totalAmount, currencyCode: currencyCode)
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}