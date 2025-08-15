//
//  SimpleRecurringListView.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Kiro on 8/4/25.
//

import SwiftUI
import CoreData

struct SimpleRecurringListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var recurringExpenses: [RecurringExpense] = []
    @State private var showingGenerateAlert = false
    @State private var generatedCount = 0
    @State private var recurringExpenseService: RecurringExpenseService?
    @State private var expenseToDelete: RecurringExpense?
    @State private var showingDeleteConfirmation = false
    @State private var deleteGeneratedExpenses = false
    @State private var selectedExpenses: Set<RecurringExpense> = []
    @State private var isInSelectionMode = false
    @State private var showingBulkDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                if recurringExpenses.isEmpty {
                    ContentUnavailableView(
                        "No Recurring Expenses",
                        systemImage: "repeat",
                        description: Text("Mark expenses as recurring to see them here")
                    )
                } else {
                    ForEach(recurringExpenses, id: \.id) { recurringExpense in
                        RecurringExpenseRow(
                            recurringExpense: recurringExpense,
                            isSelected: selectedExpenses.contains(recurringExpense),
                            isInSelectionMode: isInSelectionMode
                        ) {
                            toggleSelection(for: recurringExpense)
                        }
                    }
                    .onDelete(perform: deleteRecurringExpenses)
                }
            }
            .navigationTitle("Recurring Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !recurringExpenses.isEmpty {
                        Button(isInSelectionMode ? "Cancel" : "Select") {
                            toggleSelectionMode()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isInSelectionMode && !selectedExpenses.isEmpty {
                            Button("Delete Selected") {
                                showingBulkDeleteConfirmation = true
                            }
                            .foregroundColor(.red)
                        }
                        
                        Button("Generate Due") {
                            generateDueExpenses()
                        }
                        .disabled(getDueExpenses().isEmpty)
                    }
                }
            }
            .onAppear {
                setupService()
                loadRecurringExpenses()
            }
            .alert("Generated Expenses", isPresented: $showingGenerateAlert) {
                Button("OK") { }
            } message: {
                Text("Generated \(generatedCount) new expenses from recurring templates.")
            }
            .alert("Delete Recurring Template", isPresented: $showingDeleteConfirmation) {
                Button("Keep Generated Expenses", role: .cancel) {
                    confirmDelete(deleteGenerated: false)
                }
                Button("Delete All Related Expenses", role: .destructive) {
                    confirmDelete(deleteGenerated: true)
                }
                Button("Cancel") {
                    expenseToDelete = nil
                }
            } message: {
                if let expense = expenseToDelete, !expense.isDeleted, expense.managedObjectContext != nil {
                    let generatedCount = expense.safeGeneratedExpenses.count
                    if generatedCount > 0 {
                        Text("This will delete the recurring template for \(expense.merchant). You have \(generatedCount) generated expense(s) from this template. What would you like to do with them?")
                    } else {
                        Text("This will delete the recurring template for \(expense.merchant). No generated expenses will be affected.")
                    }
                } else {
                    Text("This recurring template is no longer available.")
                }
            }
            .alert("Delete Selected Templates", isPresented: $showingBulkDeleteConfirmation) {
                Button("Keep Generated Expenses", role: .cancel) {
                    confirmBulkDelete(deleteGenerated: false)
                }
                Button("Delete All Related Expenses", role: .destructive) {
                    confirmBulkDelete(deleteGenerated: true)
                }
                Button("Cancel") {
                    // Do nothing
                }
            } message: {
                let validExpenses = selectedExpenses.filter { !$0.isDeleted && $0.managedObjectContext != nil }
                let totalGenerated = validExpenses.reduce(0) { $0 + $1.safeGeneratedExpenses.count }
                if totalGenerated > 0 {
                    Text("This will delete \(validExpenses.count) recurring template(s). You have \(totalGenerated) generated expense(s) from these templates. What would you like to do with them?")
                } else {
                    Text("This will delete \(validExpenses.count) recurring template(s). No generated expenses will be affected.")
                }
            }
        }
    }
    
    private func setupService() {
        recurringExpenseService = RecurringExpenseService(context: viewContext)
    }
    
    private func loadRecurringExpenses() {
        guard let service = recurringExpenseService else { return }
        let allExpenses = service.getActiveRecurringExpenses()
        // Filter out any deleted objects to prevent crashes
        recurringExpenses = allExpenses.filter { !$0.isDeleted && $0.managedObjectContext != nil }
    }
    
    private func getDueExpenses() -> [RecurringExpense] {
        guard let service = recurringExpenseService else { return [] }
        return service.getDueRecurringExpenses()
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
    
    private func deleteRecurringExpenses(offsets: IndexSet) {
        guard let index = offsets.first else { return }
        expenseToDelete = recurringExpenses[index]
        showingDeleteConfirmation = true
    }
    
    private func confirmDelete(deleteGenerated: Bool) {
        guard let expense = expenseToDelete,
              let service = recurringExpenseService else { return }
        
        // Ensure the expense is still valid before attempting deletion
        guard !expense.isDeleted, expense.managedObjectContext != nil else {
            print("Warning: Attempting to delete an already deleted expense")
            expenseToDelete = nil
            loadRecurringExpenses()
            return
        }
        
        do {
            service.deleteRecurringExpense(expense, deleteGeneratedExpenses: deleteGenerated)
            try viewContext.save()
            expenseToDelete = nil
            loadRecurringExpenses()
        } catch {
            print("Error deleting recurring expense: \(error)")
            // Reset state on error
            expenseToDelete = nil
            loadRecurringExpenses()
        }
    }
    
    private func toggleSelectionMode() {
        isInSelectionMode.toggle()
        if !isInSelectionMode {
            selectedExpenses.removeAll()
        }
    }
    
    private func toggleSelection(for expense: RecurringExpense) {
        // Only allow selection of valid, non-deleted objects
        guard !expense.isDeleted, expense.managedObjectContext != nil else {
            return
        }
        
        if selectedExpenses.contains(expense) {
            selectedExpenses.remove(expense)
        } else {
            selectedExpenses.insert(expense)
        }
    }
    
    private func confirmBulkDelete(deleteGenerated: Bool) {
        guard let service = recurringExpenseService else { return }
        
        // Filter out any already deleted expenses
        let validExpenses = selectedExpenses.filter { !$0.isDeleted && $0.managedObjectContext != nil }
        
        guard !validExpenses.isEmpty else {
            print("Warning: No valid expenses to delete")
            selectedExpenses.removeAll()
            isInSelectionMode = false
            loadRecurringExpenses()
            return
        }
        
        do {
            service.deleteRecurringExpenses(Array(validExpenses), deleteGeneratedExpenses: deleteGenerated)
            try viewContext.save()
            selectedExpenses.removeAll()
            isInSelectionMode = false
            loadRecurringExpenses()
        } catch {
            print("Error deleting recurring expenses: \(error)")
            // Reset state on error
            selectedExpenses.removeAll()
            isInSelectionMode = false
            loadRecurringExpenses()
        }
    }
}

