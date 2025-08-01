import Foundation
import CoreData
import SwiftUI
import Combine

@MainActor
class ExpenseListViewModel: ObservableObject {
    
    // MARK: - ViewState Enum
    
    /// Represents the current state of the expense list view
    enum ViewState: Equatable {
        case loading
        case loaded([Expense])
        case empty
        case error(ExpenseError)
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading), (.empty, .empty):
                return true
            case (.loaded(let lhsExpenses), .loaded(let rhsExpenses)):
                return lhsExpenses.count == rhsExpenses.count
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var viewState: ViewState = .loading
    @Published var displayedExpenses: [Expense] = []
    @Published var filterCriteria = ExpenseFilterService.FilterCriteria()
    @Published var sortOption: ExpenseSortService.SortOption = .dateDescending
    
    // Individual filter properties for UI binding
    @Published var searchText: String = ""
    @Published var selectedCategory: Category? = nil
    @Published var selectedDateRange: DateRange = .all
    @Published var selectedAmountRange: AmountRange = .all
    @Published var selectedVendor: String? = nil
    @Published var customDateRange: DateInterval? = nil
    @Published var customAmountRange: ClosedRange<Decimal>? = nil
    
    // MARK: - Private Properties
    
    private let dataService: ExpenseDataService
    private let filterService: ExpenseFilterService
    private let sortService: ExpenseSortService
    internal var cancellables = Set<AnyCancellable>()
    private var lastCoreDataChangeTime: Date = Date.distantPast
    private var sortDebounceTask: Task<Void, Never>?
    private let changeDebounceInterval: TimeInterval = 0.2 // 200ms debounce

    // MARK: - Initialization
    
    init(
        dataService: ExpenseDataService? = nil,
        filterService: ExpenseFilterService = ExpenseFilterService(),
        sortService: ExpenseSortService = ExpenseSortService()
    ) {
        self.dataService = dataService ?? ExpenseDataService()
        self.filterService = filterService
        self.sortService = sortService
        
        setupBindings()
        setupFilterObservers()
    }
    
    // MARK: - Setup Methods
    
    /// Sets up reactive bindings between services and view model
    private func setupBindings() {
        // Observe data service changes
        dataService.$expenses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expenses in
                self?.lastCoreDataChangeTime = Date()
                self?.handleExpensesUpdate(expenses)
            }
            .store(in: &cancellables)
        
