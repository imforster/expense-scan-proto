import Foundation
import CoreData

// Model for receipt splitting functionality
struct ReceiptSplit: Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var category: Category?
    var isSelected: Bool
}