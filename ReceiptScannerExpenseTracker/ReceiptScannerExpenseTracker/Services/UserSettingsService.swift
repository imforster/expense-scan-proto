import Foundation

/// Service for managing user preferences and settings
class UserSettingsService: ObservableObject {
    static let shared = UserSettingsService()
    
    private init() {
        // Initialize with current values from UserDefaults, defaulting to CAD for Canadian users
        _preferredCurrencyCode = Published(initialValue: UserDefaults.standard.string(forKey: Keys.preferredCurrencyCode) ?? "CAD")
        _templateUpdateBehavior = Published(initialValue: TemplateUpdateBehavior(rawValue: UserDefaults.standard.string(forKey: Keys.templateUpdateBehavior) ?? "") ?? .alwaysAsk)
    }
    
    // MARK: - Keys
    private enum Keys {
        static let preferredCurrencyCode = "preferredCurrencyCode"
        static let templateUpdateBehavior = "templateUpdateBehavior"
    }
    
    // MARK: - Published Properties
    @Published var preferredCurrencyCode: String {
        didSet {
            UserDefaults.standard.set(preferredCurrencyCode, forKey: Keys.preferredCurrencyCode)
        }
    }
    
    @Published var templateUpdateBehavior: TemplateUpdateBehavior {
        didSet {
            UserDefaults.standard.set(templateUpdateBehavior.rawValue, forKey: Keys.templateUpdateBehavior)
        }
    }
    
    // MARK: - Computed Properties
    var preferredCurrencyInfo: CurrencyInfo? {
        return CurrencyService.shared.getCurrencyInfo(for: preferredCurrencyCode)
    }
    
    // MARK: - Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        preferredCurrencyCode = "CAD"
        templateUpdateBehavior = .alwaysAsk
    }
    
    /// Get the default currency code for new expenses
    func getDefaultCurrencyCode() -> String {
        return preferredCurrencyCode
    }
    
    /// Update the preferred currency
    func setPreferredCurrency(_ currencyCode: String) {
        preferredCurrencyCode = currencyCode
    }
    
    /// Get the template update behavior preference
    func getTemplateUpdateBehavior() -> TemplateUpdateBehavior {
        return templateUpdateBehavior
    }
    
    /// Set the template update behavior preference
    func setTemplateUpdateBehavior(_ behavior: TemplateUpdateBehavior) {
        templateUpdateBehavior = behavior
    }
    
    /// Check if user wants to be asked about template updates
    func shouldAskAboutTemplateUpdates() -> Bool {
        return templateUpdateBehavior == .alwaysAsk
    }
    
    /// Check if user wants to automatically update templates
    func shouldAutoUpdateTemplates() -> Bool {
        return templateUpdateBehavior == .alwaysUpdateTemplate
    }
    
    /// Check if user wants to only update expenses (never templates)
    func shouldOnlyUpdateExpenses() -> Bool {
        return templateUpdateBehavior == .alwaysUpdateExpenseOnly
    }
}