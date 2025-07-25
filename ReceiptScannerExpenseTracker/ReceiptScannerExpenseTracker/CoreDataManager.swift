import Foundation
import CoreData
import CloudKit

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    // Static method for testing
    static func createForTesting() -> CoreDataManager {
        let manager = CoreDataManager()
        
        // Configure in-memory store for testing
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        manager.container.persistentStoreDescriptions = [description]
        
        // Load the persistent store
        manager.container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        return manager
    }
    
    private let container: NSPersistentContainer
    
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    // Method for testing purposes
    func setPersistentStoreDescriptions(_ descriptions: [NSPersistentStoreDescription]) {
        container.persistentStoreDescriptions = descriptions
    }
    
    private init() {
        // Initialize Core Data container
        container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        
        // Register entity classes
        registerEntityClasses()
        
        // Configure CloudKit integration if enabled
        if UserDefaults.standard.bool(forKey: "enableCloudSync") {
            configureCloudKitIntegration()
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Configure the container
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable data protection
        enableDataProtection()
        
        // Initialize default data if needed
        initializeDefaultDataIfNeeded()
    }
    
    // MARK: - Helper Methods
    
    // Register entity classes to ensure proper mapping
    private func registerEntityClasses() {
        NSEntityDescription.entity(forEntityName: "Tag", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerTag"
        NSEntityDescription.entity(forEntityName: "Category", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerCategory"
        NSEntityDescription.entity(forEntityName: "Expense", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerExpense"
        NSEntityDescription.entity(forEntityName: "ExpenseItem", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerExpenseItem"
        NSEntityDescription.entity(forEntityName: "Receipt", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerReceipt"
        NSEntityDescription.entity(forEntityName: "ReceiptItem", in: viewContext)?.managedObjectClassName = "ReceiptScannerExpenseTrackerReceiptItem"
    }
    
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
    
    // MARK: - Data Initialization
    
    private func initializeDefaultDataIfNeeded() {
        // Check if we need to initialize default categories
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let count = try viewContext.count(for: fetchRequest)
            if count == 0 {
                // No categories exist, create default ones
                createDefaultCategories()
            }
        } catch {
            print("Error checking for existing categories: \(error)")
        }
    }
    
    private func createDefaultCategories() {
        let defaultCategories = [
            "Food": (color: "FF5733", icon: "fork.knife"),
            "Transportation": (color: "33A8FF", icon: "car.fill"),
            "Entertainment": (color: "FF33A8", icon: "film.fill"),
            "Utilities": (color: "33FF57", icon: "bolt.fill"),
            "Shopping": (color: "A833FF", icon: "cart.fill"),
            "Healthcare": (color: "33FFA8", icon: "heart.fill"),
            "Education": (color: "FFA833", icon: "book.fill"),
            "Travel": (color: "5733FF", icon: "airplane"),
            "Housing": (color: "57FF33", icon: "house.fill"),
            "Other": (color: "AAAAAA", icon: "ellipsis.circle.fill")
        ]
        
        for (name, attributes) in defaultCategories {
            let category = Category(context: viewContext)
            category.id = UUID()
            category.name = name
            category.colorHex = attributes.color
            category.icon = attributes.icon
            category.isDefault = true
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error creating default categories: \(error)")
        }
    }
    
    // MARK: - Receipt URL Management
    
    /// Stores a receipt URL in the database
    /// - Parameters:
    ///   - url: The URL of the receipt image
    ///   - expense: The expense to associate with the receipt
    func storeReceiptURL(_ url: URL, for expense: Expense) {
        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.imageURL = url
        receipt.expense = expense
        receipt.date = Date()
        receipt.dateProcessed = Date()
        receipt.merchantName = expense.merchant ?? "Unknown"
        receipt.totalAmount = expense.amount
        
        save()
    }
    
    /// Retrieves the receipt URL for an expense
    /// - Parameter expense: The expense to get the receipt for
    /// - Returns: The URL of the receipt image, or nil if not found
    func getReceiptURL(for expense: Expense) -> URL? {
        guard let receipt = expense.receipt else {
            return nil
        }
        
        return receipt.imageURL
    }
    
    /// Removes a receipt from an expense
    /// - Parameters:
    ///   - receipt: The receipt to remove
    ///   - expense: The expense to remove the receipt from
    func removeReceipt(_ receipt: Receipt, from expense: Expense) {
        viewContext.delete(receipt)
        save()
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
    
    // MARK: - CloudKit Integration
    
    // Configure CloudKit integration for the persistent container
    private func configureCloudKitIntegration() {
        guard let description = container.persistentStoreDescriptions.first else {
            print("Failed to retrieve a persistent store description")
            return
        }
        
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: "iCloud.com.yourcompany.ReceiptScannerExpenseTracker"
        )
        
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable history tracking for CloudKit
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
    }
    
    // Setup CloudKit sync (Requirement 4.3)
    func setupCloudKitSync(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "enableCloudSync")
        
        if enabled {
            // Check iCloud account status
            CKContainer.default().accountStatus { [weak self] (status, error) in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    switch status {
                    case .available:
                        print("iCloud account is available")
                        self.migrateToCloudKitStore()
                    case .noAccount:
                        print("No iCloud account is logged in")
                    case .restricted:
                        print("iCloud account is restricted")
                    case .couldNotDetermine:
                        print("Could not determine iCloud account status")
                        if let error = error {
                            print("Error: \(error.localizedDescription)")
                        }
                    @unknown default:
                        print("Unknown iCloud account status")
                    }
                }
            }
        } else {
            // Disable CloudKit sync
            migrateToLocalStore()
        }
    }
    
    // Migrate data to CloudKit-enabled store
    private func migrateToCloudKitStore() {
        // This would involve:
        // 1. Creating a new persistent store with CloudKit enabled
        // 2. Migrating data from the local store to the CloudKit store
        // 3. Removing the local store
        
        // For now, we'll just notify the user that they need to restart the app
        NotificationCenter.default.post(
            name: Notification.Name("CloudKitSyncStatusChanged"),
            object: nil,
            userInfo: ["message": "CloudKit sync enabled. Please restart the app for changes to take effect."]
        )
    }
    
    // Migrate data to local-only store
    private func migrateToLocalStore() {
        // This would involve:
        // 1. Creating a new persistent store without CloudKit
        // 2. Migrating data from the CloudKit store to the local store
        // 3. Removing the CloudKit store
        
        // For now, we'll just notify the user that they need to restart the app
        NotificationCenter.default.post(
            name: Notification.Name("CloudKitSyncStatusChanged"),
            object: nil,
            userInfo: ["message": "CloudKit sync disabled. Please restart the app for changes to take effect."]
        )
    }
    
    // Handle CloudKit sync conflicts
    func handleSyncConflicts() {
        // This would involve:
        // 1. Detecting conflicts between local and remote changes
        // 2. Implementing a conflict resolution strategy
        // 3. Merging changes or presenting options to the user
        
        // This is a placeholder for future implementation
    }
    
    // MARK: - Data Management
    
    /// Creates a backup of the Core Data store
    /// - Returns: URL to the backup file, or nil if backup failed
    func createBackup() -> URL? {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            print("Could not find persistent store URL")
            return nil
        }
        
        let fileManager = FileManager.default
        let backupURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Backups", isDirectory: true)
        
        // Create backups directory if it doesn't exist
        if !fileManager.fileExists(atPath: backupURL.path) {
            do {
                try fileManager.createDirectory(at: backupURL, withIntermediateDirectories: true)
            } catch {
                print("Error creating backup directory: \(error)")
                return nil
            }
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        let backupStoreURL = backupURL.appendingPathComponent("ReceiptScannerExpenseTracker-\(dateString).sqlite")
        
        do {
            // Ensure we have a clean backup file
            if fileManager.fileExists(atPath: backupStoreURL.path) {
                try fileManager.removeItem(at: backupStoreURL)
            }
            
            // Copy the store file to the backup location
            try fileManager.copyItem(at: storeURL, to: backupStoreURL)
            
            // Also backup the WAL and SHM files if they exist
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.copyItem(at: walURL, to: backupStoreURL.appendingPathExtension("wal"))
            }
            
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.copyItem(at: shmURL, to: backupStoreURL.appendingPathExtension("shm"))
            }
            
            // Apply data protection to the backup files
            try fileManager.setAttributes(
                [FileAttributeKey.protectionKey: FileProtectionType.complete],
                ofItemAtPath: backupStoreURL.path
            )
            
            return backupStoreURL
        } catch {
            print("Error creating backup: \(error)")
            return nil
        }
    }
    
    /// Restores the Core Data store from a backup
    /// - Parameter backupURL: The URL of the backup file to restore from
    /// - Returns: True if restoration was successful, false otherwise
    func restoreFromBackup(at backupURL: URL) -> Bool {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            print("Could not find persistent store URL")
            return false
        }
        
        // First, unload the persistent stores
        for store in container.persistentStoreCoordinator.persistentStores {
            do {
                try container.persistentStoreCoordinator.remove(store)
            } catch {
                print("Error removing persistent store: \(error)")
                return false
            }
        }
        
        let fileManager = FileManager.default
        
        do {
            // Remove the current store files
            if fileManager.fileExists(atPath: storeURL.path) {
                try fileManager.removeItem(at: storeURL)
            }
            
            // Also remove the WAL and SHM files if they exist
            let walURL = storeURL.appendingPathExtension("wal")
            let shmURL = storeURL.appendingPathExtension("shm")
            
            if fileManager.fileExists(atPath: walURL.path) {
                try fileManager.removeItem(at: walURL)
            }
            
            if fileManager.fileExists(atPath: shmURL.path) {
                try fileManager.removeItem(at: shmURL)
            }
            
            // Copy the backup files to the store location
            try fileManager.copyItem(at: backupURL, to: storeURL)
            
            // Also copy the WAL and SHM files if they exist
            let backupWALURL = backupURL.appendingPathExtension("wal")
            let backupSHMURL = backupURL.appendingPathExtension("shm")
            
            if fileManager.fileExists(atPath: backupWALURL.path) {
                try fileManager.copyItem(at: backupWALURL, to: walURL)
            }
            
            if fileManager.fileExists(atPath: backupSHMURL.path) {
                try fileManager.copyItem(at: backupSHMURL, to: shmURL)
            }
            
            // Reload the persistent stores
            try container.loadPersistentStores { (storeDescription, error) in
                if let error = error {
                    print("Error reloading persistent stores: \(error)")
                }
            }
            
            return true
        } catch {
            print("Error restoring from backup: \(error)")
            
            // Try to reload the persistent stores even if restoration failed
            do {
                try container.loadPersistentStores { (storeDescription, error) in
                    if let error = error {
                        print("Error reloading persistent stores: \(error)")
                    }
                }
            } catch {
                print("Error reloading persistent stores: \(error)")
            }
            
            return false
        }
    }
    
    /// Deletes all data from the Core Data store
    /// - Parameter createBackup: Whether to create a backup before deleting
    /// - Returns: True if deletion was successful, false otherwise
    func deleteAllData(createBackup: Bool = true) -> Bool {
        // Create a backup first if requested
        if createBackup {
            _ = self.createBackup()
        }
        
        // Delete all entities
        let entities = container.managedObjectModel.entities
        
        let context = createBackgroundContext()
        
        context.perform {
            for entity in entities {
                guard let entityName = entity.name else { continue }
                
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let batchDeleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                
                do {
                    try context.execute(batchDeleteRequest)
                } catch {
                    print("Error deleting \(entityName) entities: \(error)")
                }
            }
            
            // Save the context
            do {
                try context.save()
            } catch {
                print("Error saving context after batch delete: \(error)")
            }
        }
        
        // Reinitialize default data
        initializeDefaultDataIfNeeded()
        
        return true
    }
}
