import SwiftUI
import UIKit

/// View for presenting template update choices to the user
struct TemplateUpdateChoiceView: View {
    let templateInfo: RecurringTemplateInfo
    let changes: [TemplateChangeType]
    let onChoice: (TemplateUpdateChoice) -> Void
    let onPreferenceChange: (TemplateUpdateBehavior) -> Void
    
    @State private var rememberChoice = false
    @State private var selectedBehavior: TemplateUpdateBehavior = .alwaysAsk
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                headerSection
                
                // Changes summary
                changesSection
                
                // Choice options
                choiceSection
                
                // Remember preference section
                preferenceSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Update Template?")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        onChoice(.cancel)
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "repeat.circle.fill")
                    .font(.title)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recurring Template Detected")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("This expense is linked to a recurring template")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Template info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Template:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(templateInfo.patternDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let nextDue = templateInfo.nextDueDate {
                    HStack {
                        Text("Next Due:")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Text(nextDue, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var changesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Changes Detected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text("The following changes were made to this expense:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<changes.count, id: \.self) { index in
                    changeRow(for: changes[index])
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private func changeRow(for change: TemplateChangeType) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: changeIcon(for: change))
                .foregroundColor(changeColor(for: change))
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(changeTitle(for: change))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(changeDescription(for: change))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var choiceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What would you like to do?")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                choiceButton(
                    title: "Update Template",
                    description: "Apply these changes to the recurring template and all future expenses",
                    icon: "repeat.circle.fill",
                    color: .blue,
                    action: { onChoice(.updateTemplate) }
                )
                
                choiceButton(
                    title: "Update Only This Expense",
                    description: "Keep the template unchanged, only modify this specific expense",
                    icon: "doc.circle.fill",
                    color: .green,
                    action: { onChoice(.updateExpenseOnly) }
                )
            }
        }
    }
    
    private func choiceButton(
        title: String,
        description: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            if rememberChoice {
                let behavior: TemplateUpdateBehavior = title.contains("Template") ? .alwaysUpdateTemplate : .alwaysUpdateExpenseOnly
                onPreferenceChange(behavior)
            }
            action()
            dismiss()
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Remember my choice", isOn: $rememberChoice)
                .font(.subheadline)
            
            if rememberChoice {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Future Behavior:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(TemplateUpdateBehavior.allCases, id: \.self) { behavior in
                            Button(action: {
                                selectedBehavior = behavior
                            }) {
                                VStack(alignment: .leading) {
                                    Text(behavior.displayName)
                                        .font(.subheadline)
                                    Text(behavior.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(selectedBehavior.displayName)
                                    .font(.subheadline)
                                Text(selectedBehavior.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray5))
                        .cornerRadius(8)
                    }
                }
                .padding(.leading, 16)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onChoice(.cancel)
                dismiss()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func changeIcon(for change: TemplateChangeType) -> String {
        switch change {
        case .amount: return "dollarsign.circle"
        case .merchant: return "building.2"
        case .category: return "folder"
        case .notes: return "note.text"
        case .paymentMethod: return "creditcard"
        case .currency: return "coloncurrencysign.circle"
        case .tags: return "tag"
        }
    }
    
    private func changeColor(for change: TemplateChangeType) -> Color {
        switch change {
        case .amount: return .green
        case .merchant: return .blue
        case .category: return .purple
        case .notes: return .orange
        case .paymentMethod: return .indigo
        case .currency: return .mint
        case .tags: return .pink
        }
    }
    
    private func changeTitle(for change: TemplateChangeType) -> String {
        switch change {
        case .amount: return "Amount"
        case .merchant: return "Merchant"
        case .category: return "Category"
        case .notes: return "Notes"
        case .paymentMethod: return "Payment Method"
        case .currency: return "Currency"
        case .tags: return "Tags"
        }
    }
    
    private func changeDescription(for change: TemplateChangeType) -> String {
        switch change {
        case .amount(let from, let to):
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            let fromStr = formatter.string(from: from) ?? from.stringValue
            let toStr = formatter.string(from: to) ?? to.stringValue
            return "Changed from \(fromStr) to \(toStr)"
            
        case .merchant(let from, let to):
            return "Changed from \"\(from)\" to \"\(to)\""
            
        case .category(let from, let to):
            let fromName = from?.name ?? "None"
            let toName = to?.name ?? "None"
            return "Changed from \"\(fromName)\" to \"\(toName)\""
            
        case .notes(let from, let to):
            let fromPreview = String((from ?? "").prefix(30))
            let toPreview = String((to ?? "").prefix(30))
            return "Changed from \"\(fromPreview)...\" to \"\(toPreview)...\""
            
        case .paymentMethod(let from, let to):
            let fromMethod = from ?? "None"
            let toMethod = to ?? "None"
            return "Changed from \"\(fromMethod)\" to \"\(toMethod)\""
            
        case .currency(let from, let to):
            return "Changed from \(from) to \(to)"
            
        case .tags(let from, let to):
            let fromCount = from.count
            let toCount = to.count
            return "Changed from \(fromCount) tags to \(toCount) tags"
        }
    }
}

// MARK: - Preview

struct TemplateUpdateChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        TemplateUpdateChoiceView(
            templateInfo: RecurringTemplateInfo(
                templateId: UUID(),
                patternDescription: "Monthly on the 15th",
                nextDueDate: Date(),
                isActive: true,
                lastGeneratedDate: nil,
                totalGeneratedExpenses: 3
            ),
            changes: [
                TemplateChangeType.amount(from: NSDecimalNumber(value: 50.00), to: NSDecimalNumber(value: 55.00)),
                TemplateChangeType.merchant(from: "Old Store", to: "New Store")
            ],
            onChoice: { _ in },
            onPreferenceChange: { _ in }
        )
    }
}