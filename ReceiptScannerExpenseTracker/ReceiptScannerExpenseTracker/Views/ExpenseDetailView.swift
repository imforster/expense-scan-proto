import SwiftUI
import CoreData

struct ExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @ObservedObject var expense: Expense
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var isDeleting = false
    @State private var isDataLoaded = false
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            if expense.isDeleted {
                deletedView
            } else if !isDataLoaded {
                loadingView
            } else {
                expenseDetailContent
            }
        }
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingEditView) {
            ExpenseEditView(expense: expense, context: viewContext)
        }
        .alert("Delete Expense", isPresented: $showingDeleteAlert) {
            deleteAlert
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
        .onAppear {
            refreshExpenseData()
        }
    }
    
    // MARK: - Content Views
    
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
            
            Button("Return to Expense List") {
                dismiss()
            }
            .padding()
            .background(AppTheme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading expense details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Close") { dismiss() }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            if !expense.isDeleted && !isDeleting {
                Menu {
                    Button("Edit", systemImage: "pencil") {
                        showingEditView = true
                    }
                    
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private var deleteAlert: some View {
        Group {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteExpense()
            }
        }
    }
    
    private func deleteExpense() {
        isDeleting = true
        
        // Use Core Data directly for simpler, more reliable deletion
        viewContext.delete(expense)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            // Handle error - you might want to show an alert here
            print("Failed to delete expense: \(error)")
            isDeleting = false
        }
    }
    
    private func refreshExpenseData() {
        // Ensure the expense object is not a fault and relationships are loaded
        guard !expense.isDeleted, let context = expense.managedObjectContext else { 
            isDataLoaded = true
            return 
        }
        
        // Refresh the object to ensure it's up to date
        context.refresh(expense, mergeChanges: true)
        
        // Force load relationships that might be faulted
        _ = expense.category
        _ = expense.receipt
        _ = expense.items
        _ = expense.tags
        
        // Small delay to ensure UI updates properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isDataLoaded = true
        }
    }
    
    // MARK: - Expense Detail Content
    
    private var expenseDetailContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 24) {
                headerCard
                
                if let receipt = expense.receipt {
                    receiptImageCard(receipt: receipt)
                }
                
                detailsCard
                
                if !expense.safeExpenseItems.isEmpty {
                    itemsCard(items: expense.safeExpenseItems)
                }
                
                if !expense.safeTags.isEmpty {
                    tagsCard(tags: expense.safeTags)
                }
                
                if !expense.safeNotes.isEmpty {
                    notesCard(notes: expense.safeNotes)
                }
            }
            .padding()
        }
        .refreshable {
            // With @ObservedObject, the view automatically updates
            // This is just for pull-to-refresh visual feedback
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }
    
    // MARK: - Card Components
    
    private var headerCard: some View {
        CardView {
            VStack(spacing: 16) {
                Text(expense.formattedAmount())
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(expense.safeMerchant)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                Text(expense.formattedDate())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let category = expense.category {
                    categoryBadge(category: category)
                }
                
                if expense.isRecurring {
                    recurringBadge
                }
            }
        }
    }
    
    private func categoryBadge(category: Category) -> some View {
        let categoryColor = Color(hex: category.colorHex) ?? .blue
        
        return HStack {
            Image(systemName: category.safeIcon)
                .foregroundColor(categoryColor)
            
            Text(category.safeName)
                .font(.subheadline)
                .foregroundColor(categoryColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var recurringBadge: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "repeat")
                    .font(.caption)
                    .foregroundColor(.orange)
                
                Text("Recurring Expense")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            if let pattern = expense.recurringPattern {
                Text(pattern)
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var detailsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                cardHeader(title: "Details", icon: "info.circle")
                
                VStack(spacing: 12) {
                    DetailRow(label: "Amount", value: expense.formattedAmount())
                    DetailRow(label: "Date", value: expense.formattedDate())
                    DetailRow(label: "Merchant", value: expense.safeMerchant)
                    DetailRow(label: "Category", value: expense.safeCategoryName)
                    
                    if expense.safePaymentMethod != "Unknown" {
                        DetailRow(label: "Payment Method", value: expense.safePaymentMethod)
                    }
                    
                    DetailRow(label: "Recurring", value: expense.isRecurring ? "Yes" : "No")
                }
            }
        }
    }
    
    private func receiptImageCard(receipt: Receipt) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: "Receipt Image", icon: "doc.text.image")
                
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
    
    private func itemsCard(items: [ExpenseItem]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    cardHeader(title: "Items", icon: "list.bullet")
                    Spacer()
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(spacing: 8) {
                    ForEach(items, id: \.id) { item in
                        itemRow(item: item)
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
                cardHeader(title: "Tags", icon: "tag")
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 80))
                ], spacing: 8) {
                    ForEach(tags, id: \.id) { tag in
                        tagBadge(tag: tag)
                    }
                }
            }
        }
    }
    
    private func notesCard(notes: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                cardHeader(title: "Notes", icon: "note.text")
                
                Text(notes)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func cardHeader(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    private func itemRow(item: ExpenseItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.safeName)
                    .font(.body)
                    .fontWeight(.medium)
                
                // Only show description if the ExpenseItem has a description property
                // Remove this section if ExpenseItem doesn't have a description field
                /*
                if !item.safeDescription.isEmpty {
                    Text(item.safeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                */
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.formattedAmount())
                    .font(.body)
                    .fontWeight(.medium)
                
                if item.quantity > 1 {
                    Text("Qty: \(Int(item.quantity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func tagBadge(tag: Tag) -> some View {
        Text(tag.safeName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(12)
    }
}

// MARK: - Supporting Views

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
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Extensions

extension Color {
    init?(hex: String?) {
        guard let hex = hex else { return nil }
        
        let hexString = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        
        var color: UInt32 = 0
        scanner.scanHexInt32(&color)
        
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        
        let red   = Double(r) / 255.0
        let green = Double(g) / 255.0
        let blue  = Double(b) / 255.0
        
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}
