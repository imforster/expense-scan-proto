import CoreData
import Combine

// This file is kept for backward compatibility with the default SwiftUI template
// The actual Core Data management is now handled by CoreDataManager.swift

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    @Published var isStoreLoaded = false

    // Preview helper for SwiftUI previews
    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let category = Category(context: viewContext)
        category.id = UUID()
        category.name = "Food"
        category.colorHex = "FF5733"
        category.icon = "fork.knife"
        category.isDefault = true
        
        for i in 0..<5 {
            let expense = Expense(context: viewContext)
            expense.id = UUID()
            expense.amount = NSDecimalNumber(value: Double.random(in: 10...100))
            expense.date = Date().addingTimeInterval(Double(-i * 86400))
            expense.merchant = "Sample Merchant \(i+1)"
            expense.category = category
            expense.isRecurring = i % 2 == 0
        }
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        result.isStoreLoaded = true
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ReceiptScannerExpenseTracker")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            DispatchQueue.main.async {
                self.isStoreLoaded = true
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}