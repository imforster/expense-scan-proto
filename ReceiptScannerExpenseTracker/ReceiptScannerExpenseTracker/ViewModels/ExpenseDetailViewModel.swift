import Foundation
import CoreData
import SwiftUI
import Combine

class ExpenseDetailViewModel: ObservableObject {
    @Published var expense: Expense?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let context: NSManagedObjectContext
    private let expenseID: NSManagedObjectID
    
    init(context: NSManagedObjectContext, expenseID: NSManagedObjectID) {
        self.context = context
        self.expenseID = expenseID
        
        // Listen for expense data changes
        NotificationCenter.default.publisher(for: .expenseDataChanged)
            .sink { [weak self] _ in
                self?.loadExpense()
            }
            .store(in: &cancellables)
        
        // Initial load
        loadExpense()
    }
    
    func loadExpense() {
        isLoading = true
        
        // First try to load synchronously for immediate display
        do {
            if let loadedExpense = try context.existingObject(with: expenseID) as? Expense,
               !loadedExpense.isDeleted {
                self.expense = loadedExpense
                self.isLoading = false
                return
            }
        } catch {
            // If synchronous load fails, we'll try asynchronously
            print("Synchronous expense load failed, trying async: \(error)")
        }
        
        // Use a background task as fallback
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Get the expense from the context using its ID
                if let loadedExpense = try self.context.existingObject(with: self.expenseID) as? Expense,
                   !loadedExpense.isDeleted {
                    
                    // Update on the main thread
                    DispatchQueue.main.async {
                        self.expense = loadedExpense
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.expense = nil
                        self.errorMessage = "Expense not found or has been deleted."
                        self.isLoading = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.expense = nil
                    self.errorMessage = "Error loading expense: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func refreshData() {
        // Refresh the context
        context.refreshAllObjects()
        
        // Reload the expense
        loadExpense()
    }
}