import Foundation
import CoreData
import SwiftUI

@objc(ReceiptScannerExpenseTrackerExpense)
public class Expense: NSManagedObject {
    // Convenience methods
    func formattedAmount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: amount as NSNumber) ?? "$0.00"
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}