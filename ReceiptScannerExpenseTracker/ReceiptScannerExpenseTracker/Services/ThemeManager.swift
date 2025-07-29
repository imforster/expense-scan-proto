import Combine
import SwiftUI

/// Theme options available to the user
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

    var icon: String {
        switch self {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        case .system:
            return "circle.lefthalf.filled"
        }
    }
}

/// ThemeManager handles theme state management and persistence
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: ThemeMode {
        didSet {
            saveTheme()
            updateColorScheme()
        }
    }

    @Published var colorScheme: ColorScheme?

    private let userDefaults: UserDefaults
    private let themeKey = "app_theme_mode"

    init(userDefaults: UserDefaults = UserDefaults.standard) {
        self.userDefaults = userDefaults
        // Load saved theme or default to system
        let savedTheme = userDefaults.string(forKey: themeKey) ?? ThemeMode.system.rawValue
        self.currentTheme = ThemeMode(rawValue: savedTheme) ?? .system
        updateColorScheme()
    }

    private convenience init() {
        self.init(userDefaults: UserDefaults.standard)
    }

    /// Save the current theme to UserDefaults
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }

    /// Update the color scheme based on current theme
    private func updateColorScheme() {
        switch currentTheme {
        case .light:
            colorScheme = .light
        case .dark:
            colorScheme = .dark
        case .system:
            colorScheme = nil  // Let system decide
        }
    }

    /// Set a new theme
    func setTheme(_ theme: ThemeMode) {
        currentTheme = theme
    }

    /// Get the effective color scheme (resolves system theme)
    func getEffectiveColorScheme() -> ColorScheme {
        switch currentTheme {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            // Return current system color scheme
            return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
        }
    }

    /// Check if current theme is dark
    var isDarkMode: Bool {
        return getEffectiveColorScheme() == .dark
    }
}
