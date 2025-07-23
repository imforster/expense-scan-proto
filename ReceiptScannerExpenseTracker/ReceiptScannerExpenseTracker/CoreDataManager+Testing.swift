import Foundation
import CoreData

// Create a test helper extension for CoreDataManager
extension CoreDataManager {
    // Create a test instance of CoreDataManager with in-memory store
    static func createForTesting() -> CoreDataManager {
        // Use the shared instance since we can't create a new one (init is private)
        let manager = CoreDataManager.shared
        
        // Configure the persistent container to use an in-memory store
        let description = NSPersistentStoreDescription()
        description.url = URL(fileURLWithPath: "/dev/null")
        description.type = NSInMemoryStoreType
        
        // Use the setPersistentStoreDescriptions method
        manager.setPersistentStoreDescriptions([description])
        
        // Reset any existing data in the context
        let context = manager.viewContext
        let entities = manager.viewContext.persistentStoreCoordinator?.managedObjectModel.entities ?? []
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                try context.save()
            } catch {
                print("Error resetting test data: \(error)")
            }
        }
        
        // Note: We're not creating default categories here to avoid conflicts with test cases
        // that create their own categories
        
        return manager
    }
    
    // Helper method to create default categories for testing
    static func createDefaultCategoriesForTesting(in context: NSManagedObjectContext) {
        // Check if categories already exist
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        
        do {
            let count = try context.count(for: fetchRequest)
            if count > 0 {
                // Categories already exist, no need to create them
                return
            }
        } catch {
            print("Error checking for existing categories: \(error)")
            return
        }
        
        // Create default categories
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
            let category = Category(context: context)
            category.id = UUID()
            category.name = name
            category.colorHex = attributes.color
            category.icon = attributes.icon
            category.isDefault = true
        }
        
        do {
            try context.save()
        } catch {
            print("Error creating default categories for testing: \(error)")
        }
    }
}