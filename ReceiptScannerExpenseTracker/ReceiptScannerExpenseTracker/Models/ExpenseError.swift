import Foundation

/// Standardized error type for expense-related operations
enum ExpenseError: LocalizedError, Equatable {
    
    // MARK: - Error Cases
    
    /// Failed to load expenses from the data store
    case loadingFailed(String)
    
    /// Failed to save a new or updated expense
    case savingFailed(String)
    
    /// Failed to delete an expense
    case deletionFailed(String)
    
    /// The requested expense was not found
    case notFound
    
    /// The provided data is invalid or incomplete
    case invalidData(String)
    
    /// A validation rule failed (e.g., amount must be positive)
    case validationFailed(String)
    
    /// A network-related error occurred
    case networkError(String)
    
    /// A CoreData-specific error occurred
    case coreDataError(String)
    
    /// The user does not have permission to perform the action
    case permissionDenied
    
    /// The storage quota has been exceeded
    case storageQuotaExceeded
    
    /// A data synchronization error occurred
    case syncFailed(String)
    
    // MARK: - Error Descriptions
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load expenses: \(message)"
        case .savingFailed(let message):
            return "Failed to save expense: \(message)"
        case .deletionFailed(let message):
            return "Failed to delete expense: \(message)"
        case .notFound:
            return "The requested expense was not found."
        case .invalidData(let details):
            return "Invalid data provided: \(details)"
        case .validationFailed(let details):
            return "Validation failed: \(details)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .coreDataError(let message):
            return "A database error occurred: \(message)"
        case .permissionDenied:
            return "You do not have permission to perform this action."
        case .storageQuotaExceeded:
            return "Storage quota has been exceeded."
        case .syncFailed(let message):
            return "Data synchronization failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .loadingFailed, .savingFailed, .deletionFailed:
            return "Please try again later."
        case .networkError:
            return "Please check your internet connection and try again."
        case .validationFailed:
            return "Please correct the invalid data and try again."
        case .storageQuotaExceeded:
            return "Please free up some space and try again."
        default:
            return "If the problem persists, please contact support."
        }
    }
    
    // MARK: - Error Properties
    
    /// Indicates if this error is recoverable through user action
    var isRecoverable: Bool {
        switch self {
        case .loadingFailed, .savingFailed, .deletionFailed, .networkError:
            return true
        case .notFound, .invalidData, .validationFailed, .permissionDenied, .storageQuotaExceeded:
            return true
        case .coreDataError, .syncFailed:
            return false
        }
    }
    
    /// Indicates if this error should be retried automatically
    var shouldRetry: Bool {
        switch self {
        case .networkError:
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
        case .invalidData, .validationFailed, .notFound:
            return .low
        case .loadingFailed, .savingFailed, .deletionFailed, .networkError, .permissionDenied, .storageQuotaExceeded:
            return .medium
        case .coreDataError, .syncFailed:
            return .high
        }
    }
    
    // MARK: - Equatable Conformance
    
    static func == (lhs: ExpenseError, rhs: ExpenseError) -> Bool {
        switch (lhs, rhs) {
        case (.loadingFailed(let lhsMessage), .loadingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.savingFailed(let lhsMessage), .savingFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.deletionFailed(let lhsMessage), .deletionFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.validationFailed(let lhsMessage), .validationFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.coreDataError(let lhsMessage), .coreDataError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.invalidData(let lhsDetails), .invalidData(let rhsDetails)):
            return lhsDetails == rhsDetails
        case (.syncFailed(let lhsMessage), .syncFailed(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.notFound, .notFound),
             (.permissionDenied, .permissionDenied),
             (.storageQuotaExceeded, .storageQuotaExceeded):
            return true
        default:
            return false
        }
    }
}

/// Severity levels for errors
enum ErrorSeverity {
    case low, medium, high
}

/// Factory for creating specific error types from generic errors
struct ExpenseErrorFactory {
    
    /// Creates an `ExpenseError` from a generic `Error`
    static func create(from error: Error) -> ExpenseError {
        let nsError = error as NSError
        
        switch nsError.domain {
        case NSCocoaErrorDomain:
            // Handle validation errors
            if nsError.code >= 1550 && nsError.code <= 1570 {
                return .validationFailed(nsError.localizedDescription)
            }
            // Handle other CoreData errors
            return .coreDataError(nsError.localizedDescription)
        default:
            return .coreDataError(nsError.localizedDescription)
        }
    }
    
    /// Creates a network-related `ExpenseError`
    static func createNetworkError(from error: Error) -> ExpenseError {
        let nsError = error as NSError
        
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost:
            return .networkError(nsError.localizedDescription)
        case NSURLErrorTimedOut:
            return .networkError("Request timed out")
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost:
            return .networkError("Cannot connect to server")
        default:
            return .networkError(nsError.localizedDescription)
        }
    }
    
    /// Creates a validation error from a dictionary of validation messages
    static func createValidationError(from messages: [String: String]) -> ExpenseError {
        let combinedMessage = messages.map { "\($0.key): \($0.value)" }.joined(separator: "; ")
        return .validationFailed(combinedMessage)
    }
    
    /// Validates an `ExpenseData` object and returns an error if invalid
    static func validate(expenseData: ExpenseData) -> ExpenseError? {
        var validationErrors: [String] = []
        
        if expenseData.amount <= 0 {
            validationErrors.append("Amount must be positive.")
        }
        
        if expenseData.merchant.isEmpty {
            validationErrors.append("Merchant name is required.")
        }
        
        if expenseData.date > Date() {
            validationErrors.append("Expense date cannot be in the future.")
        }
        
        if !validationErrors.isEmpty {
            return .validationFailed(validationErrors.joined(separator: "; "))
        }
        
        return nil
    }
}
