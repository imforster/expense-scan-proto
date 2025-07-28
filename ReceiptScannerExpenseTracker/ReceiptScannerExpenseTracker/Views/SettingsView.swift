import SwiftUI
import UIKit

struct SettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingThemeSelection = false
    
    var body: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(title: "Settings", showBackButton: false)
            
            List {
                Section(header: Text("Account")) {
                    SettingsRow(
                        icon: "person.circle.fill",
                        title: "Profile",
                        action: {}
                    )
                    
                    SettingsRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        action: {}
                    )
                }
                
                Section(header: Text("Preferences")) {
                    SettingsRow(
                        icon: "paintbrush.fill",
                        title: "Appearance",
                        subtitle: themeManager.currentTheme.displayName,
                        action: {
                            showingThemeSelection = true
                        }
                    )
                    
                    SettingsRow(
                        icon: "accessibility",
                        title: "Accessibility",
                        action: {}
                    )
                }
                
                Section(header: Text("Data")) {
                    SettingsRow(
                        icon: "icloud.fill",
                        title: "Sync & Backup",
                        action: {}
                    )
                    
                    SettingsRow(
                        icon: "lock.fill",
                        title: "Privacy & Security",
                        action: {}
                    )
                }
                
                Section {
                    SettingsRow(
                        icon: "info.circle.fill",
                        title: "About",
                        action: {}
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .background(AppTheme.backgroundColor)
        .sheet(isPresented: $showingThemeSelection) {
            ThemeSelectionSettingsView()
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: () -> Void
    
    init(icon: String, title: String, subtitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppTheme.primaryColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ThemeSelectionSettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTheme: ThemeMode
    
    init() {
        _selectedTheme = State(initialValue: ThemeManager.shared.currentTheme)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Choose Theme")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Text("Select your preferred appearance")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                
                // Theme options with live preview
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(ThemeMode.allCases, id: \.self) { theme in
                            ThemeOptionSettingsCard(
                                theme: theme,
                                isSelected: selectedTheme == theme,
                                onSelect: {
                                    selectedTheme = theme
                                    // Apply theme immediately for preview
                                    themeManager.setTheme(theme)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 30)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    // Revert to original theme if cancelled
                    themeManager.setTheme(ThemeManager.shared.currentTheme)
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.semibold)
            )
        }
        .onAppear {
            selectedTheme = themeManager.currentTheme
        }
    }
}

struct ThemeOptionSettingsCard: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Theme preview
                ThemePreviewView(theme: theme)
                    .frame(width: 60, height: 80)
                
                // Theme info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: theme.iconName)
                            .font(.title3)
                            .foregroundColor(isSelected ? .white : AppTheme.primaryColor)
                        
                        Text(theme.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(isSelected ? .white : .primary)
                    }
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(isSelected ? AppTheme.primaryColor : Color(UIColor.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(UIColor.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
}

#Preview("Theme Selection") {
    ThemeSelectionSettingsView()
}