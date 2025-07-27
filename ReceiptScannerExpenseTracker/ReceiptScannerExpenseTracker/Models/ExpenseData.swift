import Foundation
import CoreData

// MARK: - Data Transfer Objects

/// Data structure for creating/updating expenses
struct ExpenseData {
    let amount: Decimal
    let merchant: String
    let date: Date
    let notes: String?
    let paymentMethod: String?
    let isRecurring: Bool
    let category: CategoryData?
    let tags: [TagData]
    let items: [ExpenseItemData]
    
    init(
        amount: Decimal,
        merchant: String,
        date: Date,
        notes: String? = nil,
        paymentMethod: String? = nil,
        isRecurring: Bool = false,
        category: CategoryData? = nil,
        tags: [TagData] = [],
        items: [ExpenseItemData] = []
    ) {
        self.amount = amount
        self.merchant = merchant
        self.date = date
        self.notes = notes
        self.paymentMethod = paymentMethod
        self.isRecurring = isRecurring
        self.category = category
        self.tags = tags
        self.items = items
    }
}

/// Data structure for category information
struct CategoryData: Equatable, Hashable {
    let id: UUID
    let name: String
    let icon: String?
    let colorHex: String?
    
    init(id: UUID, name: String, icon: String? = nil, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }
    
    init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.icon = category.icon
        self.colorHex = category.colorHex
    }
}

/// Data structure for tag information
struct TagData: Equatable, Hashable {
    let id: UUID
    let name: String
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
    
    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
    }
}

/// Data structure for expense item information
struct ExpenseItemData {
    let name: String
    let amount: Decimal
    let category: CategoryData?
    
    init(name: String, amount: Decimal, category: CategoryData? = nil) {
        self.name = name
        self.amount = amount
        self.category = category
    }
}

