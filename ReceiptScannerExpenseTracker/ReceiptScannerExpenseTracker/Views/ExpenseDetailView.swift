import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    let expense: Expense
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Card
                    headerCard
                    
                    // Receipt Image (if available)
                    if let receipt = expense.receipt {
                        receiptImageCard(receipt: receipt)
                    }
                    
                    // Expense Details
                    detailsCard
                    
                    // Items (if available)
                    if !expense.safeExpenseItems.isEmpty {
                        itemsCard(items: expense.safeExpenseItems)
                    }
                    
                    // Tags (if available)
                    if !expense.safeTags.isEmpty {
                        tagsCard(tags: expense.safeTags)
                    }
                    
                    // Notes (if available)
                    if !expense.safeNotes.isEmpty {
                        notesCard(notes: expense.safeNotes)
                    }
                    
                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .background(AppTheme.backgroundColor)
            .navigationTitle("Expense Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
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
                }
            }
        }
        .sheet(isPresented: $showingEditView) {
            ExpenseEditView(expense: expense, context: viewContext)
                .onDisappear {
                    // Refresh the view context to reflect any changes
                    viewContext.refreshAllObjects()
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
    
    private var headerCard: some View {
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
    
    private var detailsCard: some View {
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
        
        viewContext.delete(expense)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to delete expense: \(error)")
            isDeleting = false
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
        
        return ExpenseDetailView(expense: expense)
    }
}
#endif