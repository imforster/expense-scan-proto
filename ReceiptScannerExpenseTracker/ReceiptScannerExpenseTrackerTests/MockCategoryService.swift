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
    
    // Override initializeBudgetRuleCategories to ensure proper creation of all categories
    override func initializeBudgetRuleCategories() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Clear any existing budget rule categories first
                    let existingRulesRequest: NSFetchRequest<ReceiptScannerExpenseTracker.Category> = ReceiptScannerExpenseTracker.Category.fetchRequest()
                    existingRulesRequest.predicate = NSPredicate(format: "parentCategory == nil AND isDefault == YES")
                    let existingRules = try self.context.fetch(existingRulesRequest)
                    
                    for rule in existingRules {
                        self.context.delete(rule)
                    }
                    
                    // Create the budget rule hierarchy from scratch
                    try self.createBudgetRuleHierarchy()
                    
                    continuation.resume()
                } catch {
                    print("Error initializing budget rule categories: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Ensure we're using the same method as the parent class
    private func createBudgetRuleHierarchy() throws {
        // Create parent categories for each budget rule
        for rule in BudgetRule.allCases {
            let parentCategory = ReceiptScannerExpenseTracker.Category(context: context)
            parentCategory.id = UUID()
            parentCategory.name = rule.rawValue
            parentCategory.colorHex = rule.color
            parentCategory.icon = rule.icon
            parentCategory.isDefault = true
            parentCategory.parentCategory = nil
            
            // Create default subcategories for each rule
            let subcategories = getDefaultSubcategories(for: rule)
            for (name, icon, color) in subcategories {
                let subcategory = ReceiptScannerExpenseTracker.Category(context: context)
                subcategory.id = UUID()
                subcategory.name = name
                subcategory.colorHex = color
                subcategory.icon = icon
                subcategory.isDefault = true
                subcategory.parentCategory = parentCategory
            }
        }
        
        try context.save()
    }
    
    // Copy of the parent class method to ensure we're using the same subcategories
    private func getDefaultSubcategories(for rule: BudgetRule) -> [(String, String, String)] {
        switch rule {
        case .needs:
            return [
                // Housing & Utilities
                ("Housing & Rent", "house.fill", "FF5733"),
                ("Property Taxes & Insurance", "building.columns.fill", "FF6B42"),
                ("Utilities", "bolt.fill", "FF7C54"),
                ("Internet & Phone", "wifi", "FF8C42"),
                
                // Transportation
                ("Car Payments", "car.fill", "FFA500"),
                ("Car Insurance", "car.circle.fill", "FFB84D"),
                ("Gas & Maintenance", "fuelpump.fill", "FFC266"),
                ("Public Transit", "bus.fill", "FFD700"),
                ("Parking Fees", "parkingsign", "FFCC80"),
                
                // Food Essentials
                ("Groceries", "cart.fill", "FFE066"),
                ("Household Supplies", "house.circle.fill", "FFF5CC"),
                
                // Insurance & Healthcare
                ("Health Insurance", "cross.case.fill", "FF6B6B"),
                ("Life Insurance", "shield.lefthalf.filled", "FF8A80"),
                ("Prescriptions", "pill.fill", "FF9999"),
                ("Medical Expenses", "stethoscope", "FFAAAA"),
                
                // Minimum Debt Payments
                ("Credit Card Minimums", "creditcard.fill", "E57373"),
                ("Student Loan Minimums", "graduationcap.fill", "EF9A9A"),
                ("Other Loan Payments", "banknote.fill", "FFCDD2")
            ]
        case .wants:
            return [
                // Entertainment & Lifestyle
                ("Dining Out", "fork.knife.circle.fill", "33A8FF"),
                ("Movies & Events", "ticket.fill", "5DADE2"),
                ("Streaming Services", "play.rectangle.fill", "74B9FF"),
                ("Hobbies & Recreation", "gamecontroller.fill", "0984E3"),
                ("Gym & Fitness", "figure.strengthtraining.traditional", "42A5F5"),
                
                // Shopping
                ("Clothing & Accessories", "tshirt.fill", "6C5CE7"),
                ("Electronics & Gadgets", "iphone", "7986CB"),
                ("Home Decor", "lamp.table.fill", "9575CD"),
                ("Personal Care Items", "scissors", "A29BFE"),
                
                // Travel & Vacations
                ("Travel & Vacations", "airplane", "8E24AA"),
                ("Weekend Getaways", "suitcase.fill", "9C27B0"),
                
                // Upgraded Services
                ("Premium Subscriptions", "star.circle.fill", "673AB7"),
                ("Premium Phone/Internet", "antenna.radiowaves.left.and.right", "7E57C2"),
                ("Other Discretionary", "gift.fill", "9575CD")
            ]
        case .savingsAndDebt:
            return [
                // Emergency Fund
                ("Emergency Fund", "shield.checkered", "33FF57"),
                
                // Retirement Savings
                ("401k Contributions", "building.columns.fill", "4CAF50"),
                ("IRA Contributions", "chart.pie.fill", "66BB6A"),
                ("Other Retirement", "clock.fill", "00B894"),
                
                // Other Savings Goals
                ("House Down Payment", "house.and.flag.fill", "26A69A"),
                ("Car Replacement Fund", "car.circle.fill", "00ACC1"),
                ("Vacation Savings", "airplane.circle.fill", "00BCD4"),
                ("General Savings", "banknote.fill", "81ECEC"),
                
                // Extra Debt Payments
                ("Extra Credit Card Payments", "creditcard.and.123", "4DB6AC"),
                ("Extra Mortgage Payments", "house.circle.fill", "55A3FF"),
                ("Extra Loan Payments", "dollarsign.circle.fill", "80DEEA"),
                
                // Investments
                ("Stock Investments", "chart.line.uptrend.xyaxis", "26C6DA"),
                ("Other Investments", "chart.bar.fill", "4DD0E1")
            ]
        }
    }
}