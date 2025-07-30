import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

/// Base test case class that provides a shared Core Data stack for testing
/// This prevents entity disambiguation issues by ensuring only one managed object model is loaded
class CoreDataTestCase: XCTestCase {
    
    // Shared test Core Data manager to prevent multiple model loading
    static var sharedTestCoreDataManager: CoreDataManager?
    static var sharedTestContext: NSManagedObjectContext?
    
    var testCoreDataManager: CoreDataManager {
        return Self.sharedTestCoreDataManager!
    }
    
    var testContext: NSManagedObjectContext {
        return Self.sharedTestContext!
    }
    
    override class func setUp() {
        super.setUp()
        
        // Create a single shared Core Data manager for all tests
        if sharedTestCoreDataManager == nil {
            sharedTestCoreDataManager = CoreDataManager.createForTesting()
            sharedTestContext = sharedTestCoreDataManager!.viewContext
        }
    }
    
    override class func tearDown() {
        // Clean up the shared Core Data manager
        sharedTestCoreDataManager = nil
        sharedTestContext = nil
        super.tearDown()
    }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Clean up all entities before each test
        Task { @MainActor in
            try await cleanupAllEntities()
        }
    }
    
    override func tearDownWithError() throws {
        // Clean up all entities after each test
        Task { @MainActor in
            try await cleanupAllEntities()
        }
        try super.tearDownWithError()
    }
    
    /// Cleans up all entities in the test database
    private func cleanupAllEntities() async throws {
        let entityNames = ["Category", "Expense", "ExpenseItem", "Receipt", "ReceiptItem", "Tag"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            deleteRequest.resultType = .resultTypeObjectIDs
            
            do {
                let result = try await testContext.execute(deleteRequest) as? NSBatchDeleteResult
                if let objectIDs = result?.result as? [NSManagedObjectID] {
                    let changes = [NSDeletedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [testContext])
                }
            } catch {
                // If batch delete fails, try individual deletion
                let objects = try await testContext.fetch(fetchRequest)
                for object in objects {
                    if let managedObject = object as? NSManagedObject {
                        testContext.delete(managedObject)
                    }
                }
            }
        }
        
        try testContext.save()
    }
    
    /// Creates a test category with the given parameters
    func createTestCategory(name: String = "Test Category", 
                          colorHex: String = "FF5733", 
                          icon: String = "tag.fill", 
                          isDefault: Bool = false) -> ReceiptScannerExpenseTracker.Category {
        let category = ReceiptScannerExpenseTracker.Category(context: testContext)
        category.id = UUID()
        category.name = name
        category.colorHex = colorHex
        category.icon = icon
        category.isDefault = isDefault
        return category
    }
    
    /// Creates a test expense with the given parameters
    func createTestExpense(merchant: String = "Test Merchant",
                          amount: Decimal = 10.00,
                          date: Date = Date(),
                          category: ReceiptScannerExpenseTracker.Category? = nil) -> ReceiptScannerExpenseTracker.Expense {
        let expense = ReceiptScannerExpenseTracker.Expense(context: testContext)
        expense.id = UUID()
        expense.merchant = merchant
        expense.amount = NSDecimalNumber(decimal: amount)
        expense.date = date
        expense.category = category
        return expense
    }
    
    /// Creates a test tag with the given parameters
    func createTestTag(name: String = "Test Tag") -> ReceiptScannerExpenseTracker.Tag {
        let tag = ReceiptScannerExpenseTracker.Tag(context: testContext)
        tag.id = UUID()
        tag.name = name
        return tag
    }
    
    /// Saves the test context
    func saveTestContext() throws {
        if testContext.hasChanges {
            try testContext.save()
        }
    }
}