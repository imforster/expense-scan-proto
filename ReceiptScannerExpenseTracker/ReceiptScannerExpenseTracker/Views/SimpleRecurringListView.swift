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
                        RecurringExpenseRow(recurringExpense: recurringExpense)
                    }
                }
            }
            .navigationTitle("Recurring Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Generate Due") {
                        generateDueExpenses()
                    }
                    .disabled(getDueExpenses().isEmpty)
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
        }
    }
    
    private func setupService() {
        recurringExpenseService = RecurringExpenseService(context: viewContext)
    }
    
    private func loadRecurringExpenses() {
        guard let service = recurringExpenseService else { return }
        recurringExpenses = service.getActiveRecurringExpenses()
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
}

struct RecurringExpenseRow: View {
    let recurringExpense: RecurringExpense
    
    var body: some View {
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
        .padding(.vertical, 4)
    }
}

#Preview {
    let context = NSPersistentContainer(name: "ReceiptScannerExpenseTracker").viewContext
    
    return SimpleRecurringListView()
        .environment(\.managedObjectContext, context)
}