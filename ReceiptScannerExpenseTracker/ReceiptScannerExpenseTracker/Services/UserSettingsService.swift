import Foundation

/// Service for managing user preferences and settings
class UserSettingsService {
    static let shared = UserSettingsService()
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let templateUpdateBehavior = "templateUpdateBehavior"
        static let preferredCurrency = "preferredCurrency"
        static let biometricAuthEnabled = "biometricAuthEnabled"
        static let autoBackupEnabled = "autoBackupEnabled"
    }
    
    private init() {}
    
    // MARK: - Template Update Behavior
    
    /// Get the current template update behavior preference
    func getTemplateUpdateBehavior() -> TemplateUpdateBehavior {
        let rawValue = userDefaults.string(forKey: Keys.templateUpdateBehavior) ?? TemplateUpdateBehavior.alwaysAsk.rawValue
        return TemplateUpdateBehavior(rawValue: rawValue) ?? .alwaysAsk
    }
    
    /// Set the template update behavior preference
    func setTemplateUpdateBehavior(_ behavior: TemplateUpdateBehavior) {
        userDefaults.set(behavior.rawValue, forKey: Keys.templateUpdateBehavior)
    }
    
    /// Check if we should ask about template updates
    func shouldAskAboutTemplateUpdates() -> Bool {
        return getTemplateUpdateBehavior() == .alwaysAsk
    }
    
    /// Check if we should automatically update templates
    func shouldAutoUpdateTemplates() -> Bool {
        return getTemplateUpdateBehavior() == .alwaysUpdateTemplate
    }
    
    /// Check if we should only update expenses (not templates)
    func shouldOnlyUpdateExpenses() -> Bool {
        return getTemplateUpdateBehavior() == .alwaysUpdateExpenseOnly
    }
    
    // MARK: - Currency Settings
    
    /// Get the preferred currency code
    func getPreferredCurrency() -> String {
        return userDefaults.string(forKey: Keys.preferredCurrency) ?? "USD"
    }
    
    /// Set the preferred currency code
    func setPreferredCurrency(_ currencyCode: String) {
        userDefaults.set(currencyCode, forKey: Keys.preferredCurrency)
    }
    
    // MARK: - Security Settings
    
    /// Check if biometric authentication is enabled
    func isBiometricAuthEnabled() -> Bool {
        return userDefaults.bool(forKey: Keys.biometricAuthEnabled)
    }
    
    /// Set biometric authentication preference
    func setBiometricAuthEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.biometricAuthEnabled)
    }
    
    // MARK: - Backup Settings
    
    /// Check if auto backup is enabled
    func isAutoBackupEnabled() -> Bool {
        return userDefaults.bool(forKey: Keys.autoBackupEnabled)
    }
    
    /// Set auto backup preference
    func setAutoBackupEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.autoBackupEnabled)
    }
    
    // MARK: - Reset Settings
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        userDefaults.removeObject(forKey: Keys.templateUpdateBehavior)
        userDefaults.removeObject(forKey: Keys.preferredCurrency)
        userDefaults.removeObject(forKey: Keys.biometricAuthEnabled)
        userDefaults.removeObject(forKey: Keys.autoBackupEnabled)
    }
}