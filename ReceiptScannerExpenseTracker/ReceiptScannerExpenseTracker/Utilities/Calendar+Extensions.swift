import Foundation

extension Calendar {
    /// Returns true if the given date is on a weekend.
    func isWeekend(_ date: Date) -> Bool {
        return isDateInWeekend(date)
    }
}
