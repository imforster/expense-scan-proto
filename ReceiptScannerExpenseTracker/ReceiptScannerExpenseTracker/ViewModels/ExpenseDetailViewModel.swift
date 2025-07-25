import Foundation
import CoreData
import SwiftUI
import Combine
import os.log

/// ViewModel for ExpenseDetailView with robust state management and error handling
@MainActor
class ExpenseDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var viewState: ViewState = .loading
    @Published var recoveryInProgress = false
    @Published var recoveryAttempts = 0
    
    // MARK: - State Machine
    enum ViewState: Equatable {
        case loading
        case loaded(Expense)
        case error(ExpenseError)
        case deleted
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading):
                return true
            case (.loaded(let lhsExpense), .loaded(let rhsExpense)):
                return lhsExpense.objectID == rhsExpense.objectID
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            case (.deleted, .deleted):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Private Properties
    private let dataService: ExpenseDataService
    private let expenseID: NSManagedObjectID
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseDetailViewModel")
    private let maxRecoveryAttempts = 3
    private var lastLoadedExpense: Expense? = nil
    
    // MARK: - Initialization
    init(dataService: ExpenseDataService, expenseID: NSManagedObjectID) {
        self.dataService = dataService
        self.expenseID = expenseID
        
        // Listen for expense data changes
        NotificationCenter.default.publisher(for: .expenseDataChanged)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { [weak self] in
                    await self?.refreshExpense()
                }
            }
            .store(in: &cancellables)
        
        // Initial load - but also ensure it's called from the view
        Task {
            await loadExpense()
        }
    }
    
    // MARK: - Public Methods
    
    /// Loads the expense with proper error handling
    func loadExpense() async {
        // Don't reload if already loaded with the same expense
        if case .loaded(let expense) = viewState, expense.objectID == expenseID {
            logger.info("Expense already loaded, skipping reload")
            return
        }
        
        logger.info("Loading expense with ID: \(self.expenseID)")
        viewState = .loading
        
        do {
            // Try to get the expense from the data service
            if let expense = await dataService.getExpense(by: expenseID) {
                if expense.isDeleted {
                    logger.warning("Expense with ID \(self.expenseID) has been deleted")
                    viewState = .deleted
                } else {
                    logger.info("Successfully loaded expense with ID: \(self.expenseID)")
                    lastLoadedExpense = expense
                    viewState = .loaded(expense)
                    recoveryAttempts = 0
                }
            } else {
                logger.warning("Expense with ID \(self.expenseID) not found")
                viewState = .error(.notFound)
            }
        } catch {
            logger.error("Failed to load expense: \(error.localizedDescription)")
            let expenseError = error as? ExpenseError ?? ExpenseErrorFactory.fromCoreDataError(error)
            viewState = .error(expenseError)
            
            // If we have a previously loaded expense, we can use it as a fallback
            if let lastExpense = lastLoadedExpense {
                logger.info("Using cached expense as fallback")
                viewState = .loaded(lastExpense)
            }
        }
    }
    
    /// Refreshes the expense data
    func refreshExpense() async {
        logger.info("Refreshing expense with ID: \(self.expenseID)")
        
        // Don't change the view state to loading during refresh to avoid UI flicker
        let currentState = viewState
        
        do {
            // Try to get the expense from the data service
            if let expense = await dataService.getExpense(by: expenseID) {
                if expense.isDeleted {
                    logger.warning("Expense with ID \(self.expenseID) has been deleted")
                    viewState = .deleted
                } else {
                    logger.info("Successfully refreshed expense with ID: \(self.expenseID)")
                    lastLoadedExpense = expense
                    viewState = .loaded(expense)
                    recoveryAttempts = 0
                }
            } else {
                logger.warning("Expense with ID \(self.expenseID) not found during refresh")
                viewState = .error(.notFound)
            }
        } catch {
            logger.error("Failed to refresh expense: \(error.localizedDescription)")
            
            // Keep the current state if refresh fails
            if case .loaded = currentState {
                // Keep the current loaded state
                logger.info("Keeping current state after failed refresh")
            } else {
                let expenseError = error as? ExpenseError ?? ExpenseErrorFactory.fromCoreDataError(error)
                viewState = .error(expenseError)
            }
        }
    }
    
    /// Deletes the expense with proper error handling
    func deleteExpense() async {
        logger.info("Deleting expense with ID: \(self.expenseID)")
        
        // Only attempt deletion if we have a loaded expense
        guard case .loaded(let expense) = viewState else {
            logger.warning("Cannot delete expense: No expense is loaded")
            return
        }
        
        do {
            try await dataService.deleteExpense(expense)
            logger.info("Successfully deleted expense with ID: \(self.expenseID)")
            viewState = .deleted
            lastLoadedExpense = nil
            
            // Post notification that expense was deleted
            NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        } catch {
            logger.error("Failed to delete expense: \(error.localizedDescription)")
            let expenseError = error as? ExpenseError ?? ExpenseErrorFactory.fromCoreDataError(error)
            viewState = .error(expenseError)
        }
    }
    
    /// Attempts to recover from an error state
    func recoverFromError() async {
        guard case .error(let error) = viewState else {
            logger.warning("Cannot recover: Not in error state")
            return
        }
        
        logger.info("Attempting to recover from error: \(error.localizedDescription)")
        recoveryInProgress = true
        recoveryAttempts += 1
        
        // Different recovery strategies based on error type
        switch error {
        case .notFound:
            // If the expense is not found, we can't recover
            logger.warning("Cannot recover from not found error")
            recoveryInProgress = false
            
        case .loadingFailed, .coreDataError:
            // For loading or CoreData errors, try to load again
            if self.recoveryAttempts <= self.maxRecoveryAttempts {
                logger.info("Retrying load (attempt \(self.recoveryAttempts)/\(self.maxRecoveryAttempts))")
                await loadExpense()
            } else {
                logger.warning("Max recovery attempts reached")
                recoveryInProgress = false
            }
            
        case .networkError:
            // For network errors, try to load from cache first
            if let lastExpense = lastLoadedExpense {
                logger.info("Using cached expense for network error recovery")
                viewState = .loaded(lastExpense)
                recoveryInProgress = false
            } else {
                // If no cache, try to load again
                if self.recoveryAttempts <= self.maxRecoveryAttempts {
                    logger.info("Retrying load after network error (attempt \(self.recoveryAttempts)/\(self.maxRecoveryAttempts))")
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    await loadExpense()
                } else {
                    logger.warning("Max recovery attempts reached")
                    recoveryInProgress = false
                }
            }
            
        default:
            // For other errors, just try to load again
            if self.recoveryAttempts <= self.maxRecoveryAttempts {
                logger.info("Retrying load for general error (attempt \(self.recoveryAttempts)/\(self.maxRecoveryAttempts))")
                await loadExpense()
            } else {
                logger.warning("Max recovery attempts reached")
                recoveryInProgress = false
            }
        }
    }
    
    /// Provides a user-friendly error message with recovery steps
    func userFriendlyErrorMessage() -> String {
        guard case .error(let error) = viewState else {
            return "Unknown error"
        }
        
        return error.errorDescription ?? "An error occurred"
    }
    
    /// Provides recovery suggestion for the current error
    func recoverySuggestion() -> String {
        guard case .error(let error) = viewState else {
            return ""
        }
        
        return error.recoverySuggestion ?? "Please try again"
    }
    
    /// Returns true if the current error is recoverable
    func isErrorRecoverable() -> Bool {
        guard case .error(let error) = viewState else {
            return false
        }
        
        return error.isRecoverable && recoveryAttempts < maxRecoveryAttempts
    }
    
    // MARK: - Helper Methods
    
    /// Returns the current expense if available
    var expense: Expense? {
        if case .loaded(let expense) = viewState {
            return expense
        }
        return nil
    }
    
    /// Returns true if the view is in a loading state
    var isLoading: Bool {
        if case .loading = viewState {
            return true
        }
        return false
    }
    
    /// Returns the current error if in an error state
    var error: ExpenseError? {
        if case .error(let error) = viewState {
            return error
        }
        return nil
    }
    
    /// Returns true if the expense has been deleted
    var isDeleted: Bool {
        if case .deleted = viewState {
            return true
        }
        return false
    }
    
    // MARK: - Cleanup
    
    deinit {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        logger.info("ExpenseDetailViewModel deinit")
    }
}