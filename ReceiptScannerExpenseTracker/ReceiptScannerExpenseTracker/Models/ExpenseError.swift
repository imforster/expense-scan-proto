import Foundation

/// Comprehensive error handling for expense operations
enum ExpenseError: LocalizedError, Equatable {
    case loadingFailed(Error)
    case savingFailed(Error)
    case deletionFailed(Error)
    case notFound
    case invalidData(String)
    case networkError(Error)
    case coreDataError(Error)
    case validationError(String)
    case permissionDenied
    case storageQuotaExceeded
    case concurrencyConflict
    case dataCorruption(String)
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed:
            return "Failed to load expenses. Please try again."
        case .savingFailed:
            return "Failed to save expense. Please check your data and try again."
        case .deletionFailed:
            return "Failed to delete expense. Please try again."
        case .notFound:
            return "The requested expense could not be found."
        case .invalidData(let details):
            return "Invalid expense data: \(details)"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .coreDataError:
            return "Database error occurred. Please restart the app."
        case .validationError(let details):
            return "Validation error: \(details)"
        case .permissionDenied:
            return "Permission denied. Please check app permissions."
        case .storageQuotaExceeded:
            return "Storage quota exceeded. Please free up space."
        case .concurrencyConflict:
            return "Data conflict detected. Please refresh and try again."
        case .dataCorruption(let details):
            return "Data corruption detected: \(details)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .loadingFailed(let error):
            return "Loading failed: \(error.localizedDescription)"
        case .savingFailed(let error):
            return "Saving failed: \(error.localizedDescription)"
        case .deletionFailed(let error):
            return "Deletion failed: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .notFound:
            return "The expense may have been deleted by another process."
        case .invalidData(let details):
            return "Data validation failed: \(details)"
        case .validationError(let details):
            return "Validation failed: \(details)"
        case .permissionDenied:
            return "The app doesn't have the required permissions."
        case .storageQuotaExceeded:
            return "Device storage is full or quota exceeded."
        case .concurrencyConflict:
            return "Another process modified the data simultaneously."
        case .dataCorruption(let details):
            return "Data integrity check failed: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .loadingFailed:
            return "Try refreshing the expense list or restarting the app."
        case .savingFailed:
            return "Check your data and try saving again. If the problem persists, restart the app."
        case .deletionFailed:
            return "Try deleting the expense again. If it still fails, restart the app."
        case .notFound:
            return "Refresh the expense list to see the current data."
        case .invalidData:
            return "Please check all required fields are filled correctly."
        case .networkError:
            return "Check your internet connection and try again."
        case .coreDataError:
            return "Restart the app. If the problem persists, contact support."
        case .validationError:
            return "Please correct the highlighted fields and try again."
        case .permissionDenied:
            return "Go to Settings and grant the required permissions to the app."
        case .storageQuotaExceeded:
            return "Free up storage space on your device or in iCloud."
        case .concurrencyConflict:
            return "Refresh the data and try your operation again."
        case .dataCorruption:
            return "Try restarting the app. If the problem persists, you may need to restore from backup."
        }
    }
    
    // MARK: - Error Classification
    
    /// Indicates if this error is recoverable through user action
    var isRecoverable: Bool {
        switch self {
        case .loadingFailed, .savingFailed, .deletionFailed, .networkError, .concurrencyConflict:
            return true
        case .notFound, .invalidData, .validationError, .permissionDenied, .storageQuotaExceeded:
            return true
        case .coreDataError, .dataCorruption:
            return false
        }
    }
    
    /// Indicates if this error should be retried automatically
    var shouldRetry: Bool {
        switch self {
        case .networkError, .concurrencyConflict:
            return true
        case .loadingFailed, .savingFailed, .deletionFailed:
            return false // Let user decide
        default:
            return false
        }
    }
    
    /// The severity level of this error
    var severity: ErrorSeverity {
        switch self {
        case .invalidData, .validationError, .notFound:
            return .low
        case .loadingFailed, .savingFailed, .deletionFailed, .networkError, .permissionDenied, .storageQuotaExceeded, .concurrencyConflict:
            return .medium
        case .coreDataError, .dataCorruption:
            return .high
        }
    }
    
    // MARK: - Equatable Implementation
    
    static func == (lhs: ExpenseError, rhs: ExpenseError) -> Bool {
        switch (lhs, rhs) {
        case (.loadingFailed(let lhsError), .loadingFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.savingFailed(let lhsError), .savingFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.deletionFailed(let lhsError), .deletionFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.coreDataError(let lhsError), .coreDataError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.invalidData(let lhsDetails), .invalidData(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.validationError(let lhsDetails), .validationError(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.dataCorruption(let lhsDetails), .dataCorruption(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.notFound, .notFound),
             (.permissionDenied, .permissionDenied),
             (.storageQuotaExceeded, .storageQuotaExceeded),
             (.concurrencyConflict, .concurrencyConflict):
            return true
        default:
            return false
        }
    }
}

/// Errors specific to expense editing operations
enum ExpenseEditError: LocalizedError {
    case invalidInput
    case noSplitsSelected
    case templateSynchronizationFailed
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Please check all required fields are filled correctly."
        case .noSplitsSelected:
            return "Please select at least one receipt split to create expenses."
        case .templateSynchronizationFailed:
            return "Failed to synchronize with recurring template."
        case .saveFailed(let error):
            return "Failed to save expense: \(error.localizedDescription)"
        }
    }
}

