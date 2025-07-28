import SwiftUI
import CoreData

// Ensure we're using the SearchBar from CustomNavigation.swift
typealias SearchBarView = SearchBar

struct ExpenseListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: ExpenseListViewModel
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedExpense: Expense?
    @State private var showingAddExpense = false
    
    init() {
        // Ensure ExpenseListViewModel uses the same context as the view
        let dataService = ExpenseDataService(context: CoreDataManager.shared.viewContext)
        self._viewModel = StateObject(wrappedValue: ExpenseListViewModel(dataService: dataService))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Navigation Bar
            CustomNavigationBar(title: "Expenses", showBackButton: false) {
                HStack(spacing: 12) {
                    // Sort button
                    Button(action: { showingSortOptions = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primaryColor)
                            .padding(8)
                            .background(AppTheme.cardBackgroundColor)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                    .accessibilityLabel("Sort options")
                    
                    // Filter button
                    Button(action: { showingFilters = true }) {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primaryColor)
                            .padding(8)
                            .background(AppTheme.cardBackgroundColor)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                    .accessibilityLabel("Filter options")
                    
                    // Add expense button
                    Button(action: { showingAddExpense = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.primaryColor)
                            .padding(8)
                            .background(AppTheme.cardBackgroundColor)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            
            // Search Bar
            SearchBarView(text: $viewModel.searchText, placeholder: "Search expenses, merchants, or notes")
                .padding(.top, 8)
            
            // Active Filters Summary
            if viewModel.hasActiveFilters {
                HStack {
                    Text("Filters: \(viewModel.filterSummary)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        viewModel.clearAllFilters()
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.primaryColor)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
            }
            
            // Content
            if viewModel.isLoading {
                LoadingView(message: "Loading expenses...")
            } else if let error = viewModel.currentError {
                ErrorView(
                    title: "Error Loading Expenses",
                    message: error.localizedDescription,
                    retryAction: { 
                        Task {
                            await viewModel.retryLastOperation()
                        }
                    }
                )
            } else if viewModel.displayedExpenses.isEmpty {
                emptyStateView
            } else {
                expenseListContent
            }
        }
        .background(AppTheme.backgroundColor)
        .sheet(isPresented: $showingFilters) {
            ExpenseFiltersView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingSortOptions) {
            ExpenseSortView(viewModel: viewModel)
        }
        .sheet(item: $selectedExpense) { expense in
            NavigationView {
                ExpenseDetailView(expense: expense)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            ExpenseEditView(context: CoreDataManager.shared.viewContext)
                .onDisappear {
                    Task {
                        await viewModel.refreshExpenses()
                    }
                }
        }
        .onAppear {
            Task {
                await viewModel.loadExpenses()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
            Task {
                await viewModel.refreshExpenses()
            }
        }
    }
    
    private var emptyStateView: some View {
        EmptyStateView(
            title: viewModel.hasActiveFilters ? "No Matching Expenses" : "No Expenses Yet",
            message: viewModel.hasActiveFilters ? 
                "Try adjusting your filters to see more results." :
                "Start by scanning a receipt or adding an expense manually.",
            systemImage: viewModel.hasActiveFilters ? "magnifyingglass" : "doc.text.magnifyingglass",
            actionTitle: viewModel.hasActiveFilters ? "Clear Filters" : "Add Expense",
            action: viewModel.hasActiveFilters ? 
                { viewModel.clearAllFilters() } : 
                { showingAddExpense = true }
        )
    }
    
    private var expenseListContent: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.displayedExpenses, id: \.id) { expense in
                    ExpenseRowView(expense: expense) {
                        selectedExpense = expense
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Expense Row View
struct ExpenseRowView: View {
    let expense: Expense
    let onTap: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(expense.safeCategoryColor)
                    .frame(width: 4, height: 60)
                
                // Category icon
                VStack {
                    Image(systemName: expense.safeCategoryIcon)
                        .font(.system(size: 20))
                        .foregroundColor(expense.safeCategoryColor)
                        .frame(width: 40, height: 40)
                        .background(expense.safeCategoryColor.opacity(0.1))
                        .cornerRadius(8)
                    
                    Spacer()
                }
                
                // Expense details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(expense.safeMerchant)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(expense.formattedAmount())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text(expense.safeCategoryName)
                            .font(.subheadline)
                            .foregroundColor(expense.safeCategoryColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(expense.safeCategoryColor.opacity(0.1))
                            .cornerRadius(12)
                        
                        Spacer()
                        
                        Text(expense.formattedDate())
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !expense.safeNotes.isEmpty {
                        Text(expense.safeNotes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if expense.isRecurring {
                        HStack {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("Recurring")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Spacer()
                        }
                    }
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(AppTheme.cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Expense from \(expense.safeMerchant) for \(expense.formattedAmount()) on \(expense.formattedDate())")
        .accessibilityHint("Tap to view details")
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
struct ExpenseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExpenseListView()
    }
}
#endif