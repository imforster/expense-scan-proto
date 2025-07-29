import XCTest
@testable import ReceiptScannerExpenseTracker

class ThemeManagerTests: XCTestCase {
    var testUserDefaults: UserDefaults!
    var themeManager: ThemeManager!
    
    override func setUp() {
        super.setUp()
        // Create a test UserDefaults instance
        testUserDefaults = UserDefaults(suiteName: "ThemeManagerTests")!
        testUserDefaults.removePersistentDomain(forName: "ThemeManagerTests")
        themeManager = ThemeManager(userDefaults: testUserDefaults)
    }
    
    override func tearDown() {
        testUserDefaults.removePersistentDomain(forName: "ThemeManagerTests")
        testUserDefaults = nil
        themeManager = nil
        super.tearDown()
    }
    
    func testDefaultThemeIsSystem() {
        XCTAssertEqual(themeManager.currentTheme, .system)
        XCTAssertNil(themeManager.colorScheme)
    }
    
    func testSetLightTheme() {
        themeManager.setTheme(.light)
        XCTAssertEqual(themeManager.currentTheme, .light)
        XCTAssertEqual(themeManager.colorScheme, .light)
    }
    
    func testSetDarkTheme() {
        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.currentTheme, .dark)
        XCTAssertEqual(themeManager.colorScheme, .dark)
    }
    
    func testSetSystemTheme() {
        themeManager.setTheme(.system)
        XCTAssertEqual(themeManager.currentTheme, .system)
        XCTAssertNil(themeManager.colorScheme)
    }
    
    func testThemePersistence() {
        themeManager.setTheme(.dark)
        
        // Verify the setting is saved
        let savedTheme = testUserDefaults.string(forKey: "app_theme_mode")
        XCTAssertEqual(savedTheme, "dark")
        
        // Create a new instance to test persistence
        let newThemeManager = ThemeManager(userDefaults: testUserDefaults)
        XCTAssertEqual(newThemeManager.currentTheme, .dark)
        XCTAssertEqual(newThemeManager.colorScheme, .dark)
    }
    
    func testThemeModeDisplayNames() {
        XCTAssertEqual(ThemeMode.light.displayName, "Light")
        XCTAssertEqual(ThemeMode.dark.displayName, "Dark")
        XCTAssertEqual(ThemeMode.system.displayName, "System")
    }
    
    func testThemeModeIcons() {
        XCTAssertEqual(ThemeMode.light.icon, "sun.max")
        XCTAssertEqual(ThemeMode.dark.icon, "moon")
        XCTAssertEqual(ThemeMode.system.icon, "circle.lefthalf.filled")
    }
    
    func testEffectiveColorScheme() {
        let themeManager = ThemeManager.shared
        themeManager.setTheme(.light)
        XCTAssertEqual(themeManager.getEffectiveColorScheme(), .light)
        
        themeManager.setTheme(.dark)
        XCTAssertEqual(themeManager.getEffectiveColorScheme(), .dark)
        
        themeManager.setTheme(.system)
        // System theme should return either light or dark based on system settings
        let effectiveScheme = themeManager.getEffectiveColorScheme()
        XCTAssertTrue(effectiveScheme == .light || effectiveScheme == .dark)
    }
    
    func testIsDarkMode() {
        let themeManager = ThemeManager.shared
        themeManager.setTheme(.light)
        XCTAssertFalse(themeManager.isDarkMode)
        
        themeManager.setTheme(.dark)
        XCTAssertTrue(themeManager.isDarkMode)
    }
}