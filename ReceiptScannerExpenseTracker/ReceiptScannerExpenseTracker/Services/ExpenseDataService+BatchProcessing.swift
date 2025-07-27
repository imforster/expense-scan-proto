import Foundation
import CoreData

extension ExpenseDataService {
    
    // MARK: - Batch Processing
    
    /// Processes expenses in batches to avoid memory issues with large datasets
    func loadExpensesInBatches(batchSize: Int = 100) async throws -> [Expense] {
        let context = CoreDataManager.shared.createBackgroundContext()
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                    request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
                    
                    // Get total count first
                    let totalCount = try context.count(for: request)
                    guard totalCount > 0 else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    var allExpenses: [Expense] = []
                    var offset = 0
                    
                    while offset < totalCount {
                        request.fetchLimit = batchSize
                        request.fetchOffset = offset
                        
                        let batchExpenses = try context.fetch(request)
                        allExpenses.append(contentsOf: batchExpenses)
                        
                        offset += batchSize
                        
                        // Small delay to prevent blocking (synchronous version)
                        if offset % (batchSize * 5) == 0 {
                            Thread.sleep(forTimeInterval: 0.001) // 1ms
                        }
                    }
                    
                    continuation.resume(returning: allExpenses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Batch delete expenses that match criteria
    func batchDeleteExpenses(matching predicate: NSPredicate) async throws -> Int {
        let context = CoreDataManager.shared.createBackgroundContext()
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let fetchRequest: NSFetchRequest<NSFetchRequestResult> = Expense.fetchRequest()
                    fetchRequest.predicate = predicate
                    
                    let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    batchDeleteRequest.resultType = .resultTypeCount
                    
                    let result = try context.execute(batchDeleteRequest) as? NSBatchDeleteResult
                    let deletedCount = result?.result as? Int ?? 0
                    
                    // Merge changes to main context
                    if deletedCount > 0 {
                        let changes = [NSDeletedObjectsKey: result?.result ?? []]
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [CoreDataManager.shared.viewContext])
                    }
                    
                    continuation.resume(returning: deletedCount)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Batch update expenses with new values
    func batchUpdateExpenses(matching predicate: NSPredicate, updates: [String: Any]) async throws -> Int {
        let context = CoreDataManager.shared.createBackgroundContext()
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let batchUpdateRequest = NSBatchUpdateRequest(entityName: "Expense")
                    batchUpdateRequest.predicate = predicate
                    batchUpdateRequest.propertiesToUpdate = updates
                    batchUpdateRequest.resultType = .updatedObjectsCountResultType
                    
                    let result = try context.execute(batchUpdateRequest) as? NSBatchUpdateResult
                    let updatedCount = result?.result as? Int ?? 0
                    
                    // Refresh objects in main context
                    if updatedCount > 0 {
                        context.refreshAllObjects()
                        DispatchQueue.main.async {
                            CoreDataManager.shared.viewContext.refreshAllObjects()
                        }
                    }
                    
                    continuation.resume(returning: updatedCount)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}