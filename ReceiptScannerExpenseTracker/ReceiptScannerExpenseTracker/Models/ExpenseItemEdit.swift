import Foundation
import CoreData

// Model for editing expense items
struct ExpenseItemEdit: Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var category: Category?
}