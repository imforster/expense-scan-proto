import Foundation
import CoreData
@testable import ReceiptScannerExpenseTracker

// A mock version of CategoryService that doesn't check for duplicate names
class TestMockCategoryService: CategoryService {
    
    override init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        super.init(coreDataManager: coreDataManager)
        print("TestMockCategoryService initialized")
    }
    
    // Override the createCategory method to skip the duplicate name check
    override func createCategory(name: String, colorHex: String, icon: String, parentCategory: ReceiptScannerExpenseTracker.Category? = nil) async throws -> ReceiptScannerExpenseTracker.Category {
        print("TestMockCategoryService.createCategory called with name: \(name)")
        
        return try await withCheckedThrowingContinuation { continuation in
            self.context.perform {
                print("Inside context.perform for name: \(name)")
                
                // IMPORTANT: Skip the duplicate name check that exists in the parent class
                // Create new category without checking for duplicates
                let category = ReceiptScannerExpenseTracker.Category(context: self.context)
                category.id = UUID()
                category.name = name
                category.colorHex = colorHex
                category.icon = icon
                category.isDefault = false
                category.parentCategory = parentCategory
                
                do {
                    try self.context.save()
                    print("Successfully created category with name: \(name)")
                    continuation.resume(returning: category)
                } catch {
                    print("Error creating category in TestMockCategoryService: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}