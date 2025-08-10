//
//  ReceiptScannerExpenseTrackerApp.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Ian Forster (Home) on 2025-07-18.
//

import SwiftUI

@main
struct ReceiptScannerExpenseTrackerApp: App {
    @StateObject private var coreDataManager = CoreDataManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.colorScheme)
                .onAppear {
                    performRecurringExpenseMigration()
                }
        }
    }
    
    /// Perform one-time migration of notes-based recurring expenses to Core Data entities
    private func performRecurringExpenseMigration() {
        let migrationKey = "RecurringExpenseMigrationCompleted"
        let cleanupKey = "RecurringExpenseNotesCleanupCompleted"
        
        // Check if migration has already been performed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            // Check if we need to perform notes cleanup
            if !UserDefaults.standard.bool(forKey: cleanupKey) {
                performNotesCleanupIfNeeded()
            }
            return
        }
        
        let migrationService = RecurringExpenseMigrationService(context: coreDataManager.viewContext)
        let result = migrationService.migrateAllRecurringExpenses()
        
        print("Recurring expense migration completed:")
        print("- Total found: \(result.totalFound)")
        print("- Successfully migrated: \(result.successCount)")
        print("- Skipped: \(result.skippedCount)")
        print("- Failed: \(result.failedCount)")
        
        if result.saveError == nil {
            // Mark migration as completed
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("Migration marked as completed")
            
            // Perform notes cleanup after successful migration
            performNotesCleanupIfNeeded()
        } else {
            print("Migration save error: \(result.saveError?.localizedDescription ?? "Unknown error")")
        }
    }
    
    /// Perform notes cleanup after migration validation
    private func performNotesCleanupIfNeeded() {
        let cleanupKey = "RecurringExpenseNotesCleanupCompleted"
        
        // Check if cleanup has already been performed
        if UserDefaults.standard.bool(forKey: cleanupKey) {
            return
        }
        
        let cleanupService = NotesCleanupService(context: coreDataManager.viewContext)
        let preview = cleanupService.previewCleanup()
        
        // Only perform cleanup if there are expenses to clean
        if preview.expensesToClean.count > 0 {
            print("Notes cleanup needed for \(preview.expensesToClean.count) expenses")
            
            // Perform automatic cleanup (user has already been migrated, so cleanup is safe)
            let result = cleanupService.cleanupRecurringAnnotations()
            
            print("Notes cleanup completed:")
            print("- Total found: \(result.totalFound)")
            print("- Cleaned: \(result.cleanedCount)")
            print("- Skipped: \(result.skippedCount)")
            
            if result.saveError == nil {
                UserDefaults.standard.set(true, forKey: cleanupKey)
                print("Notes cleanup marked as completed")
            } else {
                print("Notes cleanup save error: \(result.saveError?.localizedDescription ?? "Unknown error")")
            }
        } else {
            // No cleanup needed
            UserDefaults.standard.set(true, forKey: cleanupKey)
            print("No notes cleanup needed")
        }
    }
}
