import SwiftUI
import CoreData

struct ExpenseEditView: View {
    @StateObject private var viewModel: ExpenseEditViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    private let isEditing: Bool
    
    init(expense: Expense? = nil, context: NSManagedObjectContext) {
        self.isEditing = expense != nil
        self._viewModel = StateObject(wrappedValue: ExpenseEditViewModel(context: context, expense: expense))
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Basic Information Section
                basicInformationSection
                
                // Category and Tags Section
                categoryAndTagsSection
                
                // Expense Items Section
                if !viewModel.expenseItems.isEmpty || viewModel.expense?.items?.count ?? 0 > 0 {
                    expenseItemsSection
                }
                
                // Receipt Splitting Section
                if viewModel.expense?.receipt != nil {
                    receiptSplittingSection
                }
                
                // Additional Details Section
                additionalDetailsSection
                
                // Recurring Expense Section
                recurringExpenseSection
            }
            .navigationTitle(isEditing ? "Edit Expense" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveExpense()
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $viewModel.showingCategoryPicker) {
                CategoryPickerView(
                    selectedCategory: $viewModel.selectedCategory,
                    availableCategories: viewModel.availableCategories,
                    suggestedCategories: viewModel.suggestedCategories
                )
            }
            .sheet(isPresented: $viewModel.showingTagPicker) {
                TagPickerView(
                    selectedTags: $viewModel.tags,
                    availableTags: viewModel.availableTags,
                    onAddTag: { tagName in
                        Task {
                            try await viewModel.addTag(tagName)
                        }
                    }
                )
            }
            .sheet(isPresented: $viewModel.showingReceiptSplitView) {
                ReceiptSplitView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.detectRecurringExpense()
        }
    }
    
    // MARK: - Form Sections
    
    private var basicInformationSection: some View {
        Section("Basic Information") {
            // Amount
            HStack {
                Text("Amount")
                Spacer()
                TextField("$0.00", text: $viewModel.amount)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 100)
            }
            
            // Date
            DatePicker("Date", selection: $viewModel.date, displayedComponents: [.date])
            
            // Merchant
            HStack {
                Text("Merchant")
                Spacer()
                TextField("Enter merchant name", text: $viewModel.merchant)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 200)
            }
            
            // Payment Method
            HStack {
                Text("Payment Method")
                Spacer()
                Menu(viewModel.paymentMethod.isEmpty ? "Select" : viewModel.paymentMethod) {
                    ForEach(viewModel.paymentMethods, id: \.self) { method in
                        Button(method) {
                            viewModel.paymentMethod = method
                        }
                    }
                }
            }
        }
    }
    
    private var categoryAndTagsSection: some View {
        Section("Category & Tags") {
            // Category
            HStack {
                Text("Category")
                Spacer()
                
                if let category = viewModel.selectedCategory {
                    let categoryColor = Color(hex: category.colorHex) ?? .blue
                    HStack {
                        Image(systemName: category.safeIcon)
                            .foregroundColor(categoryColor)
                        Text(category.safeName)
                            .foregroundColor(categoryColor)
                    }
                } else {
                    Text("Select Category")
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.showingCategoryPicker = true
            }
            
            // Suggested Categories
            if !viewModel.suggestedCategories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(viewModel.suggestedCategories, id: \.id) { category in
                            Button(action: {
                                viewModel.selectedCategory = category
                            }) {
                                let categoryColor = Color(hex: category.colorHex) ?? .blue
                                HStack {
                                    Image(systemName: category.safeIcon)
                                        .font(.caption)
                                    Text(category.safeName)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(categoryColor.opacity(0.1))
                                .foregroundColor(categoryColor)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
            }
            
            // Tags
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tags")
                    Spacer()
                    Button("Add Tag") {
                        viewModel.showingTagPicker = true
                    }
                    .font(.caption)
                }
                
                if !viewModel.tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(viewModel.tags, id: \.id) { tag in
                            HStack {
                                Text(tag.safeName)
                                    .font(.caption)
                                
                                Button(action: {
                                    viewModel.removeTag(tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
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
    }
    
    private var expenseItemsSection: some View {
        Section("Expense Items") {
            ForEach(Array(viewModel.expenseItems.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 8) {
                    HStack {
                        TextField("Item name", text: Binding(
                            get: { viewModel.expenseItems[index].name },
                            set: { viewModel.expenseItems[index].name = $0 }
                        ))
                        
                        TextField("$0.00", text: Binding(
                            get: { viewModel.expenseItems[index].amount },
                            set: { viewModel.expenseItems[index].amount = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .frame(width: 80)
                        
                        Button(action: {
                            viewModel.removeExpenseItem(at: index)
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    
                    if let category = viewModel.expenseItems[index].category {
                        let categoryColor = Color(hex: category.colorHex) ?? .blue
                        HStack {
                            Image(systemName: category.safeIcon)
                                .font(.caption)
                                .foregroundColor(categoryColor)
                            Text(category.safeName)
                                .font(.caption)
                                .foregroundColor(categoryColor)
                            Spacer()
                        }
                    }
                }
            }
            
            Button("Add Item") {
                viewModel.addExpenseItem()
            }
            
            if !viewModel.expenseItems.isEmpty {
                HStack {
                    Text("Total Items:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(NumberFormatter.currency.string(from: viewModel.totalExpenseItemsAmount as NSNumber) ?? "$0.00")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
    }
    
    private var receiptSplittingSection: some View {
        Section("Receipt Splitting") {
            VStack(alignment: .leading, spacing: 12) {
                Text("This expense has an associated receipt that can be split into multiple expenses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let receipt = viewModel.expense?.receipt {
                    HStack {
                        Text("Original Receipt Amount:")
                        Spacer()
                        Text(receipt.formattedTotalAmount())
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                
                Button("Split Receipt") {
                    viewModel.enableReceiptSplitMode()
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    private var additionalDetailsSection: some View {
        Section("Additional Details") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Notes")
                    .font(.headline)
                
                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if !viewModel.notes.isEmpty {
                    Text("\(viewModel.notes.count) characters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Enhanced notes features
                HStack {
                    Button(action: {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .short
                        viewModel.notes += viewModel.notes.isEmpty ? "" : "\n\n"
                        viewModel.notes += "Date: \(dateFormatter.string(from: Date()))"
                    }) {
                        Label("Add Date", systemImage: "calendar")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.notes += viewModel.notes.isEmpty ? "" : "\n\n"
                        viewModel.notes += "Location: "
                    }) {
                        Label("Add Location", systemImage: "location")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 4)
                
                // Context tags
                VStack(alignment: .leading, spacing: 8) {
                    Text("Context Tags")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(ExpenseContext.allCases, id: \.self) { context in
                                Button(action: {
                                    viewModel.toggleExpenseContext(context)
                                }) {
                                    HStack {
                                        Image(systemName: viewModel.expenseContexts.contains(context) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(viewModel.expenseContexts.contains(context) ? context.color : .gray)
                                        
                                        Text(context.rawValue)
                                            .font(.caption)
                                        
                                        Image(systemName: context.icon)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(context.color.opacity(0.1))
                                    .foregroundColor(context.color)
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    
                    Text("Add context to help with expense categorization and reporting")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                
                // Additional context section
                if viewModel.expenseContexts.contains(.business) || viewModel.expenseContexts.contains(.reimbursable) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Additional Context")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        if viewModel.expenseContexts.contains(.business) {
                            // Business purpose field - commented out until implemented in ViewModel
                            // TextField("Business purpose", text: $viewModel.businessPurpose)
                            //     .textFieldStyle(RoundedBorderTextFieldStyle())
                            //     .font(.subheadline)
                            Text("Business Expense")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if viewModel.expenseContexts.contains(.reimbursable) {
                            // Reimbursement status - commented out until implemented in ViewModel
                            HStack {
                                Text("Reimbursable Expense")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                // Picker("", selection: $viewModel.reimbursementStatus) {
                                //     Text("Pending").tag(ReimbursementStatus.pending)
                                //     Text("Submitted").tag(ReimbursementStatus.submitted)
                                //     Text("Approved").tag(ReimbursementStatus.approved)
                                //     Text("Received").tag(ReimbursementStatus.received)
                                //     Text("Rejected").tag(ReimbursementStatus.rejected)
                                // }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var recurringExpenseSection: some View {
        Section("Recurring Expense") {
            Toggle("Mark as Recurring", isOn: $viewModel.isRecurring)
            
            if viewModel.isRecurring {
                Picker("Frequency", selection: $viewModel.recurringPattern) {
                    ForEach(RecurringPattern.allCases.filter { $0 != .none }, id: \.self) { pattern in
                        Text(pattern.rawValue).tag(pattern)
                    }
                }
                
                if let nextDate = viewModel.nextExpectedDate {
                    HStack {
                        Text("Next Expected")
                        Spacer()
                        Text(nextDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Add date picker for next occurrence
                if viewModel.nextExpectedDate == nil {
                    DatePicker("Next Occurrence", selection: Binding(
                        get: { viewModel.nextExpectedDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())! },
                        set: { viewModel.nextExpectedDate = $0 }
                    ), displayedComponents: [.date])
                }
                
                // Add reminder option
                Toggle("Set Reminder", isOn: $viewModel.shouldRemind)
                
                if viewModel.shouldRemind {
                    Picker("Remind Me", selection: $viewModel.reminderDays) {
                        Text("Same day").tag(0)
                        Text("1 day before").tag(1)
                        Text("3 days before").tag(3)
                        Text("1 week before").tag(7)
                    }
                }
                
                // Add auto-create option
                Toggle("Auto-create Next Expense", isOn: $viewModel.autoCreateNext)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recurring Expense Details")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    Text("This expense will be marked as recurring, which helps with budgeting and expense tracking. You can set reminders for upcoming expenses and automatically create the next occurrence.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if viewModel.similarExpensesCount > 0 {
                        Text("Based on your history, we found \(viewModel.similarExpensesCount) similar expenses from this merchant.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveExpense() async {
        do {
            try await viewModel.saveExpense()
            
            // Post notification that expense data has changed
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
            }
            
            dismiss()
        } catch {
            // Error is handled by the view model
        }
    }
}

// MARK: - Category Picker View

struct CategoryPickerView: View {
    @Binding var selectedCategory: Category?
    let availableCategories: [Category]
    let suggestedCategories: [Category]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !suggestedCategories.isEmpty {
                    Section("Suggested") {
                        ForEach(suggestedCategories, id: \.id) { category in
                            CategoryRow(category: category, isSelected: selectedCategory?.id == category.id) {
                                selectedCategory = category
                                dismiss()
                            }
                        }
                    }
                }
                
                Section("All Categories") {
                    ForEach(availableCategories, id: \.id) { category in
                        CategoryRow(category: category, isSelected: selectedCategory?.id == category.id) {
                            selectedCategory = category
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            let categoryColor = Color(hex: category.colorHex) ?? .blue
            HStack {
                Image(systemName: category.safeIcon)
                    .foregroundColor(categoryColor)
                    .frame(width: 24)
                
                Text(category.safeName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Binding var selectedTags: [Tag]
    let availableTags: [Tag]
    let onAddTag: (String) -> Void
    
    @State private var newTagName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                // Add new tag section
                HStack {
                    TextField("New tag name", text: $newTagName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Add") {
                        onAddTag(newTagName)
                        newTagName = ""
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                
                // Available tags list
                List {
                    ForEach(availableTags, id: \.id) { tag in
                        TagRow(
                            tag: tag,
                            isSelected: selectedTags.contains { $0.id == tag.id }
                        ) {
                            if selectedTags.contains(where: { $0.id == tag.id }) {
                                selectedTags.removeAll { $0.id == tag.id }
                            } else {
                                selectedTags.append(tag)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TagRow: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(tag.safeName)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return ExpenseEditView(context: context)
}