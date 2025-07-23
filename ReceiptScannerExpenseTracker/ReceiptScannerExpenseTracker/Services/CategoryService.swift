import Foundation
import CoreData
import SwiftUI

// MARK: - Category Service Error
//enum CategoryServiceError: Error {
//    case categoryAlreadyExists
//    case categoryInUse
//    case categoryHasSubcategories
//    case cannotDeleteDefaultCategory
//}

// MARK: - Category Service Errors
enum CategoryServiceError: LocalizedError {
    case categoryAlreadyExists
    case categoryInUse
    case categoryHasSubcategories
    case cannotDeleteDefaultCategory
    case categoryNotFound
    
    var errorDescription: String? {
        switch self {
        case .categoryAlreadyExists:
            return "A category with this name already exists"
        case .categoryInUse:
            return "Cannot delete category because it's being used by existing expenses"
        case .categoryHasSubcategories:
            return "Cannot delete category because it has subcategories"
        case .cannotDeleteDefaultCategory:
            return "Cannot delete default categories"
        case .categoryNotFound:
            return "Category not found"
        }
    }
}

// MARK: - Budget Rule Types
enum BudgetRule: String, CaseIterable {
    case needs = "Needs"
    case wants = "Wants"
    case savingsAndDebt = "Savings & Debt Repayment"
    
    var percentage: Double {
        switch self {
        case .needs: return 0.50
        case .wants: return 0.30
        case .savingsAndDebt: return 0.20
        }
    }
    
    var color: String {
        switch self {
        case .needs: return "FF5733"
        case .wants: return "33A8FF"
        case .savingsAndDebt: return "33FF57"
        }
    }
    
    var icon: String {
        switch self {
        case .needs: return "house.fill"
        case .wants: return "heart.fill"
        case .savingsAndDebt: return "banknote.fill"
        }
    }
}

// MARK: - Category Service Protocol
protocol CategoryServiceProtocol {
    func getAllCategories() async throws -> [Category]
    func getDefaultCategories() async throws -> [Category]
    func getCustomCategories() async throws -> [Category]
    func getCategoriesByBudgetRule(_ rule: BudgetRule) async throws -> [Category]
    func createCategory(name: String, colorHex: String, icon: String, parentCategory: Category?) async throws -> Category
    func updateCategory(_ category: Category, name: String?, colorHex: String?, icon: String?) async throws
    func deleteCategory(_ category: Category) async throws
    func suggestCategory(for merchantName: String, amount: Decimal?) async throws -> Category?
    func suggestCategory(for receiptText: String) async throws -> Category?
    func getCategoryUsageStats() async throws -> [CategoryUsageStats]
    func getBudgetRuleStats(for rule: BudgetRule, period: DateInterval) async throws -> BudgetRuleStats
    func initializeBudgetRuleCategories() async throws
}

// MARK: - Category Usage Statistics
struct CategoryUsageStats {
    let category: Category
    let usageCount: Int
    let totalAmount: Decimal
    let averageAmount: Decimal
    let lastUsed: Date?
}

// MARK: - Budget Rule Statistics
struct BudgetRuleStats {
    let rule: BudgetRule
    let totalSpent: Decimal
    let targetAmount: Decimal
    let percentageUsed: Double
    let categories: [CategoryUsageStats]
    let isOverBudget: Bool
}

// MARK: - Category Service Implementation
class CategoryService: CategoryServiceProtocol {
    private let coreDataManager: CoreDataManager
    internal let context: NSManagedObjectContext
    
