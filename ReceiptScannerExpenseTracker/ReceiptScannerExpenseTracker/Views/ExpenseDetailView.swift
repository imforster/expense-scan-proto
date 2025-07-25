import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    // Use the new ViewModel with state machine
    @StateObject private var viewModel: ExpenseDetailViewModel
    
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    // Initialize with the expenseID and create the ViewModel
    init(expenseID: NSManagedObjectID) {
        // Create the data service and view model
        let dataService = ExpenseDataService()
        _viewModel = StateObject(wrappedValue: ExpenseDetailViewModel(dataService: dataService, expenseID: expenseID))
    }
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.backgroundColor.ignoresSafeArea()
            
            // Content based on view state
            Group {
                switch viewModel.viewState {
                case .loading:
                    loadingView
                case .loaded(let expense):
                    expenseDetailContent(expense: expense)
                case .error(let error):
                    errorView(error: error)
                case .deleted:
                    deletedView
                }
            }
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button("Close") {
                dismiss()
            },
            trailing: navigationBarTrailingItems
        )
        .sheet(isPresented: $showingEditView, onDismiss: {
            // Simply dismiss the view after editing to avoid any CoreData issues
            dismiss()
            
            // Post notification that expense was edited
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
            }
        }) {
            if let expense = viewModel.expense {
                ExpenseEditView(expense: expense, context: viewContext)
            }
        }
        .alert("Delete Expense", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteExpense()
            }
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading expense details...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(error: ExpenseError) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text(viewModel.userFriendlyErrorMessage())
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text(viewModel.recoverySuggestion())
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.isErrorRecoverable() {
                Button(action: {
                    Task {
                        await viewModel.recoverFromError()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .padding()
                    .background(AppTheme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.recoveryInProgress)
                .opacity(viewModel.recoveryInProgress ? 0.6 : 1.0)
                .overlay(
                    Group {
                        if viewModel.recoveryInProgress {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding(.leading, -25)
                        }
                    }
                )
            }
        }
        .padding()
    }
    
    private var deletedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "trash.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("This expense has been deleted")
                .font(.headline)
            
            Text("You can return to the expense list")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                dismiss()
            }) {
                Text("Return to Expense List")
                    .padding()
                    .background(AppTheme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
    
    private var navigationBarTrailingItems: some View {
        Group {
            if case .loaded = viewModel.viewState {
                Menu {
                    Button(action: { showingEditView = true }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(isDeleting)
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .disabled(isDeleting)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(isDeleting)
            } else {
                // Empty view when not in loaded state
                EmptyView()
            }
        }
    }
    
    private func expenseDetailContent(expense: Expense) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                // Header Card
                self.headerCard(expense: expense)
                
                // Receipt Image (if available)
                if let receipt = expense.receipt {
                    self.receiptImageCard(receipt: receipt)
                }
                
                // Expense Details
                self.detailsCard(expense: expense)
                
                // Items (if available)
                if !expense.safeExpenseItems.isEmpty {
                    self.itemsCard(items: expense.safeExpenseItems)
                }
                
                // Tags (if available)
                if !expense.safeTags.isEmpty {
                    self.tagsCard(tags: expense.safeTags)
                }
                
                // Notes (if available)
                if !expense.safeNotes.isEmpty {
                    self.notesCard(notes: expense.safeNotes)
                }
                
                // Action Buttons
                self.actionButtons
            }
            .padding()
        }
        .refreshable {
            await viewModel.refreshExpense()
        }
    }
    
    private func headerCard(expense: Expense) -> some View {
        CardView {
            VStack(spacing: 16) {
                // Amount
                Text(expense.formattedAmount())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                // Merchant
                Text(expense.safeMerchant)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                // Date
                Text(expense.formattedDate())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Category
                if let category = expense.category {
                    HStack {
                        Image(systemName: category.safeIcon)
                            .foregroundColor(category.color)
                        
                        Text(category.safeName)
                            .font(.subheadline)
                            .foregroundColor(category.color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(category.color.opacity(0.1))
                    .cornerRadius(16)
                }
                
                // Recurring indicator
                if expense.isRecurring {
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "repeat")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("Recurring Expense")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        // Extract recurring pattern if available
                        if let notes = expense.notes,
                           let patternRange = notes.range(of: "\\[Recurring: ([^\\]]+)\\]", options: .regularExpression) {
                            let patternString = String(notes[patternRange])
                                .replacingOccurrences(of: "[Recurring: ", with: "")
                                .replacingOccurrences(of: "]", with: "")
                            
                            Text(patternString)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func receiptImageCard(receipt: Receipt) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.image")
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Receipt Image")
                        .font(.headline)
                    
                    Spacer()
                }
                
                // Placeholder for receipt image
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "doc.text.image")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Receipt Image")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.top, 8)
                        }
                    )
            }
        }
    }
    
    private func detailsCard(expense: Expense) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Details")
                        .font(.headline)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    DetailRow(label: "Amount", value: expense.formattedAmount())
                    DetailRow(label: "Date", value: expense.formattedDate())
                    DetailRow(label: "Merchant", value: expense.safeMerchant)
                    
                    DetailRow(label: "Category", value: expense.safeCategoryName)
                    
                    if !expense.safePaymentMethod.isEmpty && expense.safePaymentMethod != "Unknown" {
                        DetailRow(label: "Payment Method", value: expense.safePaymentMethod)
                    }
                    
                    DetailRow(label: "Recurring", value: expense.isRecurring ? "Yes" : "No")
                }
            }
        }
    }
    
    private func itemsCard(items: [ExpenseItem]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "list.bullet")
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Items")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        HStack {
                            Text(item.safeName)
                                .font(.body)
                            
                            Spacer()
                            
                            Text(item.formattedAmount())
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                        
                        if item != items.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }
    
    private func tagsCard(tags: [Tag]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "tag")
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Tags")
                        .font(.headline)
                    
                    Spacer()
                }
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80))
                ], spacing: 8) {
                    ForEach(tags, id: \.id) { tag in
                        Text(tag.safeName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.primaryColor.opacity(0.1))
                            .foregroundColor(AppTheme.primaryColor)
                            .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func notesCard(notes: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Text("Notes")
                        .font(.headline)
                    
                    Spacer()
                }
                
                Text(notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            PrimaryButton(title: "Edit Expense") {
                showingEditView = true
            }
            
            SecondaryButton(title: "Delete Expense") {
                showingDeleteAlert = true
            }
        }
    }
    
    private func deleteExpense() {
        isDeleting = true
        
        // Use the ViewModel to delete the expense
        Task {
            await viewModel.deleteExpense()
            
            // Dismiss the view after deletion
            DispatchQueue.main.async {
                dismiss()
            }
        }
    }
}

// MARK: - Detail Row Component
struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// Using NumberFormatter.currency from Expense+Extensions.swift

#if DEBUG
struct ExpenseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let expense = Expense.createSampleExpense(context: context)
        
        // Pass the objectID to the ExpenseDetailView
        return ExpenseDetailView(expenseID: expense.objectID)
    }
}
#endif