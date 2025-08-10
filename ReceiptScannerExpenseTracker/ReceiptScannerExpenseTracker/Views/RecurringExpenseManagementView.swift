//
//  RecurringExpenseManagementView.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Kiro on 8/9/25.
//

import SwiftUI
import CoreData

struct RecurringExpenseManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var recurringExpenses: [RecurringExpense] = []
    @State private var recurringExpenseService: RecurringExpenseService?
    @State private var showingCreateView = false
    @State private var selectedExpense: RecurringExpense?
    @State private var showingEditView = false
    @State private var showingDeleteAlert = false
    @State private var expenseToDelete: RecurringExpense?
    @State private var showingGenerateAlert = false
    @State private var generatedCount = 0
    
    var body: some View {
        NavigationView {
            List {
                if recurringExpenses.isEmpty {
                    ContentUnavailableView(
                        "No Recurring Expenses",
                        systemImage: "repeat",
                        description: Text("Create recurring expense templates to automate your expense tracking")
                    )
                } else {
                    ForEach(recurringExpenses, id: \.id) { recurringExpense in
                        RecurringExpenseManagementRow(
                            recurringExpense: recurringExpense,
                            onEdit: { selectedExpense = $0; showingEditView = true },
                            onDelete: { expenseToDelete = $0; showingDeleteAlert = true },
                            onToggleActive: { toggleActive($0) }
                        )
                    }
                }
            }
            .navigationTitle("Manage Recurring Expenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create New", systemImage: "plus") {
                            showingCreateView = true
                        }
                        
                        Button("Generate Due", systemImage: "arrow.clockwise") {
                            generateDueExpenses()
                        }
                        .disabled(getDueCount() == 0)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                setupService()
                loadRecurringExpenses()
            }
            .sheet(isPresented: $showingCreateView) {
                RecurringExpenseCreateView()
                    .onDisappear {
                        loadRecurringExpenses()
                    }
            }
            .sheet(item: $selectedExpense) { expense in
                RecurringExpenseEditView(recurringExpense: expense)
                    .onDisappear {
                        loadRecurringExpenses()
                    }
            }
            .alert("Delete Recurring Expense", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Template Only", role: .destructive) {
                    if let expense = expenseToDelete {
                        deleteRecurringExpense(expense, deleteGenerated: false)
                    }
                }
                Button("Delete All", role: .destructive) {
                    if let expense = expenseToDelete {
                        deleteRecurringExpense(expense, deleteGenerated: true)
                    }
                }
            } message: {
                Text("Do you want to delete just the recurring template or also all generated expenses?")
            }
            .alert("Generated Expenses", isPresented: $showingGenerateAlert) {
                Button("OK") { }
            } message: {
                Text("Generated \(generatedCount) new expenses from recurring templates.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupService() {
        recurringExpenseService = RecurringExpenseService(context: viewContext)
    }
    
    private func loadRecurringExpenses() {
        guard let service = recurringExpenseService else { return }
        recurringExpenses = service.getActiveRecurringExpenses()
    }
    
    private func getDueCount() -> Int {
        guard let service = recurringExpenseService else { return 0 }
        return service.getDueRecurringExpenses().count
    }
    
    private func generateDueExpenses() {
        guard let service = recurringExpenseService else { return }
        
        let generatedExpenses = service.generateDueExpenses()
        generatedCount = generatedExpenses.count
        
        if generatedCount > 0 {
            do {
                try viewContext.save()
                showingGenerateAlert = true
                loadRecurringExpenses() // Refresh the list
            } catch {
                print("Error saving generated expenses: \(error)")
            }
        }
    }
    
    private func toggleActive(_ recurringExpense: RecurringExpense) {
        guard let service = recurringExpenseService else { return }
        
        if recurringExpense.isActive {
            service.deactivateRecurringExpense(recurringExpense)
        } else {
            service.reactivateRecurringExpense(recurringExpense)
        }
        
        do {
            try viewContext.save()
            loadRecurringExpenses()
        } catch {
            print("Error toggling recurring expense active state: \(error)")
        }
    }
    
    private func deleteRecurringExpense(_ recurringExpense: RecurringExpense, deleteGenerated: Bool) {
        guard let service = recurringExpenseService else { return }
        
        service.deleteRecurringExpense(recurringExpense, deleteGeneratedExpenses: deleteGenerated)
        
        do {
            try viewContext.save()
            loadRecurringExpenses()
        } catch {
            print("Error deleting recurring expense: \(error)")
        }
    }
}