    // Merchant-to-category mapping for suggestions (aligned with 50-30-20 budget)
    private let merchantCategoryMappings: [String: String] = [
        // NEEDS (50%) - Essential Expenses
        
        // Housing & Utilities
        "rent": "Housing & Rent",
        "mortgage": "Housing & Rent",
        "apartment": "Housing & Rent",
        "electric": "Utilities",
        "gas": "Utilities",
        "water": "Utilities",
        "sewer": "Utilities",
        "trash": "Utilities",
        "internet": "Internet & Phone",
        "phone": "Internet & Phone",
        "verizon": "Internet & Phone",
        "att": "Internet & Phone",
        "comcast": "Internet & Phone",
        
        // Transportation (Essential)
        "gasoline": "Transportation",
        "fuel": "Transportation",
        "shell": "Transportation",
        "exxon": "Transportation",
        "chevron": "Transportation",
        "metro": "Public Transit",
        "bus": "Public Transit",
        "train": "Public Transit",
        "subway": "Public Transit",
        "parking": "Parking & Fees",
        
        // Food Essentials
        "grocery": "Groceries",
        "supermarket": "Groceries",
        "walmart": "Groceries",
        "target": "Groceries",
        "costco": "Groceries",
        "safeway": "Groceries",
        "kroger": "Groceries",
        "publix": "Groceries",
        "whole foods": "Groceries",
        "trader joe": "Groceries",
        
        // Healthcare & Insurance
        "pharmacy": "Healthcare",
        "cvs": "Healthcare",
        "walgreens": "Healthcare",
        "hospital": "Healthcare",
        "clinic": "Healthcare",
        "doctor": "Healthcare",
        "medical": "Healthcare",
        "dental": "Healthcare",
        "health": "Healthcare",
        "insurance": "Health Insurance",
        
        // Minimum Debt Payments
        "credit card": "Minimum Debt Payments",
        "loan": "Minimum Debt Payments",
        "student loan": "Minimum Debt Payments",
        
        // WANTS (30%) - Discretionary Spending
        
        // Entertainment & Lifestyle
        "netflix": "Streaming Services",
        "hulu": "Streaming Services",
        "disney": "Streaming Services",
        "spotify": "Streaming Services",
        "apple music": "Streaming Services",
        "cinema": "Movies & Events",
        "movie": "Movies & Events",
        "theater": "Movies & Events",
        "concert": "Movies & Events",
        "game": "Hobbies & Recreation",
        "gym": "Gym & Fitness",
        "fitness": "Gym & Fitness",
        
        // Shopping (Non-essential)
        "amazon": "Shopping",
        "mall": "Shopping",
        "store": "Shopping",
        "shop": "Shopping",
        "retail": "Shopping",
        "clothing": "Clothing",
        "fashion": "Clothing",
        "electronics": "Electronics",
        "best buy": "Electronics",
        "apple store": "Electronics",
        
        // Dining Out
        "restaurant": "Dining Out",
        "mcdonalds": "Dining Out",
        "starbucks": "Dining Out",
        "subway restaurant": "Dining Out",
        "pizza": "Dining Out",
        "cafe": "Dining Out",
        "diner": "Dining Out",
        "bakery": "Dining Out",
        "bar": "Dining Out",
        "pub": "Dining Out",
        
        // Personal Care
        "salon": "Personal Care",
        "spa": "Personal Care",
        "barber": "Personal Care",
        "beauty": "Personal Care",
        
        // Travel & Vacations
        "hotel": "Travel & Vacations",
        "motel": "Travel & Vacations",
        "resort": "Travel & Vacations",
        "airbnb": "Travel & Vacations",
        "airline": "Travel & Vacations",
        "airport": "Travel & Vacations",
        "uber": "Travel & Vacations", // When used for leisure
        "lyft": "Travel & Vacations", // When used for leisure
        "taxi": "Travel & Vacations", // When used for leisure
        
        // Premium Services
        "premium": "Premium Services",
        "subscription": "Premium Services",
        
        // SAVINGS & DEBT REPAYMENT (20%)
        "401k": "401k Contributions",
        "ira": "IRA Contributions",
        "retirement": "Retirement Savings",
        "savings": "General Savings",
        "investment": "Stock Investments",
        "brokerage": "Stock Investments"
    ]
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        self.context = coreDataManager.viewContext
    }
    
    // MARK: - Category Retrieval
    
    func getAllCategories() async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.isDefault, ascending: false),
                    NSSortDescriptor(keyPath: \Category.name, ascending: true)
                ]
                
                do {
                    let categories = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getDefaultCategories() async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "isDefault == YES")
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
                
                do {
                    let categories = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getCustomCategories() async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "isDefault == NO")
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
                
                do {
                    let categories = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getCategoriesByBudgetRule(_ rule: BudgetRule) async throws -> [Category] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                
                // Get parent category for the budget rule
                let parentPredicate = NSPredicate(format: "name == %@ AND parentCategory == nil", rule.rawValue)
                fetchRequest.predicate = parentPredicate
                fetchRequest.fetchLimit = 1
                
                do {
                    let parentCategories = try self.context.fetch(fetchRequest)
                    guard let parentCategory = parentCategories.first else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    // Get subcategories
                    let subcategoriesRequest: NSFetchRequest<Category> = Category.fetchRequest()
                    subcategoriesRequest.predicate = NSPredicate(format: "parentCategory == %@", parentCategory)
                    subcategoriesRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
                    
                    let subcategories = try self.context.fetch(subcategoriesRequest)
                    continuation.resume(returning: subcategories)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Category Management
    
    func createCategory(name: String, colorHex: String, icon: String, parentCategory: Category? = nil) async throws -> Category {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Check if category with same name already exists
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                
                do {
                    let existingCategories = try self.context.fetch(fetchRequest)
                    if !existingCategories.isEmpty {
                        continuation.resume(throwing: CategoryServiceError.categoryAlreadyExists)
                        return
                    }
                    
                    // Create new category
                    let category = Category(context: self.context)
                    category.id = UUID()
                    category.name = name
                    category.colorHex = colorHex
                    category.icon = icon
                    category.isDefault = false
                    category.parentCategory = parentCategory
                    
                    try self.context.save()
                    continuation.resume(returning: category)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateCategory(_ category: Category, name: String? = nil, colorHex: String? = nil, icon: String? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                if let name = name {
                    category.name = name
                }
                if let colorHex = colorHex {
                    category.colorHex = colorHex
                }
                if let icon = icon {
                    category.icon = icon
                }
                
                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteCategory(_ category: Category) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Check if category is being used by any expenses
                if let expenses = category.expenses, expenses.count > 0 {
                    continuation.resume(throwing: CategoryServiceError.categoryInUse)
                    return
                }
                
                // Check if category has subcategories
                if let subcategories = category.subcategories, subcategories.count > 0 {
                    continuation.resume(throwing: CategoryServiceError.categoryHasSubcategories)
                    return
                }
                
                // Don't allow deletion of default categories
                if category.isDefault {
                    continuation.resume(throwing: CategoryServiceError.cannotDeleteDefaultCategory)
                    return
                }
                
                self.context.delete(category)
                
                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Category Suggestion Algorithm
    
    func suggestCategory(for merchantName: String, amount: Decimal? = nil) async throws -> Category? {
        let normalizedMerchant = merchantName.lowercased()
        
        // First, try exact merchant mapping
        for (keyword, categoryName) in merchantCategoryMappings {
            if normalizedMerchant.contains(keyword) {
                if let category = try await getCategoryByName(categoryName) {
                    return category
                }
            }
        }
        
        // If no direct mapping found, use machine learning approach based on historical data
        return try await suggestCategoryFromHistory(merchantName: merchantName, amount: amount)
    }
    
    func suggestCategory(for receiptText: String) async throws -> Category? {
        let normalizedText = receiptText.lowercased()
        
        // Analyze receipt text for category keywords
        var categoryScores: [String: Int] = [:]
        
        for (keyword, categoryName) in merchantCategoryMappings {
            let occurrences = normalizedText.components(separatedBy: keyword).count - 1
            if occurrences > 0 {
                categoryScores[categoryName, default: 0] += occurrences
            }
        }
        
        // Find the category with the highest score
        if let bestCategory = categoryScores.max(by: { $0.value < $1.value }) {
            return try await getCategoryByName(bestCategory.key)
        }
        
        return nil
    }
    
    // MARK: - Category Usage Statistics
    
    func getCategoryUsageStats() async throws -> [CategoryUsageStats] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                
                do {
                    let categories = try self.context.fetch(fetchRequest)
                    var stats: [CategoryUsageStats] = []
                    
                    for category in categories {
                        let expenses = category.expenses?.allObjects as? [Expense] ?? []
                        let usageCount = expenses.count
                        let totalAmount = expenses.reduce(Decimal.zero) { $0 + ($1.amount as Decimal) }
                        let averageAmount = usageCount > 0 ? totalAmount / Decimal(usageCount) : Decimal.zero
                        let lastUsed = expenses.max(by: { $0.date < $1.date })?.date
                        
                        let stat = CategoryUsageStats(
                            category: category,
                            usageCount: usageCount,
                            totalAmount: totalAmount,
                            averageAmount: averageAmount,
                            lastUsed: lastUsed
                        )
                        stats.append(stat)
                    }
                    
                    // Sort by usage count descending
                    stats.sort { $0.usageCount > $1.usageCount }
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Budget Rule Management
    
    func getBudgetRuleStats(for rule: BudgetRule, period: DateInterval) async throws -> BudgetRuleStats {
        // Get categories for this budget rule
        let categories = try await getCategoriesByBudgetRule(rule)
        
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    
                    // Calculate total spent in this rule for the period
                    var totalSpent = Decimal.zero
                    var categoryStats: [CategoryUsageStats] = []
                    
                    for category in categories {
                        let expenses = category.expenses?.allObjects as? [Expense] ?? []
                        let periodExpenses = expenses.filter { expense in
                            period.contains(expense.date)
                        }
                        
                        let categoryTotal = periodExpenses.reduce(Decimal.zero) { $0 + ($1.amount as Decimal) }
                        totalSpent += categoryTotal
                        
                        let usageCount = periodExpenses.count
                        let averageAmount = usageCount > 0 ? categoryTotal / Decimal(usageCount) : Decimal.zero
                        let lastUsed = periodExpenses.max(by: { $0.date < $1.date })?.date
                        
                        let stat = CategoryUsageStats(
                            category: category,
                            usageCount: usageCount,
                            totalAmount: categoryTotal,
                            averageAmount: averageAmount,
                            lastUsed: lastUsed
                        )
                        categoryStats.append(stat)
                    }
                    
                    // Calculate target amount (this would typically come from user's total budget)
                    // For now, we'll use a placeholder calculation
                    let estimatedMonthlyIncome = Decimal(5000) // This should come from user settings
                    let targetAmount = estimatedMonthlyIncome * Decimal(rule.percentage)
                    
                    let percentageUsed = targetAmount > 0 ? Double(truncating: totalSpent as NSNumber) / Double(truncating: targetAmount as NSNumber) : 0.0
                    let isOverBudget = totalSpent > targetAmount
                    
                    let stats = BudgetRuleStats(
                        rule: rule,
                        totalSpent: totalSpent,
                        targetAmount: targetAmount,
                        percentageUsed: percentageUsed,
                        categories: categoryStats,
                        isOverBudget: isOverBudget
                    )
                    
                    continuation.resume(returning: stats)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func initializeBudgetRuleCategories() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // Check if budget rule categories already exist
                    let existingRulesRequest: NSFetchRequest<Category> = Category.fetchRequest()
                    existingRulesRequest.predicate = NSPredicate(format: "parentCategory == nil AND isDefault == YES")
                    let existingRules = try self.context.fetch(existingRulesRequest)
                    
                    // Only initialize if no budget rule categories exist
                    if existingRules.isEmpty {
                        try self.createBudgetRuleHierarchy()
                    }
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func createBudgetRuleHierarchy() throws {
        // Create parent categories for each budget rule
        for rule in BudgetRule.allCases {
            let parentCategory = Category(context: context)
            parentCategory.id = UUID()
            parentCategory.name = rule.rawValue
            parentCategory.colorHex = rule.color
            parentCategory.icon = rule.icon
            parentCategory.isDefault = true
            parentCategory.parentCategory = nil
            
            // Create default subcategories for each rule
            let subcategories = getDefaultSubcategories(for: rule)
            for (name, icon, color) in subcategories {
                let subcategory = Category(context: context)
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
    
    // MARK: - Private Helper Methods
    
    private func getCategoryByName(_ name: String) async throws -> Category? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                fetchRequest.fetchLimit = 1
                
                do {
                    let categories = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: categories.first)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func suggestCategoryFromHistory(merchantName: String, amount: Decimal?) async throws -> Category? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                // Find expenses with similar merchant names
                let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "merchant CONTAINS[cd] %@", merchantName)
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                fetchRequest.fetchLimit = 10
                
                do {
                    let similarExpenses = try self.context.fetch(fetchRequest)
                    
                    if !similarExpenses.isEmpty {
                        // Find the most commonly used category for this merchant
                        var categoryFrequency: [Category: Int] = [:]
                        
                        for expense in similarExpenses {
                            if let category = expense.category {
                                categoryFrequency[category, default: 0] += 1
                            }
                        }
                        
                        // Return the most frequent category
                        let mostFrequentCategory = categoryFrequency.max { $0.value < $1.value }?.key
                        continuation.resume(returning: mostFrequentCategory)
                    } else {
                        // If no historical data, suggest based on amount ranges
                        let suggestedCategory = self.suggestCategoryByAmount(amount)
                        continuation.resume(returning: suggestedCategory)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func suggestCategoryByAmount(_ amount: Decimal?) -> Category? {
        // This is a simple heuristic based on amount ranges
        guard let amount = amount else { return nil }
        
        // These are just example thresholds - could be made configurable
        if amount < 10 {
            // Small amounts might be food/coffee
            return getCategoryByNameSync("Dining Out") ?? getCategoryByNameSync("Food")
        } else if amount < 50 {
            // Medium amounts might be groceries, entertainment, or personal care
            return getCategoryByNameSync("Groceries") ?? getCategoryByNameSync("Entertainment") ?? getCategoryByNameSync("Personal Care")
        } else if amount < 100 {
            // Larger amounts might be shopping or transportation
            return getCategoryByNameSync("Shopping") ?? getCategoryByNameSync("Transportation")
        } else if amount < 200 {
            // Even larger amounts might be utilities or healthcare
            return getCategoryByNameSync("Utilities") ?? getCategoryByNameSync("Healthcare")
        } else {
            // Very large amounts might be housing, travel, or major purchases
            return getCategoryByNameSync("Housing") ?? getCategoryByNameSync("Travel")
        }
    }
    
    private func getCategoryByNameSync(_ name: String) -> Category? {
        return context.performAndWait {
            let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "name == %@", name)
            fetchRequest.fetchLimit = 1
            
            do {
                let categories = try self.context.fetch(fetchRequest)
                return categories.first
            } catch {
                print("Error fetching category by name: \(error)")
                return nil
            }
        }
    }
}