        dataService.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.handleLoadingStateChange(isLoading)
            }
            .store(in: &cancellables)
        
        dataService.$error
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.handleErrorStateChange(error)
            }
            .store(in: &cancellables)
        
        // Listen for Core Data save notifications to track changes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.lastCoreDataChangeTime = Date()
            }
            .store(in: &cancellables)
    }
    
    /// Sets up observers for filter property changes
    private func setupFilterObservers() {
        // Combine all filter properties into a single publisher
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(300), scheduler: DispatchQueue.main),
            $selectedCategory,
            $selectedDateRange,
            $selectedAmountRange
        )
        .combineLatest(
            Publishers.CombineLatest4(
                $selectedVendor,
                $customDateRange,
                $customAmountRange,
                $sortOption
            )
        )
        .sink { [weak self] filterData, additionalData in
            self?.updateFilterCriteria(
                searchText: filterData.0,
                category: filterData.1,
                dateRange: filterData.2,
                amountRange: filterData.3,
                vendor: additionalData.0,
                customDateRange: additionalData.1,
                customAmountRange: additionalData.2,
                sortOption: additionalData.3
            )
        }
        .store(in: &cancellables)
    }

    // MARK: - Public Methods
    
    /// Loads expenses using the data service
    func loadExpenses() async {
        await dataService.loadExpenses()
    }
    
    /// Refreshes the expense data
    func refreshExpenses() async {
        await dataService.refreshExpenses()
    }
    
    /// Deletes an expense
    func deleteExpense(_ expense: Expense) async {
        do {
            try await dataService.deleteExpense(expense)
        } catch {
            // Error is handled by the data service and propagated through bindings
        }
    }

    // MARK: - Private Methods - State Management
    
    /// Handles updates from the data service
    private func handleExpensesUpdate(_ expenses: [Expense]) {
        Task {
            await applyFiltersAndSort(to: expenses)
        }
    }
    
    /// Handles loading state changes from the data service
    private func handleLoadingStateChange(_ isLoading: Bool) {
        if isLoading && viewState != .loading {
            viewState = .loading
        }
    }
    
    /// Handles error state changes from the data service
    private func handleErrorStateChange(_ error: ExpenseError?) {
        if let error = error {
            viewState = .error(error)
        }
    }
    
    /// Updates filter criteria based on UI property changes
    private func updateFilterCriteria(
        searchText: String,
        category: Category?,
        dateRange: DateRange,
        amountRange: AmountRange,
        vendor: String?,
        customDateRange: DateInterval?,
        customAmountRange: ClosedRange<Decimal>?,
        sortOption: ExpenseSortService.SortOption
    ) {
        // Convert UI properties to filter criteria
        let dateInterval = (dateRange == .custom) ? customDateRange : dateRange.dateInterval
        let amountRangeValue = (amountRange == .custom) ? customAmountRange : amountRange.range
        
        let categoryData = category.map { CategoryData(id: $0.id, name: $0.name) }
        
        filterCriteria = ExpenseFilterService.FilterCriteria(
            searchText: searchText.isEmpty ? nil : searchText,
            category: categoryData,
            dateRange: dateInterval,
            amountRange: amountRangeValue,
            vendor: vendor
        )
        
        self.sortOption = sortOption
        
        // Apply filters to current expenses
        Task {
            await applyFiltersAndSort(to: dataService.expenses)
        }
    }
    
    /// Applies filters and sorting using the services with debouncing
    private func applyFiltersAndSort(to expenses: [Expense]) async {
        // Cancel any existing sort operation
        sortDebounceTask?.cancel()
        
        sortDebounceTask = Task {
            // Debounce rapid successive calls
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms debounce
            
            guard !Task.isCancelled else { return }
            
            guard !expenses.isEmpty else {
                await MainActor.run {
                    self.displayedExpenses = []
                    self.viewState = .empty
                }
                return
            }
            
            // Add defensive delay if Core Data changes occurred recently
            let timeSinceLastChange = Date().timeIntervalSince(lastCoreDataChangeTime)
            if timeSinceLastChange < changeDebounceInterval {
                let delayNanoseconds = UInt64((changeDebounceInterval - timeSinceLastChange) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNanoseconds)
            }
            
            guard !Task.isCancelled else { return }
            
            // Apply filtering
            let filteredExpenses = filterService.filter(expenses, with: filterCriteria)
            
            guard !Task.isCancelled else { return }
            
            // Apply sorting with enhanced error handling
            let sortedExpenses = await sortService.sortAsync(filteredExpenses, by: sortOption)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.displayedExpenses = sortedExpenses
                
                if sortedExpenses.isEmpty && !filterCriteria.isEmpty {
                    // No results after filtering
                    self.viewState = .empty
                } else {
                    self.viewState = .loaded(sortedExpenses)
                }
            }
        }
        
        await sortDebounceTask?.value
    }
    
    /// Checks if Core Data changes occurred recently
    private func hasRecentCoreDataChanges() -> Bool {
        let timeSinceLastChange = Date().timeIntervalSince(lastCoreDataChangeTime)
        return timeSinceLastChange < changeDebounceInterval
    }

    // MARK: - Filter Management
    
    /// Clears all active filters
    func clearAllFilters() {
        searchText = ""
        selectedCategory = nil
        selectedDateRange = .all
        selectedAmountRange = .all
        selectedVendor = nil
        customDateRange = nil
        customAmountRange = nil
    }
    
    /// Updates the sort option and applies it
    func updateSort(_ option: ExpenseSortService.SortOption) async {
        sortOption = option
        await applyFiltersAndSort(to: dataService.expenses)
    }
    
    /// Applies filters without changing sort
    func applyFilters() async {
        await applyFiltersAndSort(to: dataService.expenses)
    }

    // MARK: - Computed Properties
    
    /// Returns true if any filters are currently active
    var hasActiveFilters: Bool {
        return !filterCriteria.isEmpty
    }
    
    /// Returns a summary of active filters for display
    var filterSummary: String {
        return filterCriteria.activeFiltersDescription
    }
    
    /// Returns the current error if in error state
    var currentError: ExpenseError? {
        if case .error(let error) = viewState {
            return error
        }
        return nil
    }
    
    /// Returns true if the view is currently loading
    var isLoading: Bool {
        return viewState == .loading
    }
    
    /// Returns true if there are no expenses to display
    var isEmpty: Bool {
        return viewState == .empty
    }
    
    // MARK: - Helper Methods
    
    /// Gets unique vendors from all expenses for filter options
    func getUniqueVendors() -> [String] {
        let allExpenses = dataService.expenses
        guard !allExpenses.isEmpty else { return [] }
        return Array(Set(allExpenses.map { $0.merchant })).sorted()
    }
    
    /// Gets available categories for filter options
    func getAvailableCategories() -> [Category] {
        // This would typically come from a category service
        // For now, we'll extract from existing expenses
        let allExpenses = dataService.expenses
        let categories = allExpenses.compactMap { $0.category }
        return Array(Set(categories)).sorted { $0.name < $1.name }
    }
    
    /// Retries the last failed operation
    func retryLastOperation() async {
        if case .error = viewState {
            await loadExpenses()
        }
    }
    
    /// Clears the current error state
    func clearError() {
        dataService.clearErrors()
        if case .error = viewState {
            viewState = .loading
            Task {
                await loadExpenses()
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