struct RecurringExpenseRow: View {
    let recurringExpense: RecurringExpense
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onSelectionToggle: () -> Void
    
    var body: some View {
        // Safety check to prevent crashes with deleted objects
        guard !recurringExpense.isDeleted, recurringExpense.managedObjectContext != nil else {
            return AnyView(
                HStack {
                    Text("Deleted recurring expense")
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 4)
            )
        }
        
        return AnyView(
            HStack {
                if isInSelectionMode {
                    Button(action: onSelectionToggle) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .blue : .gray)
                            .font(.title2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(recurringExpense.merchant)
                            .font(.headline)
                        
                        Spacer()
                        
                        Text(recurringExpense.formattedAmount())
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
            
                if let pattern = recurringExpense.pattern {
                    Text(pattern.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Next due:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(pattern.nextDueDate, style: .date)
                            .font(.caption)
                            .foregroundColor(pattern.nextDueDate <= Date() ? .orange : .secondary)
                    }
                }
                
                if let category = recurringExpense.category {
                    HStack {
                        Image(systemName: category.safeIcon)
                            .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                        
                        Text(category.safeName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Visual indicator for recurring template
                HStack {
                    Image(systemName: "repeat.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    
                    Text("Recurring Template")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if !recurringExpense.isActive {
                        Text("(Inactive)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                if isInSelectionMode {
                    onSelectionToggle()
                }
            }
        )
    }
}

#Preview {
    let context = NSPersistentContainer(name: "ReceiptScannerExpenseTracker").viewContext
    
    return SimpleRecurringListView()
        .environment(\.managedObjectContext, context)
}