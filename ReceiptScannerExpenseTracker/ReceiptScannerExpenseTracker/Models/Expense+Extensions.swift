import Foundation
import SwiftUI
import CoreData

// MARK: - Expense Extensions for Safe Data Handling
extension Expense {
    
    // MARK: - Safe Property Access
    
    // Note: formattedAmount() and formattedDate() are already defined in Expense+CoreDataProperties.swift
    
    /// Safe merchant name with fallback
    var safeMerchant: String {
        return self.merchant
    }
    
    /// Safe notes with fallback
    var safeNotes: String {
        return self.notes ?? ""
    }
    
    /// Safe payment method with fallback
    var safePaymentMethod: String {
        return self.paymentMethod ?? "Unknown"
    }
    
    // MARK: - Category Handling
    
    /// Safe category name with fallback
    var safeCategoryName: String {
        return self.category?.name ?? "Uncategorized"
    }
    
    /// Safe category color with fallback
    var safeCategoryColor: Color {
        return self.category?.color ?? .blue
    }
    
    /// Safe category icon with fallback
    var safeCategoryIcon: String {
        return self.category?.icon ?? "questionmark.circle"
    }
    
    // MARK: - Collection Handling
    
    /// Safe expense items array
    var safeExpenseItems: [ExpenseItem] {
        return self.items?.allObjects as? [ExpenseItem] ?? []
    }
    
    /// Safe tags array
    var safeTags: [Tag] {
        return self.tags?.allObjects as? [Tag] ?? []
    }
    
    // MARK: - Sample Data Creation
    
    // Note: createSampleExpense(context:) is already defined in Expense+CoreDataProperties.swift
}

// MARK: - Category Extensions for Safe Data Handling
extension Category {
    
    /// Safe category name with fallback
    var safeName: String {
        return self.name
    }
    
    /// Safe category icon with fallback
    var safeIcon: String {
        return self.icon
    }
}

// MARK: - Tag Extensions for Safe Data Handling
extension Tag {
    
    /// Safe tag name with fallback
    var safeName: String {
        return self.name
    }
}

// MARK: - ExpenseItem Extensions for Safe Data Handling
extension ExpenseItem {
    
    /// Safe item name with fallback
    var safeName: String {
        return self.name
    }
    
    // Note: formattedAmount() is already defined in ExpenseItem+CoreDataProperties.swift
}

// MARK: - Receipt Extensions for Safe Data Handling
extension Receipt {
    
    /// Safe merchant name with fallback
    var safeMerchantName: String {
        return self.merchantName
    }
    
    // Note: formattedTotalAmount() and formattedDate() are already defined in Receipt+CoreDataProperties.swift
    
    /// Safe receipt items array
    var safeReceiptItems: [ReceiptItem] {
        return self.items?.allObjects as? [ReceiptItem] ?? []
    }
    
    // Note: imageURL is already defined in Receipt+CoreDataProperties.swift
}

// MARK: - ReceiptItem Extensions for Safe Data Handling
extension ReceiptItem {
    
    /// Safe item name with fallback
    var safeName: String {
        return self.name
    }
    
    // Note: formattedTotalPrice() is already defined in ReceiptItem+CoreDataProperties.swift
}

// MARK: - NumberFormatter Extension
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter
    }()
}

// MARK: - Expense Context Enum
enum ExpenseContext: String, CaseIterable {
    case business = "Business"
    case personal = "Personal"
    case reimbursable = "Reimbursable"
    case tax = "Tax Deductible"
    case subscription = "Subscription"
    
    var color: Color {
        switch self {
        case .business:
            return .blue
        case .personal:
            return .green
        case .reimbursable:
            return .orange
        case .tax:
            return .purple
        case .subscription:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .business:
            return "briefcase"
        case .personal:
            return "person"
        case .reimbursable:
            return "arrow.counterclockwise"
        case .tax:
            return "doc.text"
        case .subscription:
            return "repeat"
        }
    }
}
