import Foundation
import CoreData

@objc(ReceiptScannerExpenseTrackerRecurringPattern)
public class RecurringPatternEntity: NSManagedObject {
    
    /// Calculate the next date from a given date based on this pattern
    func calculateNextDate(from date: Date) -> Date {
        let calendar = Calendar.current
        
        guard let patternEnum = RecurringFrequency(rawValue: self.patternType) else {
            return date
        }
        
        switch patternEnum {
        case .none:
            return date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: Int(self.interval), to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .weekOfYear, value: 2 * Int(self.interval), to: date) ?? date
        case .monthly:
            if self.dayOfMonth > 0 {
                // Calculate next occurrence of specific day of month
                var components = calendar.dateComponents([.year, .month], from: date)
                components.day = Int(self.dayOfMonth)
                
                if let targetDate = calendar.date(from: components), targetDate > date {
                    return targetDate
                } else {
                    // Move to next month
                    components.month = (components.month ?? 1) + Int(self.interval)
                    return calendar.date(from: components) ?? date
                }
            } else {
                return calendar.date(byAdding: .month, value: Int(self.interval), to: date) ?? date
            }
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3 * Int(self.interval), to: date) ?? date
        }
    }
    
    /// Human readable description of the pattern
    public override var description: String {
        guard let patternEnum = RecurringFrequency(rawValue: self.patternType) else {
            return "Unknown pattern"
        }
        
        switch patternEnum {
        case .none:
            return "Not recurring"
        case .weekly:
            return self.interval == 1 ? "Weekly" : "Every \(self.interval) weeks"
        case .biweekly:
            return self.interval == 1 ? "Bi-weekly" : "Every \(self.interval * 2) weeks"
        case .monthly:
            if self.dayOfMonth > 0 {
                let suffix = ordinalSuffix(for: Int(self.dayOfMonth))
                return self.interval == 1 ? "Monthly on the \(self.dayOfMonth)\(suffix)" : "Every \(self.interval) months on the \(self.dayOfMonth)\(suffix)"
            } else {
                return self.interval == 1 ? "Monthly" : "Every \(self.interval) months"
            }
        case .quarterly:
            return self.interval == 1 ? "Quarterly" : "Every \(self.interval) quarters"
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

/// Enum for recurring pattern types (renamed to avoid conflict with existing enum)
enum RecurringFrequency: String, CaseIterable {
    case none = "None"
    case weekly = "Weekly"
    case biweekly = "Biweekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
}