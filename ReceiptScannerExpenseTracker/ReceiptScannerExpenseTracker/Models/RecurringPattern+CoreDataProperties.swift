import Foundation
import CoreData

extension RecurringPatternEntity {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecurringPatternEntity> {
        return NSFetchRequest<RecurringPatternEntity>(entityName: "RecurringPattern")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var patternType: String
    @NSManaged public var interval: Int32
    @NSManaged public var dayOfMonth: Int32
    @NSManaged public var dayOfWeek: Int32
    @NSManaged public var nextDueDate: Date
    @NSManaged public var recurringExpense: RecurringExpense?
}