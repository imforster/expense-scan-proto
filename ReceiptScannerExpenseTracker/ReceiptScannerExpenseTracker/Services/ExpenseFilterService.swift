import Foundation
import CoreData

class ExpenseFilterService {
    
    struct FilterCriteria {
        var searchText: String?
        var category: CategoryData?
        var dateRange: DateInterval?
        var amountRange: ClosedRange<Decimal>?
        var vendor: String?
        
        init(
            searchText: String? = nil,
            category: CategoryData? = nil,
            dateRange: DateInterval? = nil,
            amountRange: ClosedRange<Decimal>? = nil,
            vendor: String? = nil
        ) {
            self.searchText = searchText
            self.category = category
            self.dateRange = dateRange
            self.amountRange = amountRange
            self.vendor = vendor
        }
        
        var isEmpty: Bool {
            return searchText?.isEmpty != false &&
                   category == nil &&
                   dateRange == nil &&
                   amountRange == nil &&
                   vendor == nil
        }
        
        var activeFiltersDescription: String {
            var descriptions: [String] = []
            
            if let searchText = searchText, !searchText.isEmpty {
                descriptions.append("Search: \(searchText)")
            }
            
            if let category = category {
                descriptions.append("Category: \(category.name)")
            }
            
            if let dateRange = dateRange {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                let start = formatter.string(from: dateRange.start)
                let end = formatter.string(from: dateRange.end)
                descriptions.append("Date: \(start) - \(end)")
            }
            
            if let amountRange = amountRange {
                descriptions.append("Amount: $\(amountRange.lowerBound) - $\(amountRange.upperBound)")
            }
            
            if let vendor = vendor {
                descriptions.append("Vendor: \(vendor)")
            }
            
            return descriptions.joined(separator: ", ")
        }
    }
    
    func filter(_ expenses: [Expense], with criteria: FilterCriteria) -> [Expense] {
        return expenses.filter { expense in
            // Search text filter
            if let searchText = criteria.searchText, !searchText.isEmpty {
                let searchLower = searchText.lowercased()
                let matchesSearch = expense.merchant.lowercased().contains(searchLower) ||
                                  expense.safeNotes.lowercased().contains(searchLower) ||
                                  expense.safeCategoryName.lowercased().contains(searchLower)
                if !matchesSearch {
                    return false
                }
            }
            
            // Category filter
            if let categoryData = criteria.category {
                guard let expenseCategory = expense.category,
                      expenseCategory.id == categoryData.id else {
                    return false
                }
            }
            
            // Date range filter
            if let dateRange = criteria.dateRange {
                if !dateRange.contains(expense.date) {
                    return false
                }
            }
            
            // Amount range filter
            if let amountRange = criteria.amountRange {
                let expenseAmount = expense.amount.decimalValue
                if !amountRange.contains(expenseAmount) {
                    return false
                }
            }
            
            // Vendor filter
            if let vendor = criteria.vendor {
                if expense.merchant != vendor {
                    return false
                }
            }
            
            return true
        }
    }
}

struct CategoryData: Equatable {
    let id: UUID
    let name: String
}