struct RecurringExpenseManagementRow: View {
    let recurringExpense: RecurringExpense
    let onEdit: (RecurringExpense) -> Void
    let onDelete: (RecurringExpense) -> Void
    let onToggleActive: (RecurringExpense) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recurringExpense.merchant)
                        .font(.headline)
                        .foregroundColor(recurringExpense.isActive ? .primary : .secondary)
                    
                    if let pattern = recurringExpense.pattern {
                        Text(pattern.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(recurringExpense.formattedAmount())
                        .font(.headline)
                        .foregroundColor(recurringExpense.isActive ? .primary : .secondary)
                    
                    if let pattern = recurringExpense.pattern {
                        Text(pattern.nextDueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(pattern.nextDueDate <= Date() ? .orange : .secondary)
                    }
                }
            }
            
            HStack {
                if let category = recurringExpense.category {
                    HStack {
                        Image(systemName: category.safeIcon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                        
                        Text(category.safeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: { onToggleActive(recurringExpense) }) {
                        Image(systemName: recurringExpense.isActive ? "pause.circle" : "play.circle")
                            .foregroundColor(recurringExpense.isActive ? .orange : .green)
                    }
                    
                    Button(action: { onEdit(recurringExpense) }) {
                        Image(systemName: "pencil.circle")
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { onDelete(recurringExpense) }) {
                        Image(systemName: "trash.circle")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if !recurringExpense.isActive {
                HStack {
                    Image(systemName: "pause.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("Inactive")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create View

struct RecurringExpenseCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var amount: String = ""
    @State private var merchant: String = ""
    @State private var notes: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedPattern: RecurringFrequency = .monthly
    @State private var interval: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var showingDayPicker = false
    @State private var recurringExpenseService: RecurringExpenseService?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Merchant", text: $merchant)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Notes (Optional)", text: $notes)
                }
                
                Section(header: Text("Recurring Pattern")) {
                    Picker("Frequency", selection: $selectedPattern) {
                        ForEach(RecurringFrequency.allCases.filter { $0 != .none }, id: \.self) { pattern in
                            Text(pattern.rawValue).tag(pattern)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if selectedPattern == .monthly {
                        Toggle("Specific day of month", isOn: $showingDayPicker)
                        
                        if showingDayPicker {
                            Stepper("Day: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)
                        }
                    }
                    
                    if selectedPattern != .biweekly {
                        Stepper("Every \(interval) \(intervalLabel)", value: $interval, in: 1...12)
                    }
                }
            }
            .navigationTitle("Create Recurring Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecurringExpense()
                    }
                    .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                setupService()
            }
        }
    }
    
    private var intervalLabel: String {
        switch selectedPattern {
        case .weekly:
            return interval == 1 ? "week" : "weeks"
        case .monthly:
            return interval == 1 ? "month" : "months"
        case .quarterly:
            return interval == 1 ? "quarter" : "quarters"
        default:
            return ""
        }
    }
    
    private func setupService() {
        recurringExpenseService = RecurringExpenseService(context: viewContext)
    }
    
    private func saveRecurringExpense() {
        guard let service = recurringExpenseService,
              let amountDecimal = NSDecimalNumber(string: amount) as NSDecimalNumber?,
              amountDecimal.doubleValue > 0 else {
            return
        }
        
        let _ = service.createRecurringExpense(
            amount: amountDecimal,
            currencyCode: "USD", // Default currency - could be made configurable
            merchant: merchant,
            notes: notes.isEmpty ? nil : notes,
            paymentMethod: nil,
            category: selectedCategory,
            tags: [],
            patternType: selectedPattern,
            interval: Int32(interval),
            dayOfMonth: showingDayPicker ? Int32(dayOfMonth) : nil,
            dayOfWeek: nil,
            startDate: Date()
        )
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving recurring expense: \(error)")
        }
    }
}

// MARK: - Edit View

struct RecurringExpenseEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let recurringExpense: RecurringExpense
    
    @State private var amount: String = ""
    @State private var merchant: String = ""
    @State private var notes: String = ""
    @State private var selectedPattern: RecurringFrequency = .monthly
    @State private var interval: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var showingDayPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Expense Details")) {
                    TextField("Merchant", text: $merchant)
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                    TextField("Notes (Optional)", text: $notes)
                }
                
                Section(header: Text("Recurring Pattern")) {
                    Picker("Frequency", selection: $selectedPattern) {
                        ForEach(RecurringFrequency.allCases.filter { $0 != .none }, id: \.self) { pattern in
                            Text(pattern.rawValue).tag(pattern)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if selectedPattern == .monthly {
                        Toggle("Specific day of month", isOn: $showingDayPicker)
                        
                        if showingDayPicker {
                            Stepper("Day: \(dayOfMonth)", value: $dayOfMonth, in: 1...28)
                        }
                    }
                    
                    if selectedPattern != .biweekly {
                        Stepper("Every \(interval) \(intervalLabel)", value: $interval, in: 1...12)
                    }
                }
            }
            .navigationTitle("Edit Recurring Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(merchant.isEmpty || amount.isEmpty)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    private var intervalLabel: String {
        switch selectedPattern {
        case .weekly:
            return interval == 1 ? "week" : "weeks"
        case .monthly:
            return interval == 1 ? "month" : "months"
        case .quarterly:
            return interval == 1 ? "quarter" : "quarters"
        default:
            return ""
        }
    }
    
    private func loadCurrentValues() {
        amount = recurringExpense.amount.stringValue
        merchant = recurringExpense.merchant
        notes = recurringExpense.notes ?? ""
        
        if let pattern = recurringExpense.pattern,
           let patternType = RecurringFrequency(rawValue: pattern.patternType) {
            selectedPattern = patternType
            interval = Int(pattern.interval)
            
            if pattern.dayOfMonth > 0 {
                dayOfMonth = Int(pattern.dayOfMonth)
                showingDayPicker = true
            }
        }
    }
    
    private func saveChanges() {
        guard let amountDecimal = NSDecimalNumber(string: amount) as NSDecimalNumber?,
              amountDecimal.doubleValue > 0 else {
            return
        }
        
        recurringExpense.amount = amountDecimal
        recurringExpense.merchant = merchant
        recurringExpense.notes = notes.isEmpty ? nil : notes
        
        if let pattern = recurringExpense.pattern {
            pattern.patternType = selectedPattern.rawValue
            pattern.interval = Int32(interval)
            pattern.dayOfMonth = showingDayPicker ? Int32(dayOfMonth) : 0
        }
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving recurring expense changes: \(error)")
        }
    }
}

#Preview {
    RecurringExpenseManagementView()
        .environment(\.managedObjectContext, NSPersistentContainer(name: "ReceiptScannerExpenseTracker").viewContext)
}