/// Error severity levels for logging and handling
enum ErrorSeverity {
    case low    // User input errors, validation issues
    case medium // Network errors, temporary failures
    case high   // System errors, data corruption
}

/// Error recovery strategies
enum ErrorRecoveryStrategy {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case userAction(message: String)
    case fallback(action: () -> Void)
    case none
}

// MARK: - Error Factory

/// Factory for creating specific expense errors with context
struct ExpenseErrorFactory {
    
    /// Creates an error from a Core Data error
    static func fromCoreDataError(_ error: Error) -> ExpenseError {
        let nsError = error as NSError
        
        // Check for common CoreData error codes
        switch nsError.domain {
        case NSCocoaErrorDomain:
            // Handle validation errors
            if nsError.code >= 1550 && nsError.code <= 1570 {
                return .validationError(nsError.localizedDescription)
            }
            // Handle other CoreData errors
            return .coreDataError(error)
        default:
            return .coreDataError(error)
        }
    }
    
    /// Creates an error from a network error
    static func fromNetworkError(_ error: Error) -> ExpenseError {
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return .networkError(error)
        case NSURLErrorTimedOut:
            return .networkError(error)
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost:
            return .networkError(error)
        default:
            return .networkError(error)
        }
    }
    
    /// Validates expense data and returns validation errors
    static func validateExpenseData(_ data: ExpenseData) -> ExpenseError? {
        var validationErrors: [String] = []
        
        // Validate amount
        if data.amount <= 0 {
            validationErrors.append("Amount must be greater than zero")
        }
        
        if data.amount > 999999.99 {
            validationErrors.append("Amount cannot exceed $999,999.99")
        }
        
        // Validate merchant
        if data.merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append("Merchant name is required")
        }
        
        if data.merchant.count > 100 {
            validationErrors.append("Merchant name cannot exceed 100 characters")
        }
        
        // Validate date
        let calendar = Calendar.current
        let futureLimit = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        let pastLimit = calendar.date(byAdding: .year, value: -10, to: Date()) ?? Date()
        
        if data.date > futureLimit {
            validationErrors.append("Date cannot be more than 1 year in the future")
        }
        
        if data.date < pastLimit {
            validationErrors.append("Date cannot be more than 10 years in the past")
        }
        
        // Validate notes length
        if let notes = data.notes, notes.count > 500 {
            validationErrors.append("Notes cannot exceed 500 characters")
        }
        
        // Validate payment method
        if let paymentMethod = data.paymentMethod, paymentMethod.count > 50 {
            validationErrors.append("Payment method cannot exceed 50 characters")
        }
        
        // Validate expense items
        for (index, item) in data.items.enumerated() {
            if item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                validationErrors.append("Item \(index + 1) name is required")
            }
            
            if item.amount <= 0 {
                validationErrors.append("Item \(index + 1) amount must be greater than zero")
            }
        }
        
        if !validationErrors.isEmpty {
            return .validationError(validationErrors.joined(separator: "; "))
        }
        
        return nil
    }
}