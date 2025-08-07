import Foundation

/// Service for managing user preferences and settings
class UserSettingsService: ObservableObject {
    static let shared = UserSettingsService()
    
    private init() {
        // Initialize with current values from UserDefaults
        _preferredCurrencyCode = Published(initialValue: UserDefaults.standard.string(forKey: Keys.preferredCurrencyCode) ?? CurrencyService.shared.getLocalCurrencyCode())
    }
    
    // MARK: - Keys
    private enum Keys {
        static let preferredCurrencyCode = "preferredCurrencyCode"
    }
    
    // MARK: - Published Properties
    @Published var preferredCurrencyCode: String {
        didSet {
            UserDefaults.standard.set(preferredCurrencyCode, forKey: Keys.preferredCurrencyCode)
        }
    }
    
    // MARK: - Computed Properties
    var preferredCurrencyInfo: CurrencyInfo? {
        return CurrencyService.shared.getCurrencyInfo(for: preferredCurrencyCode)
    }
    
    // MARK: - Methods
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        preferredCurrencyCode = CurrencyService.shared.getLocalCurrencyCode()
    }
    
    /// Get the default currency code for new expenses
    func getDefaultCurrencyCode() -> String {
        return preferredCurrencyCode
    }
    
    /// Update the preferred currency
    func setPreferredCurrency(_ currencyCode: String) {
        preferredCurrencyCode = currencyCode
    }
}