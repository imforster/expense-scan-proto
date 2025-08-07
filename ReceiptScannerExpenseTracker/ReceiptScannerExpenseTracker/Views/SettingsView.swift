import SwiftUI

/// Settings view with theme selection and other app preferences
struct SettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var userSettings = UserSettingsService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCurrencyPicker = false
    
    var body: some View {
        List {
            // Currency Selection Section
            Section {
                CurrencySettingRow(
                    selectedCurrencyCode: userSettings.preferredCurrencyCode,
                    onTap: {
                        showingCurrencyPicker = true
                    }
                )
            } header: {
                Text("Currency")
                    .font(.headline)
            } footer: {
                Text("Set your preferred currency for new expenses. This will be used as the default when creating expenses.")
                    .font(.caption)
            }
            
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
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .preferredColorScheme(themeManager.colorScheme)
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencySelectionView(selectedCurrencyCode: $userSettings.preferredCurrencyCode)
        }
    }
}

/// Currency setting row
struct CurrencySettingRow: View {
    let selectedCurrencyCode: String
    let onTap: () -> Void
    
    private var currencyInfo: CurrencyInfo? {
        CurrencyService.shared.getCurrencyInfo(for: selectedCurrencyCode)
    }
    
    var body: some View {
        HStack {
            Image(systemName: "dollarsign.circle")
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Default Currency")
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text("Used for new expenses")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                if let currencyInfo = currencyInfo {
                    Text(currencyInfo.symbol)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    Text(currencyInfo.code)
                        .foregroundColor(.secondary)
                } else {
                    Text(selectedCurrencyCode)
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .accessibilityLabel("Default currency: \(currencyInfo?.displayName ?? selectedCurrencyCode)")
        .accessibilityHint("Tap to change default currency")
        .accessibilityAddTraits(.isButton)
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
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyService.shared.formatAmount(NSDecimalNumber(value: 4.50), currencyCode: UserSettingsService.shared.preferredCurrencyCode))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if UserSettingsService.shared.preferredCurrencyCode != CurrencyService.shared.getLocalCurrencyCode() {
                        Text(UserSettingsService.shared.preferredCurrencyCode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                }
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