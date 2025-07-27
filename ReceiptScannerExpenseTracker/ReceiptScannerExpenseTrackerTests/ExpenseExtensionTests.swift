
import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

class ExpenseExtensionTests: XCTestCase {

    var viewContext: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        viewContext = PersistenceController.preview.container.viewContext
    }

    override func tearDownWithError() throws {
        viewContext = nil
        try super.tearDownWithError()
    }

    func testRecurringPattern_WhenPatternExists() {
        // Given
        let expense = Expense(context: viewContext)
        expense.notes = "Some notes here [Recurring: Monthly] and some other notes."

        // When
        let pattern = expense.recurringPattern

        // Then
        XCTAssertEqual(pattern, "Monthly", "The recurring pattern should be correctly extracted.")
    }

    func testRecurringPattern_WhenNoPatternExists() {
        // Given
        let expense = Expense(context: viewContext)
        expense.notes = "This is a regular expense with no recurring information."

        // When
        let pattern = expense.recurringPattern

        // Then
        XCTAssertNil(pattern, "The recurring pattern should be nil when no pattern is present.")
    }

    func testRecurringPattern_WhenNotesAreNil() {
        // Given
        let expense = Expense(context: viewContext)
        expense.notes = nil

        // When
        let pattern = expense.recurringPattern

        // Then
        XCTAssertNil(pattern, "The recurring pattern should be nil when notes are nil.")
    }
    
    func testRecurringPattern_WhenPatternIsComplex() {
        // Given
        let expense = Expense(context: viewContext)
        expense.notes = "This is a complex note [Recurring: Bi-weekly on Fridays] with other details."

        // When
        let pattern = expense.recurringPattern

        // Then
        XCTAssertEqual(pattern, "Bi-weekly on Fridays", "The recurring pattern should handle complex strings.")
    }
}
