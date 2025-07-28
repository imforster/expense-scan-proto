import Foundation

/// Data transfer object for expense information
struct ExpenseData {
    let amount: Decimal
    let merchant: String
    let date: Date
    let notes: String?
    let paymentMethod: String?
    let isRecurring: Bool
    let categoryId: UUID?
    let tags: [TagData]
    let items: [ExpenseItemData]
    
    init(
        amount: Decimal,
        merchant: String,
        date: Date = Date(),
        notes: String? = nil,
        paymentMethod: String? = nil,
        isRecurring: Bool = false,
        categoryId: UUID? = nil,
        tags: [TagData] = [],
        items: [ExpenseItemData] = []
    ) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.isRecurring = isRecurring
        self.categoryId = categoryId
        self.tags = tags
        self.items = items
    }
}

struct TagData: Equatable {
    let id: UUID
    let name: String
}

struct ExpenseItemData: Equatable {
    let name: String
    let amount: Decimal
    let quantity: Int32
    
    init(name: String, amount: Decimal, quantity: Int32 = 1) {
        self.name = name
        self.amount = amount
        self.quantity = quantity
    }
}