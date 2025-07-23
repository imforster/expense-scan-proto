import SwiftUI
import CoreData

struct ReceiptSplitView: View {
    @ObservedObject var viewModel: ExpenseEditViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateExpensesAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with original receipt info
                headerSection
                
                // Split items list
                splitItemsList
                
                // Summary and actions
                summarySection
            }
            .navigationTitle("Split Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create Expenses") {
                        showingCreateExpensesAlert = true
                    }
                    .disabled(selectedSplitsCount == 0)
                }
            }
            .alert("Create Expenses", isPresented: $showingCreateExpensesAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    Task {
                        await createExpensesFromSplits()
                    }
                }
            } message: {
                Text("This will create \(selectedSplitsCount) new expense\(selectedSplitsCount == 1 ? "" : "s") from the selected items.")
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            CardView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "doc.text.image")
                            .foregroundColor(AppTheme.primaryColor)
                        
                        Text("Original Receipt")
                            .font(.headline)
                        
                        Spacer()
                    }
                    
                    if let receipt = viewModel.expense?.receipt {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Merchant:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(receipt.safeMerchantName)
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Date:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(receipt.formattedDate())
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Total Amount:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(receipt.formattedTotalAmount())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.primaryColor)
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
            
            // Instructions
            Text("Select the items you want to create as separate expenses. Each selected item will become a new expense entry.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(AppTheme.backgroundColor)
    }
    
    // MARK: - Split Items List
    
    private var splitItemsList: some View {
        List {
            // Quick actions section
            Section("Quick Actions") {
                Button(action: {
                    viewModel.selectAllSplits()
                }) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.primaryColor)
                        Text("Select All Items")
                    }
                }
                
                Button(action: {
                    viewModel.deselectAllSplits()
                }) {
                    HStack {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                        Text("Deselect All Items")
                    }
                }
                
                Button(action: {
                    viewModel.distributeAmountEvenly()
                }) {
                    HStack {
                        Image(systemName: "equal.circle.fill")
                            .foregroundColor(AppTheme.primaryColor)
                        Text("Distribute Amount Evenly")
                    }
                }
                
                Button(action: {
                    viewModel.suggestCategoriesForSplits()
                }) {
                    HStack {
                        Image(systemName: "tag.circle.fill")
                            .foregroundColor(AppTheme.primaryColor)
                        Text("Auto-Categorize Items")
                    }
                }
            }
            
            // Split items section
            Section("Receipt Items") {
                ForEach(Array(viewModel.receiptSplits.enumerated()), id: \.element.id) { index, split in
                    ReceiptSplitRow(
                        split: split,
                        index: index,
                        availableCategories: viewModel.availableCategories,
                        onToggleSelection: {
                            viewModel.receiptSplits[index].isSelected.toggle()
                        },
                        onUpdateAmount: { newAmount in
                            viewModel.receiptSplits[index].amount = newAmount
                        },
                        onUpdateCategory: { category in
                            viewModel.receiptSplits[index].category = category
                        },
                        onUpdateName: { newName in
                            viewModel.receiptSplits[index].name = newName
                        },
                        onDelete: {
                            viewModel.removeReceiptSplit(at: index)
                        }
                    )
                }
                
                // Add new split button
                Button(action: {
                    viewModel.addReceiptSplit()
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppTheme.primaryColor)
                        Text("Add Custom Split")
                            .foregroundColor(AppTheme.primaryColor)
                    }
                }
            }
        }
    }
    
    // MARK: - Summary Section
    
    private var summarySection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                HStack {
                    Text("Selected Items:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(selectedSplitsCount)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Selected Amount:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(NumberFormatter.currency.string(from: selectedSplitsAmount as NSNumber) ?? "$0.00")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedSplitsAmount > viewModel.originalReceiptAmount ? .red : .primary)
                }
                
                HStack {
                    Text("Original Amount:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(NumberFormatter.currency.string(from: viewModel.originalReceiptAmount as NSNumber) ?? "$0.00")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                if selectedSplitsAmount != viewModel.originalReceiptAmount {
                    HStack {
                        Text("Difference:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        let difference = selectedSplitsAmount - viewModel.originalReceiptAmount
                        Text(NumberFormatter.currency.string(from: difference as NSNumber) ?? "$0.00")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(difference > 0 ? .red : .orange)
                    }
                }
            }
            .padding(.horizontal)
            
            if selectedSplitsCount > 0 {
                PrimaryButton(title: "Create \(selectedSplitsCount) Expense\(selectedSplitsCount == 1 ? "" : "s")") {
                    showingCreateExpensesAlert = true
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(AppTheme.backgroundColor)
    }
    
    // MARK: - Computed Properties
    
    private var selectedSplitsCount: Int {
        viewModel.receiptSplits.filter { $0.isSelected }.count
    }
    
    private var selectedSplitsAmount: Decimal {
        viewModel.receiptSplits
            .filter { $0.isSelected }
            .reduce(Decimal.zero) { total, split in
                total + (Decimal(string: split.amount) ?? 0)
            }
    }
    
    // MARK: - Actions
    
    private func createExpensesFromSplits() async {
        do {
            let _ = try await viewModel.createExpensesFromSplits()
            dismiss()
        } catch {
            // Error handling would be implemented here
            print("Failed to create expenses from splits: \(error)")
        }
    }
}

// MARK: - Receipt Split Row

struct ReceiptSplitRow: View {
    let split: ReceiptSplit
    let index: Int
    let availableCategories: [Category]
    let onToggleSelection: () -> Void
    let onUpdateAmount: (String) -> Void
    let onUpdateCategory: (Category?) -> Void
    let onUpdateName: (String) -> Void
    let onDelete: () -> Void
    
    @State private var showingCategoryPicker = false
    @State private var editingAmount = false
    @State private var editingName = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Selection checkbox
                Button(action: onToggleSelection) {
                    Image(systemName: split.isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(split.isSelected ? .blue : .gray)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // Item name
                    if editingName {
                        TextField("Item name", text: Binding(
                            get: { split.name },
                            set: onUpdateName
                        ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            editingName = false
                        }
                    } else {
                        Button(action: {
                            editingName = true
                        }) {
                            Text(split.name.isEmpty ? "Custom Item" : split.name)
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    // Category
                    if let category = split.category {
                        HStack {
                            Image(systemName: category.safeIcon)
                                .font(.caption)
                                .foregroundColor(category.color)
                            Text(category.safeName)
                                .font(.caption)
                                .foregroundColor(category.color)
                        }
                    } else {
                        Text("No category")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Amount
                VStack(alignment: .trailing) {
                    if editingAmount {
                        TextField("$0.00", text: Binding(
                            get: { split.amount },
                            set: onUpdateAmount
                        ))
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 80)
                        .onSubmit {
                            editingAmount = false
                        }
                    } else {
                        Button(action: {
                            editingAmount = true
                        }) {
                            Text(NumberFormatter.currency.string(from: Decimal(string: split.amount) as NSNumber? ?? 0) ?? "$0.00")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            // Category selection button
            if split.isSelected {
                Button(action: {
                    showingCategoryPicker = true
                }) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(AppTheme.primaryColor)
                        
                        if let category = split.category {
                            Text("Change Category: \(category.safeName)")
                        } else {
                            Text("Select Category")
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                    .foregroundColor(AppTheme.primaryColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerView(
                selectedCategory: Binding(
                    get: { split.category },
                    set: onUpdateCategory
                ),
                availableCategories: availableCategories,
                suggestedCategories: []
            )
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let expense = Expense.createSampleExpense(context: context)
    let viewModel = ExpenseEditViewModel(context: context, expense: expense)
    
    return ReceiptSplitView(viewModel: viewModel)
}