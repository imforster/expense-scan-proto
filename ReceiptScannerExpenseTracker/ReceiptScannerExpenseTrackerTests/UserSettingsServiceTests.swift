import XCTest
@testable import ReceiptScannerExpenseTracker

final class UserSettingsServiceTests: XCTestCase {
    
    var userSettings: UserSettingsService!
    
    override func setUp() {
        super.setUp()
        userSettings = UserSettingsService.shared
        // Reset to defaults for testing
        userSettings.resetToDefaults()
    }
    
    override func tearDown() {
        // Reset to defaults after testing
        userSettings.resetToDefaults()
        userSettings = nil
        super.tearDown()
    }
    
    // MARK: - Currency Settings Tests
    
    func testDefaultCurrencyIsLocalCurrency() {
        let defaultCurrency = userSettings.getDefaultCurrencyCode()
        let localCurrency = CurrencyService.shared.getLocalCurrencyCode()
        
        XCTAssertEqual(defaultCurrency, localCurrency, "Default currency should be local currency")
    }
    
    func testSetPreferredCurrency() {
        let testCurrency = "EUR"
        
        userSettings.setPreferredCurrency(testCurrency)
        
        XCTAssertEqual(userSettings.preferredCurrencyCode, testCurrency, "Preferred currency should be updated")
        XCTAssertEqual(userSettings.getDefaultCurrencyCode(), testCurrency, "Default currency should return preferred currency")
    }
    
    func testPreferredCurrencyInfo() {
        let testCurrency = "GBP"
        
        userSettings.setPreferredCurrency(testCurrency)
        
        let currencyInfo = userSettings.preferredCurrencyInfo
        XCTAssertNotNil(currencyInfo, "Should have currency info for valid currency")
        XCTAssertEqual(currencyInfo?.code, testCurrency, "Currency info should match preferred currency")
        XCTAssertEqual(currencyInfo?.symbol, "£", "Should have correct symbol for GBP")
    }
    
    func testPreferredCurrencyInfoForInvalidCurrency() {
        let invalidCurrency = "INVALID"
        
        userSettings.setPreferredCurrency(invalidCurrency)
        
        let currencyInfo = userSettings.preferredCurrencyInfo
        XCTAssertNil(currencyInfo, "Should return nil for invalid currency")
    }
    
    func testResetToDefaults() {
        // Set a non-default currency
        userSettings.setPreferredCurrency("JPY")
        XCTAssertEqual(userSettings.preferredCurrencyCode, "JPY", "Should be set to JPY")
        
        // Reset to defaults
        userSettings.resetToDefaults()
        
        let localCurrency = CurrencyService.shared.getLocalCurrencyCode()
        XCTAssertEqual(userSettings.preferredCurrencyCode, localCurrency, "Should reset to local currency")
    }
    
    func testCurrencyPersistence() {
        let testCurrency = "CAD"
        
        // Set preferred currency
        userSettings.setPreferredCurrency(testCurrency)
        
        // Create new instance to test persistence
        let newUserSettings = UserSettingsService.shared
        
        XCTAssertEqual(newUserSettings.preferredCurrencyCode, testCurrency, "Currency preference should persist")
    }
    
    // MARK: - Integration Tests
    
    func testCurrencyServiceUsesPreferredCurrency() {
        let testCurrency = "EUR"
        
        userSettings.setPreferredCurrency(testCurrency)
        
        let preferredFromService = CurrencyService.shared.getPreferredCurrencyCode()
        XCTAssertEqual(preferredFromService, testCurrency, "CurrencyService should return user's preferred currency")
    }
    
    func testMultipleCurrencyChanges() {
        let currencies = ["USD", "EUR", "GBP", "JPY", "CAD"]
        
        for currency in currencies {
            userSettings.setPreferredCurrency(currency)
            XCTAssertEqual(userSettings.preferredCurrencyCode, currency, "Should update to \(currency)")
            XCTAssertEqual(userSettings.getDefaultCurrencyCode(), currency, "Default should return \(currency)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testCurrencySettingPerformance() {
        measure {
            for i in 0..<100 {
                let currency = i % 2 == 0 ? "USD" : "EUR"
                userSettings.setPreferredCurrency(currency)
            }
        }
    }
}