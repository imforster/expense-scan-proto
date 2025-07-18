import Foundation
import CoreData

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    private let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    private init() {
        container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Configure the container
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Helper Methods
    
    func save() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error saving Core Data context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func createBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    // MARK: - Data Encryption
    
    // Configure data protection - this helps satisfy requirement 4.1
    func enableDataProtection() {
        guard let url = container.persistentStoreDescriptions.first?.url else {
            return
        }
        
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        
        do {
            var fileURL = url
            try fileURL.setResourceValues(resourceValues)
            
            // Set data protection
            let fileManager = FileManager.default
            try fileManager.setAttributes([FileAttributeKey.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
        } catch {
            print("Error setting data protection: \(error)")
        }
    }
}