import Foundation
import CoreData
import Combine
import os.log

/// Centralized data service for managing expense operations with automatic UI updates
@MainActor
class ExpenseDataService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var expenses: [Expense] = []
    @Published var isLoading = false
    @Published var error: ExpenseError?
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseDataService")
    private var retryAttempts: [String: Int] = [:]
    private let maxRetryAttempts = 3
    private lazy var fetchedResultsController: NSFetchedResultsController<Expense> = {
        let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \Expense.date, ascending: false),
            NSSortDescriptor(keyPath: \Expense.merchant, ascending: true)
        ]
        
        let controller = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: "ExpenseCache"
        )
        
        controller.delegate = self
        return controller
    }()
    
    // MARK: - Initialization
    init(context: NSManagedObjectContext = CoreDataManager.shared.viewContext) {
        self.context = context
        self.backgroundContext = CoreDataManager.shared.createBackgroundContext()
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Loads expenses using NSFetchedResultsController with background processing
    func loadExpenses() async {
        let operationId = "loadExpenses"
        isLoading = true
        error = nil
        
        logger.info("Starting to load expenses")
        
        do {
            try fetchedResultsController.performFetch()
            await MainActor.run {
                self.expenses = fetchedResultsController.fetchedObjects ?? []
                self.isLoading = false
                self.retryAttempts[operationId] = 0
                self.logger.info("Successfully loaded \(self.expenses.count) expenses")
            }
        } catch {
            logger.error("Failed to load expenses: \(error.localizedDescription)")
            
            let expenseError = ExpenseErrorFactory.fromCoreDataError(error)
            
            // Implement retry logic for recoverable errors
            if await shouldRetryOperation(operationId, error: expenseError) {
                logger.info("Retrying load expenses operation")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                await loadExpenses()
                return
            }
            
            await MainActor.run {
                self.error = expenseError
                self.isLoading = false
            }
        }
    }
    
    /// Creates a new expense with proper error handling
    /// - Parameter expenseData: The data for the new expense
    /// - Returns: The created expense
    /// - Throws: ExpenseError if creation fails
    func createExpense(_ expenseData: ExpenseData) async throws -> Expense {
        // Validate input data first
        if let validationError = ExpenseErrorFactory.validateExpenseData(expenseData) {
            logger.error("Expense validation failed: \(validationError.localizedDescription)")
            throw validationError
        }
        
        logger.info("Creating new expense for merchant: \(expenseData.merchant)")
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    let expense = Expense(context: self.backgroundContext)
                    expense.id = UUID()
                    expense.amount = NSDecimalNumber(decimal: expenseData.amount)
                    expense.merchant = expenseData.merchant
                    expense.date = expenseData.date
                    expense.notes = expenseData.notes
                    expense.paymentMethod = expenseData.paymentMethod
                    expense.isRecurring = expenseData.isRecurring
                    
                    // Handle category relationship
                    if let categoryData = expenseData.category {
                        let categoryFetch: NSFetchRequest<Category> = Category.fetchRequest()
                        categoryFetch.predicate = NSPredicate(format: "id == %@", categoryData.id as CVarArg)
                        
                        if let category = try self.backgroundContext.fetch(categoryFetch).first {
                            expense.category = category
                        }
                    }
                    
                    // Handle tags relationship
                    for tagData in expenseData.tags {
                        let tagFetch: NSFetchRequest<Tag> = Tag.fetchRequest()
                        tagFetch.predicate = NSPredicate(format: "id == %@", tagData.id as CVarArg)
                        
                        if let tag = try self.backgroundContext.fetch(tagFetch).first {
                            expense.addToTags(tag)
                        }
                    }
                    
                    // Handle expense items
                    for itemData in expenseData.items {
                        let expenseItem = ExpenseItem(context: self.backgroundContext)
                        expenseItem.id = UUID()
                        expenseItem.name = itemData.name
                        expenseItem.amount = NSDecimalNumber(decimal: itemData.amount)
                        expense.addToItems(expenseItem)
                    }
                    
                    try self.backgroundContext.save()
                    
                    // Get the object ID to pass back to main context
                    let objectID = expense.objectID
                    
                    self.logger.info("Successfully created expense with ID: \(objectID)")
                    
                    DispatchQueue.main.async {
                        do {
                            let mainContextExpense = try self.context.existingObject(with: objectID) as! Expense
                            continuation.resume(returning: mainContextExpense)
                        } catch {
                            self.logger.error("Failed to retrieve created expense in main context: \(error.localizedDescription)")
                            continuation.resume(throwing: ExpenseErrorFactory.fromCoreDataError(error))
                        }
                    }
                    
                } catch {
                    self.logger.error("Failed to create expense: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        continuation.resume(throwing: ExpenseErrorFactory.fromCoreDataError(error))
                    }
                }
            }
        }
    }
    
    /// Updates an existing expense with proper error handling
    /// - Parameters:
    ///   - expense: The expense to update
    ///   - expenseData: The new data for the expense
    /// - Throws: ExpenseError if update fails
    func updateExpense(_ expense: Expense, with expenseData: ExpenseData) async throws {
        // Validate input data first
        if let validationError = ExpenseErrorFactory.validateExpenseData(expenseData) {
            logger.error("Expense update validation failed: \(validationError.localizedDescription)")
            throw validationError
        }
        
        let objectID = expense.objectID
        logger.info("Updating expense with ID: \(objectID)")
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    guard let backgroundExpense = try? self.backgroundContext.existingObject(with: objectID) as? Expense else {
                        DispatchQueue.main.async {
                            continuation.resume(throwing: ExpenseError.notFound)
                        }
                        return
                    }
                    
                    // Update properties
                    backgroundExpense.amount = NSDecimalNumber(decimal: expenseData.amount)
                    backgroundExpense.merchant = expenseData.merchant
                    backgroundExpense.date = expenseData.date
                    backgroundExpense.notes = expenseData.notes
                    backgroundExpense.paymentMethod = expenseData.paymentMethod
                    backgroundExpense.isRecurring = expenseData.isRecurring
                    
                    // Update category relationship
                    if let categoryData = expenseData.category {
                        let categoryFetch: NSFetchRequest<Category> = Category.fetchRequest()
                        categoryFetch.predicate = NSPredicate(format: "id == %@", categoryData.id as CVarArg)
                        
                        if let category = try self.backgroundContext.fetch(categoryFetch).first {
                            backgroundExpense.category = category
                        }
                    } else {
                        backgroundExpense.category = nil
                    }
                    
                    // Update tags relationship
                    backgroundExpense.removeFromTags(backgroundExpense.tags ?? NSSet())
                    for tagData in expenseData.tags {
                        let tagFetch: NSFetchRequest<Tag> = Tag.fetchRequest()
                        tagFetch.predicate = NSPredicate(format: "id == %@", tagData.id as CVarArg)
                        
                        if let tag = try self.backgroundContext.fetch(tagFetch).first {
                            backgroundExpense.addToTags(tag)
                        }
                    }
                    
                    // Update expense items
                    backgroundExpense.removeFromItems(backgroundExpense.items ?? NSSet())
                    for itemData in expenseData.items {
                        let expenseItem = ExpenseItem(context: self.backgroundContext)
                        expenseItem.id = UUID()
                        expenseItem.name = itemData.name
                        expenseItem.amount = NSDecimalNumber(decimal: itemData.amount)
                        backgroundExpense.addToItems(expenseItem)
                    }
                    
                    try self.backgroundContext.save()
                    
                    self.logger.info("Successfully updated expense with ID: \(objectID)")
                    
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                    
                } catch {
                    self.logger.error("Failed to update expense: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        continuation.resume(throwing: ExpenseErrorFactory.fromCoreDataError(error))
                    }
                }
            }
        }
    }
    
    /// Deletes an expense with proper error handling
    /// - Parameter expense: The expense to delete
    /// - Throws: ExpenseError if deletion fails
    func deleteExpense(_ expense: Expense) async throws {
        let objectID = expense.objectID
        logger.info("Deleting expense with ID: \(objectID)")
        
        return try await withCheckedThrowingContinuation { continuation in
            backgroundContext.perform {
                do {
                    guard let backgroundExpense = try? self.backgroundContext.existingObject(with: objectID) as? Expense else {
                        DispatchQueue.main.async {
                            continuation.resume(throwing: ExpenseError.notFound)
                        }
                        return
                    }
                    
                    self.backgroundContext.delete(backgroundExpense)
                    try self.backgroundContext.save()
                    
                    self.logger.info("Successfully deleted expense with ID: \(objectID)")
                    
                    DispatchQueue.main.async {
                        continuation.resume()
                    }
                    
                } catch {
                    self.logger.error("Failed to delete expense: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        continuation.resume(throwing: ExpenseErrorFactory.fromCoreDataError(error))
                    }
                }
            }
        }
    }
    
    /// Safely retrieves an expense by its object ID
    /// - Parameter id: The NSManagedObjectID of the expense
    /// - Returns: The expense if found, nil otherwise
    func getExpense(by id: NSManagedObjectID) async -> Expense? {
        return await withCheckedContinuation { continuation in
            context.perform {
                do {
                    let expense = try self.context.existingObject(with: id) as? Expense
                    continuation.resume(returning: expense)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Refreshes the expense data from the persistent store
    func refreshExpenses() async {
        await loadExpenses()
    }
    
    // MARK: - Error Recovery and Retry Logic
    
    /// Determines if an operation should be retried based on error type and attempt count
    private func shouldRetryOperation(_ operationId: String, error: ExpenseError) async -> Bool {
        let currentAttempts = retryAttempts[operationId] ?? 0
        
        guard currentAttempts < maxRetryAttempts && error.shouldRetry else {
            return false
        }
        
        retryAttempts[operationId] = currentAttempts + 1
        return true
    }
    
    /// Implements fallback mechanism for failed operations
    private func handleOperationFailure(_ operationId: String, error: ExpenseError) async {
        logger.error("Operation \(operationId) failed with error: \(error.localizedDescription)")
        
        // Reset retry counter
        retryAttempts[operationId] = 0
        
        // Implement fallback strategies based on error type
        switch error {
        case .loadingFailed:
            // Try to load from cache or show cached data
            await loadCachedExpensesIfAvailable()
        case .savingFailed:
            // Queue the operation for later retry
            await queueFailedSaveOperation(operationId)
        case .networkError:
            // Switch to offline mode
            await enableOfflineMode()
        default:
            break
        }
    }
    
    /// Loads cached expenses when primary loading fails
    private func loadCachedExpensesIfAvailable() async {
        logger.info("Attempting to load cached expenses")
        // Implementation would depend on caching strategy
        // For now, we'll just clear the error to show empty state
        await MainActor.run {
            self.error = nil
            self.isLoading = false
        }
    }
    
    /// Queues failed save operations for retry
    private func queueFailedSaveOperation(_ operationId: String) async {
        logger.info("Queueing failed operation for retry: \(operationId)")
        // Implementation would involve persisting failed operations
        // and retrying them when conditions improve
    }
    
    /// Enables offline mode when network operations fail
    private func enableOfflineMode() async {
        logger.info("Enabling offline mode due to network errors")
        // Implementation would involve:
        // 1. Disabling network-dependent features
        // 2. Showing offline indicator
        // 3. Queuing operations for when network returns
    }
    
    /// Clears all error states and retry counters
    func clearErrors() {
        error = nil
        retryAttempts.removeAll()
        logger.info("Cleared all error states")
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension ExpenseDataService: @preconcurrency NSFetchedResultsControllerDelegate {
    
    nonisolated func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        DispatchQueue.main.async {
            self.expenses = self.fetchedResultsController.fetchedObjects ?? []
        }
    }
}