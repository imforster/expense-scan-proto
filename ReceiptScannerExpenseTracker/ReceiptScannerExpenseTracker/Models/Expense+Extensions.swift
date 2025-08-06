import Foundation
import SwiftUI
import CoreData

// MARK: - Expense Extensions for Safe Data Handling
extension Expense: Identifiable {
    
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

    /// Extracts the recurring pattern from the notes, if available
    var recurringPattern: String? {
        guard let notes = self.notes,
              let patternRange = notes.range(of: "\\[Recurring: ([^\\]]+)\\]", options: .regularExpression) else {
            return nil
        }
        
        return String(notes[patternRange])
            .replacingOccurrences(of: "[Recurring: ", with: "")
            .replacingOccurrences(of: "]", with: "")
    }
    
    /// Parsed recurring information from notes
    var recurringInfo: RecurringInfo? {
        guard isRecurring, let notes = self.notes else { return nil }
        return RecurringInfo.parse(from: notes)
    }
    
    /// Sets recurring information in the notes
    func setRecurringInfo(_ info: RecurringInfo) {
        isRecurring = true
        
        // Remove existing recurring info from notes
        var updatedNotes = notes ?? ""
        if let existingRange = updatedNotes.range(of: "\\[Recurring:.*?\\]", options: .regularExpression) {
            updatedNotes.removeSubrange(existingRange)
        }
        
        // Add new recurring info on its own line at the bottom
        let recurringTag = info.toNotesFormat()
        updatedNotes = updatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !updatedNotes.isEmpty {
            updatedNotes += "\n"
        }
        updatedNotes += recurringTag
        
        notes = updatedNotes
    }
    
    /// Calculates the next due date for this recurring expense
    var nextRecurringDate: Date? {
        guard let info = recurringInfo else { return nil }
        return info.calculateNextDate(from: date)
    }
    
    // MARK: - Category Handling
    
    /// Safe category name with fallback
    var safeCategoryName: String {
        return self.category?.name ?? "Uncategorized"
    }
    
    /// Safe category color with fallback
    var safeCategoryColor: Color {
        guard let category = self.category else { return .blue }
        return Color(hex: category.colorHex) ?? .blue
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
// Note: safeName and safeIcon are already defined in Category+CoreDataProperties.swift

// MARK: - Tag Extensions for Safe Data Handling
// Note: safeName is already defined in Tag+CoreDataProperties.swift

// MARK: - ExpenseItem Extensions for Safe Data Handling
// Note: safeName and formattedAmount() are already defined in ExpenseItem+CoreDataProperties.swift

// MARK: - Receipt Extensions for Safe Data Handling
extension Receipt {
    
    // Note: safeMerchantName, formattedTotalAmount() and formattedDate() are already defined in Receipt+CoreDataProperties.swift
    
    /// Safe receipt items array
    var safeReceiptItems: [ReceiptItem] {
        return self.items?.allObjects as? [ReceiptItem] ?? []
    }
    
    // Note: imageURL is already defined in Receipt+CoreDataProperties.swift
}

// MARK: - ReceiptItem Extensions for Safe Data Handling
// Note: safeName and formattedTotalPrice() are already defined in ReceiptItem+CoreDataProperties.swift

// MARK: - NumberFormatter Extension
// Note: Currency formatter is defined in SimpleRecurringSetupView.swift

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

// MARK: - Recurring Expense Support

// RecurringPattern enum is defined in ExpenseEditViewModel.swift

/// Simple structure to hold recurring expense information
struct RecurringInfo {
    let pattern: RecurringPattern
    let interval: Int
    let dayOfMonth: Int?
    
    init(pattern: RecurringPattern, interval: Int = 1, dayOfMonth: Int? = nil) {
        self.pattern = pattern
        self.interval = interval
        self.dayOfMonth = dayOfMonth
    }
    
    /// Parse recurring info from notes format: [Recurring: monthly, interval:1, day:15]
    static func parse(from notes: String) -> RecurringInfo? {
        guard let range = notes.range(of: "\\[Recurring: ([^\\]]+)\\]", options: .regularExpression) else {
            return nil
        }
        
        let content = String(notes[range])
            .replacingOccurrences(of: "[Recurring: ", with: "")
            .replacingOccurrences(of: "]", with: "")
        
        let components = content.components(separatedBy: ", ")
        guard let patternString = components.first,
              let pattern = RecurringPattern(rawValue: patternString.capitalized) else {
            return nil
        }
        
        var interval = 1
        var dayOfMonth: Int? = nil
        
        for component in components.dropFirst() {
            let parts = component.components(separatedBy: ":")
            guard parts.count == 2 else { continue }
            
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "interval":
                interval = Int(value) ?? 1
            case "day":
                dayOfMonth = Int(value)
            default:
                break
            }
        }
        
        return RecurringInfo(pattern: pattern, interval: interval, dayOfMonth: dayOfMonth)
    }
    
    /// Convert to notes format
    func toNotesFormat() -> String {
        var components = [pattern.rawValue.lowercased()]
        
        if interval != 1 {
            components.append("interval:\(interval)")
        }
        
        if let day = dayOfMonth {
            components.append("day:\(day)")
        }
        
        return "[Recurring: \(components.joined(separator: ", "))]"
    }
    
    /// Calculate next date from a given date
    func calculateNextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        switch pattern {
        case .none:
            return date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * interval, to: date) ?? date
        case .monthly:
            if let dayOfMonth = dayOfMonth {
                // Calculate next occurrence of specific day of month
                var components = calendar.dateComponents([.year, .month], from: date)
                components.day = dayOfMonth
                
                if let targetDate = calendar.date(from: components), targetDate > date {
                    return targetDate
                } else {
                    // Move to next month
                    components.month = (components.month ?? 1) + interval
                    return calendar.date(from: components) ?? date
                }
            } else {
                return calendar.date(byAdding: .month, value: interval, to: date) ?? date
            }
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3 * interval, to: date) ?? date
        }
    }
    
    /// Human readable description
    var description: String {
        switch pattern {
        case .none:
            return "Not recurring"
        case .weekly:
            return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case .biweekly:
            return interval == 1 ? "Bi-weekly" : "Every \(interval * 2) weeks"
        case .monthly:
            if let day = dayOfMonth {
                let suffix = ordinalSuffix(for: day)
                return interval == 1 ? "Monthly on the \(day)\(suffix)" : "Every \(interval) months on the \(day)\(suffix)"
            } else {
                return interval == 1 ? "Monthly" : "Every \(interval) months"
            }
        case .quarterly:
            return interval == 1 ? "Quarterly" : "Every \(interval) quarters"
        }
    }
    
    private func ordinalSuffix(for number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }
        
        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
}
