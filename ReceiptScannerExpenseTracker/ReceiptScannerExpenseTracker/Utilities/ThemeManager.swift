import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: ThemeMode = .system
    @Published var colorScheme: ColorScheme?
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "selected_theme"
    
    init() {
        loadTheme()
        updateColorScheme()
    }
    
    func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
        updateColorScheme()
        saveTheme()
    }
    
    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil // Use system default
        }
    }
    
    private func loadTheme() {
        if let themeRawValue = userDefaults.object(forKey: themeKey) as? String,
           let theme = ThemeMode(rawValue: themeRawValue) {
            currentTheme = theme
        }
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
}

enum ThemeMode: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .system:
            return "System"
        }
    }
    
    var iconName: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "gear"
        }
    }
    
    var description: String {
        switch self {
        case .light:
            return "Always use light mode"
        case .dark:
            return "Always use dark mode"
        case .system:
            return "Follow system settings"
        }
    }
}

struct ThemeSelectionView: View {
    @StateObject private var themeManager = ThemeManager.shared
    let onComplete: () -> Void
    let onSkip: () -> Void
    
    @State private var selectedTheme: ThemeMode = .system
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "paintbrush.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Choose Your Theme")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select your preferred appearance. You can change this later in settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 60)
            
            // Theme options
            VStack(spacing: 16) {
                ForEach(ThemeMode.allCases, id: \.self) { theme in
                    ThemeOptionCard(
                        theme: theme,
                        isSelected: selectedTheme == theme,
                        onSelect: { selectedTheme = theme }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Apply Theme") {
                    themeManager.setTheme(selectedTheme)
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("Skip for Now") {
                    onSkip()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
        .onAppear {
            selectedTheme = themeManager.currentTheme
        }
    }
}

struct ThemeOptionCard: View {
    let theme: ThemeMode
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Theme icon
                Image(systemName: theme.iconName)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 30)
                
                // Theme info
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
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
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Theme preview component for settings
struct ThemePreviewView: View {
    let theme: ThemeMode
    
    var body: some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 8)
                .fill(previewBackgroundColor)
                .frame(height: 60)
                .overlay(
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(previewTextColor)
                            .frame(height: 8)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                        
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(previewTextColor.opacity(0.6))
                                .frame(height: 6)
                            
                            Spacer()
                            
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 12, height: 12)
                        }
                        .padding(.horizontal, 8)
                    }
                )
            
            Text(theme.displayName)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    private var previewBackgroundColor: Color {
        switch theme {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .system:
            return Color(.systemBackground)
        }
    }
    
    private var previewTextColor: Color {
        switch theme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        case .system:
            return Color(.label)
        }
    }
}