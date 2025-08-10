//
//  NotesCleanupService.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Kiro on 8/9/25.
//

import Foundation
import CoreData

/// Service for cleaning up recurring-related annotations from expense notes after migration
class NotesCleanupService {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Cleanup Operations
    
    /// Clean up all recurring-related annotations from migrated expenses
    func cleanupRecurringAnnotations() -> CleanupResult {
        let expensesWithRecurringNotes = findExpensesWithRecurringAnnotations()
        
        var result = CleanupResult()
        result.totalFound = expensesWithRecurringNotes.count
        
        for expense in expensesWithRecurringNotes {
            let originalNotes = expense.notes
            let cleanedNotes = cleanRecurringAnnotations(from: expense.notes)
            
            if cleanedNotes != originalNotes {
                expense.notes = cleanedNotes
                result.cleanedExpenses.append(CleanedExpense(
                    expense: expense,
                    originalNotes: originalNotes,
                    cleanedNotes: cleanedNotes
                ))
            } else {
                result.skippedExpenses.append(expense)
            }
        }
        
        // Save changes if we have cleaned expenses
        if !result.cleanedExpenses.isEmpty {
            do {
                try context.save()
                print("Notes cleanup completed successfully. Cleaned \(result.cleanedExpenses.count) expenses.")
            } catch {
                print("Error saving notes cleanup changes: \(error)")
                result.saveError = error
            }
        }
        
        return result
    }
    
    /// Preview what would be cleaned without making changes
    func previewCleanup() -> CleanupPreview {
        let expensesWithRecurringNotes = findExpensesWithRecurringAnnotations()
        
        var preview = CleanupPreview()
        preview.totalExpenses = expensesWithRecurringNotes.count
        
        for expense in expensesWithRecurringNotes {
            let originalNotes = expense.notes
            let cleanedNotes = cleanRecurringAnnotations(from: expense.notes)
            
            if cleanedNotes != originalNotes {
                preview.expensesToClean.append(CleanupPreviewItem(
                    expenseId: expense.id,
                    merchant: expense.merchant,
                    originalNotes: originalNotes,
                    cleanedNotes: cleanedNotes
                ))
            }
        }
        
        return preview
    }
    
    // MARK: - Helper Methods
    
    /// Find all expenses that still have recurring-related annotations in their notes
    private func findExpensesWithRecurringAnnotations() -> [Expense] {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "notes CONTAINS '[Recurring:' OR notes CONTAINS '[Reminder:' OR notes CONTAINS '[AutoCreate:'")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching expenses with recurring annotations: \(error)")
            return []
        }
    }
    
    /// Remove all recurring-related annotations from a notes string
    private func cleanRecurringAnnotations(from notes: String?) -> String? {
        guard let notes = notes else { return nil }
        
        var cleanedNotes = notes
        
        // Remove recurring pattern annotations
        cleanedNotes = cleanedNotes.replacingOccurrences(
            of: "\\n?\\[Recurring:.*?\\]",
            with: "",
            options: .regularExpression
        )
        
        // Remove reminder annotations
        cleanedNotes = cleanedNotes.replacingOccurrences(
            of: "\\n?\\[Reminder: \\d+ days?\\]",
            with: "",
            options: .regularExpression
        )
        
        // Remove auto-create annotations
        cleanedNotes = cleanedNotes.replacingOccurrences(
            of: "\\n?\\[AutoCreate: (true|false)\\]",
            with: "",
            options: .regularExpression
        )
        
        // Remove "Generated from recurring expense" annotations
        cleanedNotes = cleanedNotes.replacingOccurrences(
            of: "Generated from recurring expense\\.\\s*",
            with: "",
            options: .regularExpression
        )
        
        // Clean up extra whitespace and newlines
        cleanedNotes = cleanedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleanedNotes.isEmpty ? nil : cleanedNotes
    }
    
    // MARK: - Validation
    
    /// Validate that cleanup was successful
    func validateCleanup() -> CleanupValidationResult {
        var result = CleanupValidationResult()
        
        // Check for remaining recurring annotations
        let remainingAnnotatedExpenses = findExpensesWithRecurringAnnotations()
        result.remainingAnnotatedExpenses = remainingAnnotatedExpenses.count
        
        // Check for expenses that might have been over-cleaned (empty notes when they shouldn't be)
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "notes == nil AND recurringTemplate != nil")
        
        do {
            let potentiallyOverCleaned = try context.fetch(request)
            result.potentiallyOverCleanedExpenses = potentiallyOverCleaned.count
        } catch {
            result.validationErrors.append("Error checking for over-cleaned expenses: \(error)")
        }
        
        result.isValid = result.remainingAnnotatedExpenses == 0 && 
                        result.validationErrors.isEmpty
        
        return result
    }
}

// MARK: - Result Types

struct CleanupResult {
    var totalFound: Int = 0
    var cleanedExpenses: [CleanedExpense] = []
    var skippedExpenses: [Expense] = []
    var saveError: Error?
    
    var cleanedCount: Int { cleanedExpenses.count }
    var skippedCount: Int { skippedExpenses.count }
}

struct CleanedExpense {
    let expense: Expense
    let originalNotes: String?
    let cleanedNotes: String?
}

struct CleanupPreview {
    var totalExpenses: Int = 0
    var expensesToClean: [CleanupPreviewItem] = []
}

struct CleanupPreviewItem {
    let expenseId: UUID
    let merchant: String
    let originalNotes: String?
    let cleanedNotes: String?
}

struct CleanupValidationResult {
    var isValid: Bool = false
    var remainingAnnotatedExpenses: Int = 0
    var potentiallyOverCleanedExpenses: Int = 0
    var validationErrors: [String] = []
}