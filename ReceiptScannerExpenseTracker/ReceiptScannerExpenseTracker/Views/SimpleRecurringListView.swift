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
    
    @State private var recurringExpenses: [Expense] = []
    @State private var showingGenerateAlert = false
    @State private var generatedCount = 0
    
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
                    ForEach(recurringExpenses, id: \.id) { expense in
                        RecurringExpenseRow(expense: expense)
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
                loadRecurringExpenses()
            }
            .alert("Generated Expenses", isPresented: $showingGenerateAlert) {
                Button("OK") { }
            } message: {
                Text("Generated \(generatedCount) new expenses from recurring templates.")
            }
        }
    }
    
    private func loadRecurringExpenses() {
        recurringExpenses = RecurringExpenseHelper.getRecurringExpenses(context: viewContext)
    }
    
    private func getDueExpenses() -> [Expense] {
        return RecurringExpenseHelper.getDueRecurringExpenses(context: viewContext)
    }
    
    private func generateDueExpenses() {
        let dueExpenses = getDueExpenses()
        var generated = 0
        
        for expense in dueExpenses {
            if let _ = RecurringExpenseHelper.generateNextExpense(from: expense, context: viewContext) {
                generated += 1
            }
        }
        
        if generated > 0 {
            do {
                try viewContext.save()
                generatedCount = generated
                showingGenerateAlert = true
            } catch {
                print("Error saving generated expenses: \(error)")
            }
        }
    }
}

struct RecurringExpenseRow: View {
    let expense: Expense
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(expense.merchant)
                    .font(.headline)
                
                Spacer()
                
                Text(expense.formattedAmount())
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            
            if let recurringInfo = expense.recurringInfo {
                Text(recurringInfo.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let nextDate = expense.nextRecurringDate {
                    HStack {
                        Text("Next due:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(nextDate, style: .date)
                            .font(.caption)
                            .foregroundColor(nextDate <= Date() ? .orange : .secondary)
                    }
                }
            }
            
            if let category = expense.category {
                HStack {
                    Image(systemName: category.safeIcon)
                        .foregroundColor(Color(hex: category.colorHex) ?? .blue)
                    
                    Text(category.safeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
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