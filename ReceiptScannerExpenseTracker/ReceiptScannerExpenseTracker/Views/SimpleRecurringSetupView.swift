//
//  SimpleRecurringSetupView.swift
//  ReceiptScannerExpenseTracker
//
//  Created by Kiro on 8/4/25.
//

import SwiftUI
import CoreData

struct SimpleRecurringSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let expense: Expense
    
    @State private var selectedPattern: RecurringFrequency = .monthly
    @State private var interval: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var showingDayPicker = false
    @State private var nextExpectedDate: Date?
    @State private var shouldRemind: Bool = false
    @State private var reminderDays: Int = 1
    @State private var autoCreateNext: Bool = false
    @State private var recurringExpenseService: RecurringExpenseService?
    @State private var existingRecurringExpense: RecurringExpense?
    @State private var showingDeleteTemplateConfirmation = false
    @State private var deleteGeneratedExpenses = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recurring Pattern")) {
                    Picker("Frequency", selection: $selectedPattern) {
                        ForEach(RecurringFrequency.allCases.filter { $0 != .none }, id: \.self) { pattern in
                            Text(pattern.rawValue).tag(pattern)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if selectedPattern != .none {
                    Section(header: Text("Options")) {
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
                
                Section(header: Text("Next Occurrence")) {
                    if let nextDate = nextExpectedDate {
                        HStack {
                            Text("Next Expected")
                            Spacer()
                            Text(nextDate, style: .date)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        DatePicker("Next Occurrence", selection: Binding(
                            get: { nextExpectedDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date())! },
                            set: { nextExpectedDate = $0 }
                        ), displayedComponents: [.date])
                    }
                }
                
                Section(header: Text("Reminders")) {
                    Toggle("Set Reminder", isOn: $shouldRemind)
                    
                    if shouldRemind {
                        Picker("Remind Me", selection: $reminderDays) {
                            Text("Same day").tag(0)
                            Text("1 day before").tag(1)
                            Text("3 days before").tag(3)
                            Text("1 week before").tag(7)
                        }
                    }
                }
                
                Section(header: Text("Automation")) {
                    Toggle("Auto-create Next Expense", isOn: $autoCreateNext)
                }
                
                Section(header: Text("Preview")) {
                    Text(getPatternDescription())
                        .foregroundColor(.secondary)
                    
                    if let nextDate = nextExpectedDate {
                        Text("Next occurrence: \(nextDate, style: .date)")
                            .foregroundColor(.secondary)
                    }
                }
                
                if existingRecurringExpense != nil {
                    Section {
                        Button("Remove Recurring Setting", role: .destructive) {
                            removeRecurringInfo()
                        }
                        
                        Button("Delete Recurring Template", role: .destructive) {
                            showingDeleteTemplateConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(existingRecurringExpense != nil ? "Update Recurring" : "Set as Recurring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecurringInfo()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            setupService()
            loadExistingRecurringInfo()
        }
        .alert("Delete Recurring Template", isPresented: $showingDeleteTemplateConfirmation) {
            Button("Keep Generated Expenses", role: .cancel) {
                deleteRecurringTemplate(deleteGenerated: false)
            }
            Button("Delete All Related Expenses", role: .destructive) {
                deleteRecurringTemplate(deleteGenerated: true)
            }
            Button("Cancel") {
                // Do nothing
            }
        } message: {
            if let recurringExpense = existingRecurringExpense, !recurringExpense.isDeleted, recurringExpense.managedObjectContext != nil {
                let generatedCount = recurringExpense.safeGeneratedExpenses.count
                if generatedCount > 0 {
                    Text("This will permanently delete the recurring template for \(recurringExpense.merchant). You have \(generatedCount) generated expense(s) from this template. What would you like to do with them?")
                } else {
                    Text("This will permanently delete the recurring template for \(recurringExpense.merchant). No generated expenses will be affected.")
                }
            } else {
                Text("This recurring template is no longer available.")
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
    
    private func loadExistingRecurringInfo() {
        // Set default day of month from expense date
        dayOfMonth = Calendar.current.component(.day, from: expense.date)
        
        // Set default next expected date
        nextExpectedDate = Calendar.current.date(byAdding: .month, value: 1, to: expense.date)
        
        // Check if expense has a recurring template
        existingRecurringExpense = expense.recurringTemplate
        
        if let recurringExpense = existingRecurringExpense,
           let pattern = recurringExpense.pattern {
            // Load settings from Core Data entity
            if let patternType = RecurringFrequency(rawValue: pattern.patternType) {
                selectedPattern = patternType
            }
            interval = Int(pattern.interval)
            
            if pattern.dayOfMonth > 0 {
                dayOfMonth = Int(pattern.dayOfMonth)
                showingDayPicker = true
            } else {
                showingDayPicker = false
            }
            
            // Calculate next expected date based on recurring pattern
            nextExpectedDate = pattern.nextDueDate
        } else {
            // Legacy recurring info is no longer supported
            // This functionality has been removed as part of the recurring expense editing cleanup
        }
        
        // Load additional recurring properties from expense notes if they exist
        if let notes = expense.notes {
            // Parse reminder settings
            if notes.contains("[Reminder:") {
                let reminderRegex = try? NSRegularExpression(pattern: "\\[Reminder: (\\d+) days?\\]", options: [])
                if let match = reminderRegex?.firstMatch(in: notes, options: [], range: NSRange(location: 0, length: notes.count)) {
                    if let range = Range(match.range(at: 1), in: notes) {
                        if let days = Int(String(notes[range])) {
                            shouldRemind = true
                            reminderDays = days
                        }
                    }
                }
            }
            
            // Parse auto-create setting
            if notes.contains("[AutoCreate: true]") {
                autoCreateNext = true
            }
        }
    }
    

    
    private func getPatternDescription() -> String {
        switch selectedPattern {
        case .none:
            return "Not recurring"
        case .weekly:
            return interval == 1 ? "Weekly" : "Every \(interval) weeks"
        case .biweekly:
            return interval == 1 ? "Bi-weekly" : "Every \(interval * 2) weeks"
        case .monthly:
            if showingDayPicker {
                let suffix = ordinalSuffix(for: dayOfMonth)
                return interval == 1 ? "Monthly on the \(dayOfMonth)\(suffix)" : "Every \(interval) months on the \(dayOfMonth)\(suffix)"
            } else {
                return interval == 1 ? "Monthly" : "Every \(interval) months"
            }
        case .quarterly:
            return interval == 1 ? "Quarterly" : "Every \(interval) quarters"
        }
    }
    
    private func ordinalSuffix(for number: Int) -> String {
        let lastDigit = number % 10
        let lastTwoDigits = number % 100
        
        if lastTwoDigits >= 11 && lastTwoDigits <= 13 {
            return "th"
        }
        
        switch lastDigit {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }
    
    private func saveRecurringInfo() {
        guard let service = recurringExpenseService else { return }
        
        do {
            if let existingRecurring = existingRecurringExpense {
                // Update existing recurring expense
                existingRecurring.amount = expense.amount
                existingRecurring.currencyCode = expense.currencyCode
                existingRecurring.merchant = expense.merchant
                existingRecurring.notes = expense.notes
                existingRecurring.paymentMethod = expense.paymentMethod
                existingRecurring.category = expense.category
                
                // Update pattern
                if let pattern = existingRecurring.pattern {
                    pattern.patternType = selectedPattern.rawValue
                    pattern.interval = Int32(interval)
                    pattern.dayOfMonth = showingDayPicker ? Int32(dayOfMonth) : 0
                    pattern.nextDueDate = nextExpectedDate ?? Date()
                }
            } else {
                // Create new recurring expense
                let recurringExpense = service.createRecurringExpense(
                    amount: expense.amount,
                    currencyCode: expense.currencyCode,
                    merchant: expense.merchant,
                    notes: expense.notes,
                    paymentMethod: expense.paymentMethod,
                    category: expense.category,
                    tags: expense.safeTags,
                    patternType: selectedPattern,
                    interval: Int32(interval),
                    dayOfMonth: showingDayPicker ? Int32(dayOfMonth) : nil,
                    dayOfWeek: nil,
                    startDate: expense.date
                )
                
                // Link expense to recurring template
                expense.recurringTemplate = recurringExpense
                
                // Clear legacy recurring info
                expense.isRecurring = false
                if let notes = expense.notes {
                    let cleanedNotes = notes.replacingOccurrences(
                        of: "\\[Recurring:.*?\\]",
                        with: "",
                        options: .regularExpression
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    expense.notes = cleanedNotes.isEmpty ? nil : cleanedNotes
                }
            }
            
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving recurring info: \(error)")
        }
    }
    
    private func removeRecurringInfo() {
        guard let service = recurringExpenseService else { return }
        
        do {
            if let existingRecurring = existingRecurringExpense {
                // Remove the relationship
                expense.recurringTemplate = nil
                
                // Deactivate the recurring expense
                service.deactivateRecurringExpense(existingRecurring)
            }
            
            // Clear legacy recurring info
            expense.isRecurring = false
            if let notes = expense.notes {
                var updatedNotes = notes
                
                // Remove the recurring pattern
                updatedNotes = updatedNotes.replacingOccurrences(
                    of: "\\n?\\[Recurring:.*?\\]", 
                    with: "", 
                    options: .regularExpression
                )
                
                // Remove reminder settings
                updatedNotes = updatedNotes.replacingOccurrences(
                    of: "\\n?\\[Reminder: \\d+ days?\\]", 
                    with: "", 
                    options: .regularExpression
                )
                
                // Remove auto-create settings
                updatedNotes = updatedNotes.replacingOccurrences(
                    of: "\\n?\\[AutoCreate: (true|false)\\]", 
                    with: "", 
                    options: .regularExpression
                )
                
                updatedNotes = updatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                expense.notes = updatedNotes.isEmpty ? nil : updatedNotes
            }
            
            try viewContext.save()
            dismiss()
        } catch {
            print("Error removing recurring info: \(error)")
        }
    }
    
    private func deleteRecurringTemplate(deleteGenerated: Bool) {
        guard let service = recurringExpenseService,
              let existingRecurring = existingRecurringExpense else { return }
        
        // Ensure the recurring expense is still valid
        guard !existingRecurring.isDeleted, existingRecurring.managedObjectContext != nil else {
            print("Warning: Attempting to delete an already deleted recurring template")
            dismiss()
            return
        }
        
        do {
            // Remove the relationship from the current expense first
            if !expense.isDeleted && expense.managedObjectContext != nil {
                expense.recurringTemplate = nil
                
                // Clear legacy recurring info
                expense.isRecurring = false
                if let notes = expense.notes {
                    var updatedNotes = notes
                    
                    // Remove the recurring pattern
                    updatedNotes = updatedNotes.replacingOccurrences(
                        of: "\\n?\\[Recurring:.*?\\]", 
                        with: "", 
                        options: .regularExpression
                    )
                    
                    // Remove reminder settings
                    updatedNotes = updatedNotes.replacingOccurrences(
                        of: "\\n?\\[Reminder: \\d+ days?\\]", 
                        with: "", 
                        options: .regularExpression
                    )
                    
                    // Remove auto-create settings
                    updatedNotes = updatedNotes.replacingOccurrences(
                        of: "\\n?\\[AutoCreate: (true|false)\\]", 
                        with: "", 
                        options: .regularExpression
                    )
                    
                    updatedNotes = updatedNotes.trimmingCharacters(in: .whitespacesAndNewlines)
                    expense.notes = updatedNotes.isEmpty ? nil : updatedNotes
                }
            }
            
            // Delete the recurring template and optionally its generated expenses
            service.deleteRecurringExpense(existingRecurring, deleteGeneratedExpenses: deleteGenerated)
            
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting recurring template: \(error)")
            dismiss()
        }
    }
}

#Preview {
    let context = NSPersistentContainer(name: "ReceiptScannerExpenseTracker").viewContext
    let expense = Expense(context: context)
    expense.id = UUID()
    expense.amount = NSDecimalNumber(string: "25.99")
    expense.date = Date()
    expense.merchant = "Test Merchant"
    
    return SimpleRecurringSetupView(expense: expense)
        .environment(\.managedObjectContext, context)
}