import Foundation
import CoreData

/// Service for migrating existing notes-based recurring expenses to proper Core Data entities
class RecurringExpenseMigrationService {
    private let context: NSManagedObjectContext
    private let recurringExpenseService: RecurringExpenseService
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.recurringExpenseService = RecurringExpenseService(context: context)
    }
    
    // MARK: - Migration Operations
    
    /// Migrate all existing notes-based recurring expenses to new Core Data entities
    func migrateAllRecurringExpenses() -> MigrationResult {
        let existingRecurringExpenses = findNotesBasedRecurringExpenses()
        
        var migrationResult = MigrationResult()
        migrationResult.totalFound = existingRecurringExpenses.count
        
        for expense in existingRecurringExpenses {
            do {
                let result = try migrateExpense(expense)
                switch result {
                case .success(let recurringExpense):
                    migrationResult.successfulMigrations.append(MigratedExpense(
                        originalExpense: expense,
                        newRecurringExpense: recurringExpense
                    ))
                case .skipped(let reason):
                    migrationResult.skippedMigrations.append(SkippedMigration(
                        expense: expense,
                        reason: reason
                    ))
                case .failed(let error):
                    migrationResult.failedMigrations.append(FailedMigration(
                        expense: expense,
                        error: error
                    ))
                }
            } catch {
                migrationResult.failedMigrations.append(FailedMigration(
                    expense: expense,
                    error: error
                ))
            }
        }
        
        // Save changes if we have successful migrations
        if !migrationResult.successfulMigrations.isEmpty {
            do {
                try context.save()
                print("Migration completed successfully. Migrated \(migrationResult.successfulMigrations.count) recurring expenses.")
            } catch {
                print("Error saving migration changes: \(error)")
                migrationResult.saveError = error
            }
        }
        
        return migrationResult
    }
    
    /// Migrate a single expense from notes-based to Core Data entity
    private func migrateExpense(_ expense: Expense) throws -> MigrationResult.ExpenseResult {
        // Since RecurringInfo and RecurringPattern are no longer available, skip migration
        return .skipped("RecurringPattern migration not supported in current implementation")

    }
    
    // MARK: - Helper Methods
    
    /// Find all expenses that use notes-based recurring info
    private func findNotesBasedRecurringExpenses() -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isRecurring == YES AND notes CONTAINS '[Recurring:'")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching notes-based recurring expenses: \(error)")
            return []
        }
    }
    

    
    /// Remove recurring info from notes string
    private func cleanNotesFromRecurringInfo(_ notes: String?) -> String? {
        guard let notes = notes else { return nil }
        
        let cleanedNotes = notes.replacingOccurrences(
            of: "\\[Recurring:.*?\\]",
            with: "",
            options: .regularExpression
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedNotes.isEmpty ? nil : cleanedNotes
    }
    
    // MARK: - Validation
    
    /// Validate that migration was successful
    func validateMigration() -> ValidationResult {
        var result = ValidationResult()
        
        // Check for remaining notes-based recurring expenses
        let remainingNotesBasedExpenses = findNotesBasedRecurringExpenses()
        result.remainingNotesBasedExpenses = remainingNotesBasedExpenses.count
        
        // Check for orphaned recurring expenses (no generated expenses)
        let allRecurringExpenses = recurringExpenseService.getActiveRecurringExpenses()
        result.totalRecurringExpenses = allRecurringExpenses.count
        
        let orphanedRecurringExpenses = allRecurringExpenses.filter { $0.safeGeneratedExpenses.isEmpty }
        result.orphanedRecurringExpenses = orphanedRecurringExpenses.count
        
        // Check for expenses with both old and new recurring info
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "isRecurring == YES AND recurringTemplate != nil")
        
        do {
            let conflictingExpenses = try context.fetch(request)
            result.conflictingExpenses = conflictingExpenses.count
        } catch {
            result.validationErrors.append("Error checking for conflicting expenses: \(error)")
        }
        
        result.isValid = result.remainingNotesBasedExpenses == 0 && 
                        result.conflictingExpenses == 0 &&
                        result.validationErrors.isEmpty
        
        return result
    }
}

// MARK: - Migration Result Types

struct MigrationResult {
    var totalFound: Int = 0
    var successfulMigrations: [MigratedExpense] = []
    var skippedMigrations: [SkippedMigration] = []
    var failedMigrations: [FailedMigration] = []
    var saveError: Error?
    
    var successCount: Int { successfulMigrations.count }
    var skippedCount: Int { skippedMigrations.count }
    var failedCount: Int { failedMigrations.count }
    
    enum ExpenseResult {
        case success(RecurringExpense)
        case skipped(String)
        case failed(Error)
    }
}

struct MigratedExpense {
    let originalExpense: Expense
    let newRecurringExpense: RecurringExpense
}

struct SkippedMigration {
    let expense: Expense
    let reason: String
}

struct FailedMigration {
    let expense: Expense
    let error: Error
}

struct ValidationResult {
    var isValid: Bool = false
    var remainingNotesBasedExpenses: Int = 0
    var totalRecurringExpenses: Int = 0
    var orphanedRecurringExpenses: Int = 0
    var conflictingExpenses: Int = 0
    var validationErrors: [String] = []
}