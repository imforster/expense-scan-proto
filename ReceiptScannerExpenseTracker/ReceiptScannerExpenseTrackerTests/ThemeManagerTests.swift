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
        themeManager = ThemeManager()
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
        let savedTheme = testUserDefaults.string(forKey: "selected_theme")
        XCTAssertEqual(savedTheme, "dark")
        
        // Create a new instance to test persistence
        let newThemeManager = ThemeManager()
        XCTAssertEqual(newThemeManager.currentTheme, .dark)
        XCTAssertEqual(newThemeManager.colorScheme, .dark)
    }
    
    func testThemeModeDisplayNames() {
        XCTAssertEqual(ThemeMode.light.displayName, "Light")
        XCTAssertEqual(ThemeMode.dark.displayName, "Dark")
        XCTAssertEqual(ThemeMode.system.displayName, "System")
    }
    
    func testThemeModeIcons() {
        XCTAssertEqual(ThemeMode.light.iconName, "sun.max.fill")
        XCTAssertEqual(ThemeMode.dark.iconName, "moon.fill")
        XCTAssertEqual(ThemeMode.system.iconName, "gear")
    }
}