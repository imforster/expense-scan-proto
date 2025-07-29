import SwiftUI

/// Settings view with theme selection and other app preferences
struct SettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            // Theme Selection Section
            Section {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    ThemeSelectionRow(
                        theme: theme,
                        isSelected: themeManager.currentTheme == theme,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                themeManager.setTheme(theme)
                            }
                        }
                    )
                }
            } header: {
                Text("Appearance")
                    .font(.headline)
            } footer: {
                Text("Choose how the app looks. System will follow your device's appearance settings.")
                    .font(.caption)
            }
            
            // Theme Preview Section
            Section {
                ThemePreviewCard()
            } header: {
                Text("Preview")
                    .font(.headline)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
    }
}

/// Individual theme selection row
struct ThemeSelectionRow: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: theme.iconName)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.displayName)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(themeDescription(for: theme))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this theme")
        .accessibilityAddTraits(.isButton)
    }
    
    private func themeDescription(for theme: ThemeMode) -> String {
        switch theme {
        case .light:
            return "Always use light appearance"
        case .dark:
            return "Always use dark appearance"
        case .system:
            return "Follow system settings"
        }
    }
}

/// Real-time theme preview card
struct ThemePreviewCard: View {
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Preview")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "creditcard")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
            
            Text("This is how your expenses will look with the selected theme.")
                .font(.body)
                .foregroundColor(.secondary)
            
            // Sample expense item
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Coffee Shop")
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text("Food & Dining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("$4.50")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Sample button
            Button("Add Expense") {
                // Preview only - no action
            }
            .frame(height: 50)
            .frame(maxWidth: .infinity)
            .background(.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color(.systemGray4).opacity(0.3), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Theme preview showing how the app will look with current settings")
    }
}

#Preview("Settings View - Light") {
    SettingsView()
        .preferredColorScheme(.light)
}

#Preview("Settings View - Dark") {
    SettingsView()
        .preferredColorScheme(.dark)
}