import Foundation
import CoreData

// MARK: - Recurring Template Types

/// Information about a recurring template relationship
struct RecurringTemplateInfo {
    let templateId: UUID
    let patternDescription: String
    let nextDueDate: Date?
    let isActive: Bool
    let lastGeneratedDate: Date?
    let totalGeneratedExpenses: Int
}

/// Enum representing different types of template changes
enum TemplateChangeType {
    case amount(from: NSDecimalNumber, to: NSDecimalNumber)
    case merchant(from: String, to: String)
    case category(from: Category?, to: Category?)
    case notes(from: String?, to: String?)
    case paymentMethod(from: String?, to: String?)
    case currency(from: String, to: String)
    case tags(from: [ReceiptScannerExpenseTracker.Tag], to: [ReceiptScannerExpenseTracker.Tag])
    
    /// Get a string key for grouping changes by type
    var changeTypeKey: String {
        switch self {
        case .amount: return "amount"
        case .merchant: return "merchant"
        case .category: return "category"
        case .notes: return "notes"
        case .paymentMethod: return "paymentMethod"
        case .currency: return "currency"
        case .tags: return "tags"
        }
    }
}

/// Enum for template update behavior preferences
enum TemplateUpdateBehavior: String, CaseIterable {
    case alwaysAsk = "alwaysAsk"
    case alwaysUpdateTemplate = "alwaysUpdateTemplate"
    case alwaysUpdateExpenseOnly = "alwaysUpdateExpenseOnly"
    
    var displayName: String {
        switch self {
        case .alwaysAsk:
            return "Always Ask"
        case .alwaysUpdateTemplate:
            return "Always Update Template"
        case .alwaysUpdateExpenseOnly:
            return "Always Update Expense Only"
        }
    }
    
    var description: String {
        switch self {
        case .alwaysAsk:
            return "Ask me each time what to do"
        case .alwaysUpdateTemplate:
            return "Automatically update the recurring template"
        case .alwaysUpdateExpenseOnly:
            return "Only update this expense, never the template"
        }
    }
}

/// Enum representing the user's choice for template updates
enum TemplateUpdateChoice {
    case updateTemplate
    case updateExpenseOnly
    case cancel
}