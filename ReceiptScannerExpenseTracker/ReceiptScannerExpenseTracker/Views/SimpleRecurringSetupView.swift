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
    
    @State private var selectedPattern: RecurringPattern = .monthly
    @State private var interval: Int = 1
    @State private var dayOfMonth: Int = 1
    @State private var showingDayPicker = false
    @State private var nextExpectedDate: Date?
    @State private var shouldRemind: Bool = false
    @State private var reminderDays: Int = 1
    @State private var autoCreateNext: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Recurring Pattern")) {
                    Picker("Frequency", selection: $selectedPattern) {
                        ForEach(RecurringPattern.allCases.filter { $0 != .none }, id: \.self) { pattern in
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
                    let recurringInfo = RecurringInfo(
                        pattern: selectedPattern,
                        interval: interval,
                        dayOfMonth: showingDayPicker ? dayOfMonth : nil
                    )
                    
                    Text(recurringInfo.description)
                        .foregroundColor(.secondary)
                    
                    let nextDate = recurringInfo.calculateNextDate(from: expense.date)
                    Text("Next occurrence: \(nextDate, style: .date)")
                        .foregroundColor(.secondary)
                }
                
                if expense.isRecurring {
                    Section {
                        Button("Remove Recurring Setting", role: .destructive) {
                            removeRecurringInfo()
                        }
                    }
                }
            }
            .navigationTitle(expense.isRecurring ? "Update Recurring" : "Set as Recurring")
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
            loadExistingRecurringInfo()
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
    
    private func loadExistingRecurringInfo() {
        // Set default day of month from expense date
        dayOfMonth = Calendar.current.component(.day, from: expense.date)
        
        // Set default next expected date
        nextExpectedDate = Calendar.current.date(byAdding: .month, value: 1, to: expense.date)
        
        // If expense is already recurring, load its settings
        if expense.isRecurring, let recurringInfo = expense.recurringInfo {
            selectedPattern = recurringInfo.pattern
            interval = recurringInfo.interval
            
            if let existingDayOfMonth = recurringInfo.dayOfMonth {
                dayOfMonth = existingDayOfMonth
                showingDayPicker = true
            } else {
                showingDayPicker = false
            }
            
            // Calculate next expected date based on recurring pattern
            nextExpectedDate = recurringInfo.calculateNextDate(from: expense.date)
        }
        
        // Load additional recurring properties from expense notes if they exist
        // These would be stored in a similar format as the recurring pattern
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
    
    private func saveRecurringInfo() {
        let recurringInfo = RecurringInfo(
            pattern: selectedPattern,
            interval: interval,
            dayOfMonth: showingDayPicker ? dayOfMonth : nil
        )
        
        expense.setRecurringInfo(recurringInfo)
        
        // Save additional recurring properties to notes
        var notesText = expense.notes ?? ""
        
        // Remove any existing reminder and auto-create settings
        notesText = notesText.replacingOccurrences(of: "\\[Reminder: \\d+ days?\\]", with: "", options: .regularExpression)
        notesText = notesText.replacingOccurrences(of: "\\[AutoCreate: (true|false)\\]", with: "", options: .regularExpression)
        
        // Add reminder setting if enabled
        if shouldRemind {
            let reminderText = "\n[Reminder: \(reminderDays) \(reminderDays == 1 ? "day" : "days")]"
            notesText += reminderText
        }
        
        // Add auto-create setting if enabled
        if autoCreateNext {
            notesText += "\n[AutoCreate: true]"
        }
        
        // Clean up any extra newlines
        notesText = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        expense.notes = notesText.isEmpty ? nil : notesText
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving recurring info: \(error)")
        }
    }
    
    private func removeRecurringInfo() {
        // Set isRecurring to false
        expense.isRecurring = false
        
        // Remove all recurring-related info from notes
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
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error removing recurring info: \(error)")
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