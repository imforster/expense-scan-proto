import Foundation

/// Data transfer object for expense creation and updates
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
        date: Date = Date(),
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

/// Data transfer object for category information
struct CategoryData: Equatable, Hashable {
    let id: UUID
    let name: String
    let colorHex: String?
    let icon: String?
    
    init(id: UUID, name: String, colorHex: String? = nil, icon: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
    }
}

/// Data transfer object for tag information
struct TagData: Equatable, Hashable {
    let id: UUID
    let name: String
    
    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

/// Data transfer object for expense item information
struct ExpenseItemData {
    let name: String
    let amount: Decimal
    
    init(name: String, amount: Decimal) {
        self.name = name
        self.amount = amount
    }
}

// MARK: - Convenience Extensions

extension ExpenseData {
    /// Creates ExpenseData from an existing Expense entity
    init(from expense: Expense) {
        self.amount = expense.amount.decimalValue
        self.merchant = expense.merchant
        self.date = expense.date
        self.notes = expense.notes
        self.paymentMethod = expense.paymentMethod
        self.isRecurring = expense.isRecurring
        
        // Convert category
        if let category = expense.category {
            self.category = CategoryData(
                id: category.id,
                name: category.name,
                colorHex: category.colorHex,
                icon: category.icon
            )
        } else {
            self.category = nil
        }
        
        // Convert tags
        if let tags = expense.tags as? Set<Tag> {
            self.tags = tags.map { TagData(id: $0.id, name: $0.name) }
        } else {
            self.tags = []
        }
        
        // Convert items
        if let items = expense.items as? Set<ExpenseItem> {
            self.items = items.map { 
                ExpenseItemData(
                    name: $0.name,
                    amount: $0.amount.decimalValue
                )
            }
        } else {
            self.items = []
        }
    }
}

extension CategoryData {
    /// Creates CategoryData from an existing Category entity
    init(from category: Category) {
        self.id = category.id
        self.name = category.name
        self.colorHex = category.colorHex
        self.icon = category.icon
    }
}

extension TagData {
    /// Creates TagData from an existing Tag entity
    init(from tag: Tag) {
        self.id = tag.id
        self.name = tag.name
    }
}

extension ExpenseItemData {
    /// Creates ExpenseItemData from an existing ExpenseItem entity
    init(from item: ExpenseItem) {
        self.name = item.name
        self.amount = item.amount.decimalValue
    }
}