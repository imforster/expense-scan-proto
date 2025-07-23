import SwiftUI
import CoreData

struct ExpenseListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: ExpenseListViewModel
    @State private var showingFilters = false
    @State private var showingSortOptions = false
    @State private var selectedExpense: Expense?
    @State private var showingExpenseDetail = false
    @State private var showingAddExpense = false
    
    init(context: NSManagedObjectContext) {
        self._viewModel = StateObject(wrappedValue: ExpenseListViewModel(context: context))
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
                            .background(Color.white)
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
                            .background(Color.white)
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
                            .background(Color.white)
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.1), radius: 2)
                    }
                    .accessibilityLabel("Add expense")
                }
            }
            
            // Search Bar
            SearchBar(text: $viewModel.searchText, placeholder: "Search expenses, merchants, or notes")
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
                .background(Color(.systemGray6))
            }
            
            // Content
            if viewModel.isLoading {
                LoadingView(message: "Loading expenses...")
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(
                    title: "Error Loading Expenses",
                    message: errorMessage,
                    retryAction: { viewModel.loadExpenses() }
                )
            } else if viewModel.filteredExpenses.isEmpty {
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
        .sheet(isPresented: $showingExpenseDetail) {
            if let expense = selectedExpense {
                NavigationView {
                    ExpenseDetailView(expenseID: expense.objectID)
                }
            }
        }
        .sheet(isPresented: $showingAddExpense) {
            ExpenseEditView(context: viewContext)
                .onDisappear {
                    viewModel.loadExpenses()
                }
        }
        .onAppear {
            viewModel.loadExpenses()
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
                ForEach(viewModel.filteredExpenses, id: \.id) { expense in
                    ExpenseRowView(expense: expense) {
                        selectedExpense = expense
                        // Fire the fault to ensure all data is loaded
                        let _ = selectedExpense?.merchant
                        showingExpenseDetail = true
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
            .background(Color.white)
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
        ExpenseListView(context: PersistenceController.preview.container.viewContext)
    }
}
#endif