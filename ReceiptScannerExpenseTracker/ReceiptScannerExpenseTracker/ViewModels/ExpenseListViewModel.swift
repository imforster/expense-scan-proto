import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class ExpenseListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var filteredExpenses: [Expense] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Filter & Sort Properties with Observers
    // Any change to these properties will trigger a recalculation of the filtered list.
    @Published var searchText: String = "" { didSet { updateFilteredExpenses() } }
    @Published var selectedCategory: Category? = nil { didSet { updateFilteredExpenses() } }
    @Published var selectedDateRange: DateRange = .all { didSet { updateFilteredExpenses() } }
    @Published var selectedAmountRange: AmountRange = .all { didSet { updateFilteredExpenses() } }
    @Published var selectedVendor: String? = nil { didSet { updateFilteredExpenses() } }
    @Published var sortOption: SortOption = .dateDescending { didSet { updateFilteredExpenses() } }
    @Published var customDateRange: DateInterval? = nil { didSet { updateFilteredExpenses() } }
    @Published var customAmountRange: ClosedRange<Decimal>? = nil { didSet { updateFilteredExpenses() } }

    // MARK: - Private State
    private var sourceExpenses: [Expense] = []
    private let context: NSManagedObjectContext
    private var cancellables = Set<AnyCancellable>()

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Data Loading
    func loadExpenses() {
        isLoading = true
        errorMessage = nil
        
        // Defer the fetch to the next run loop cycle.
        // This gives the SwiftUI view time to finish its initial setup,
        // preventing a race condition on the first load.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let request: NSFetchRequest<Expense> = Expense.fetchRequest()
            
            do {
                self.sourceExpenses = try self.context.fetch(request)
                // After fetching, immediately apply filters.
                self.updateFilteredExpenses()
            } catch {
                self.errorMessage = "Failed to load expenses: \(error.localizedDescription)"
                self.sourceExpenses = []
            }
            
            self.isLoading = false
        }
    }

    // MARK: - Core Filtering and Sorting Logic
    private func updateFilteredExpenses() {
        var filtered = sourceExpenses

        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.safeMerchant.localizedCaseInsensitiveContains(searchText) ||
                $0.safeNotes.localizedCaseInsensitiveContains(searchText) ||
                $0.safeCategoryName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Apply date range filter
        if let dateInterval = (selectedDateRange == .custom) ? customDateRange : selectedDateRange.dateInterval {
            filtered = filtered.filter { dateInterval.contains($0.date) }
        }
        
        // Apply amount range filter
        if let amountRange = (selectedAmountRange == .custom) ? customAmountRange : selectedAmountRange.range {
            filtered = filtered.filter { amountRange.contains($0.amount.decimalValue) }
        }
        
        // Apply vendor filter
        if let vendor = selectedVendor, !vendor.isEmpty {
            filtered = filtered.filter { $0.safeMerchant == vendor }
        }
        
        // Apply sorting and update the published property
        self.filteredExpenses = sortExpenses(filtered, by: sortOption)
    }
    
    private func sortExpenses(_ expenses: [Expense], by sortOption: SortOption) -> [Expense] {
        switch sortOption {
        case .dateAscending: return expenses.sorted { $0.date < $1.date }
        case .dateDescending: return expenses.sorted { $0.date > $1.date }
        case .amountAscending: return expenses.sorted { $0.amount.decimalValue < $1.amount.decimalValue }
        case .amountDescending: return expenses.sorted { $0.amount.decimalValue > $1.amount.decimalValue }
        case .merchantAscending: return expenses.sorted { $0.safeMerchant.localizedCaseInsensitiveCompare($1.safeMerchant) == .orderedAscending }
        case .merchantDescending: return expenses.sorted { $0.safeMerchant.localizedCaseInsensitiveCompare($1.safeMerchant) == .orderedDescending }
        }
    }

    // MARK: - User Actions
    func clearAllFilters() {
        searchText = ""
        selectedCategory = nil
        selectedDateRange = .all
        selectedAmountRange = .all
        selectedVendor = nil
        customDateRange = nil
        customAmountRange = nil
    }
    
    func deleteExpense(_ expense: Expense) {
        context.delete(expense)
        do {
            try context.save()
            loadExpenses()
        } catch {
            errorMessage = "Failed to delete expense: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers
    func getUniqueVendors() -> [String] {
        return Array(Set(sourceExpenses.map { $0.safeMerchant })).sorted()
    }
    
    func getAvailableCategories() -> [Category] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.name, ascending: true)]
        do {
            return try context.fetch(request)
        } catch {
            return []
        }
    }
    
    var hasActiveFilters: Bool {
        return !searchText.isEmpty || selectedCategory != nil || selectedDateRange != .all || selectedAmountRange != .all || selectedVendor != nil
    }
    
    var filterSummary: String {
        var components: [String] = []
        if !searchText.isEmpty { components.append("Search: \(searchText)") }
        if let category = selectedCategory { components.append("Category: \(category.safeName)") }
        if selectedDateRange != .all { components.append("Date: \(selectedDateRange.rawValue)") }
        if selectedAmountRange != .all { components.append("Amount: \(selectedAmountRange.rawValue)") }
        if let vendor = selectedVendor { components.append("Vendor: \(vendor)") }
        return components.joined(separator: ", ")
    }
    
    // MARK: - Enums
    enum SortOption: String, CaseIterable {
        case dateAscending = "Date (Oldest First)"
        case dateDescending = "Date (Newest First)"
        case amountAscending = "Amount (Low to High)"
        case amountDescending = "Amount (High to Low)"
        case merchantAscending = "Merchant (A-Z)"
        case merchantDescending = "Merchant (Z-A)"
        
        var systemImage: String {
            switch self {
            case .dateAscending, .dateDescending: return "calendar"
            case .amountAscending, .amountDescending: return "dollarsign.circle"
            case .merchantAscending, .merchantDescending: return "building.2"
            }
        }
    }
    
    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case lastMonth = "Last Month"
        case thisYear = "This Year"
        case custom = "Custom Range"
        
        var systemImage: String {
            switch self {
            case .all: return "calendar"
            case .today: return "calendar.badge.clock"
            case .thisWeek: return "calendar.badge.plus"
            case .thisMonth, .lastMonth: return "calendar.circle"
            case .thisYear: return "calendar.badge.exclamationmark"
            case .custom: return "calendar.badge.minus"
            }
        }
        
        var dateInterval: DateInterval? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .all, .custom: return nil
            case .today:
                let startOfDay = calendar.startOfDay(for: now)
                guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
                return DateInterval(start: startOfDay, end: endOfDay)
            case .thisWeek:
                guard let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
                      let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek) else { return nil }
                return DateInterval(start: startOfWeek, end: endOfWeek)
            case .thisMonth:
                guard let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start,
                      let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) else { return nil }
                return DateInterval(start: startOfMonth, end: endOfMonth)
            case .lastMonth:
                guard let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start,
                      let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) else { return nil }
                return DateInterval(start: startOfLastMonth, end: startOfThisMonth)
            case .thisYear:
                guard let startOfYear = calendar.dateInterval(of: .year, for: now)?.start,
                      let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear) else { return nil }
                return DateInterval(start: startOfYear, end: endOfYear)
            }
        }
    }
    
    enum AmountRange: String, CaseIterable {
        case all = "All Amounts"
        case under25 = "Under $25"
        case between25And100 = "$25 - $100"
        case between100And500 = "$100 - $500"
        case over500 = "Over $500"
        case custom = "Custom Range"
        
        var systemImage: String { return "dollarsign.circle" }
        
        var range: ClosedRange<Decimal>? {
            switch self {
            case .all, .custom: return nil
            case .under25: return 0...25
            case .between25And100: return 25...100
            case .between100And500: return 100...500
            case .over500: return 500...Decimal.greatestFiniteMagnitude
            }
        }
    }
}
