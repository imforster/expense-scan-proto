import XCTest
@testable import ReceiptScannerExpenseTracker

final class CurrencyServiceTests: XCTestCase {
    
    var currencyService: CurrencyService!
    
    override func setUp() {
        super.setUp()
        currencyService = CurrencyService.shared
    }
    
    override func tearDown() {
        currencyService = nil
        super.tearDown()
    }
    
    // MARK: - Currency Info Tests
    
    func testGetLocalCurrencyCode() {
        let localCurrency = currencyService.getLocalCurrencyCode()
        XCTAssertFalse(localCurrency.isEmpty, "Local currency code should not be empty")
        XCTAssertEqual(localCurrency.count, 3, "Currency code should be 3 characters")
    }
    
    func testGetCurrencyInfo() {
        let usdInfo = currencyService.getCurrencyInfo(for: "USD")
        XCTAssertNotNil(usdInfo, "USD currency info should exist")
        XCTAssertEqual(usdInfo?.code, "USD")
        XCTAssertEqual(usdInfo?.name, "US Dollar")
        XCTAssertEqual(usdInfo?.symbol, "$")
        
        let invalidInfo = currencyService.getCurrencyInfo(for: "INVALID")
        XCTAssertNil(invalidInfo, "Invalid currency code should return nil")
    }
    
    func testGetAllCurrencies() {
        let currencies = currencyService.getAllCurrencies()
        XCTAssertFalse(currencies.isEmpty, "Should return available currencies")
        XCTAssertTrue(currencies.contains { $0.code == "USD" }, "Should contain USD")
        XCTAssertTrue(currencies.contains { $0.code == "EUR" }, "Should contain EUR")
        
        // Check if sorted alphabetically by name
        let sortedNames = currencies.map { $0.name }
        XCTAssertEqual(sortedNames, sortedNames.sorted(), "Currencies should be sorted by name")
    }
    
    func testSearchCurrencies() {
        // Test search by name
        let dollarCurrencies = currencyService.searchCurrencies("Dollar")
        XCTAssertTrue(dollarCurrencies.contains { $0.code == "USD" }, "Should find USD when searching for Dollar")
        XCTAssertTrue(dollarCurrencies.contains { $0.code == "CAD" }, "Should find CAD when searching for Dollar")
        
        // Test search by code
        let euroCurrencies = currencyService.searchCurrencies("EUR")
        XCTAssertTrue(euroCurrencies.contains { $0.code == "EUR" }, "Should find EUR when searching for EUR")
        
        // Test case insensitive search
        let poundCurrencies = currencyService.searchCurrencies("pound")
        XCTAssertTrue(poundCurrencies.contains { $0.code == "GBP" }, "Should find GBP when searching for pound (lowercase)")
        
        // Test empty search returns all currencies
        let allCurrencies = currencyService.searchCurrencies("")
        XCTAssertEqual(allCurrencies.count, currencyService.getAllCurrencies().count, "Empty search should return all currencies")
    }
    
    // MARK: - Currency Formatting Tests
    
    func testFormatAmount() {
        let amount = NSDecimalNumber(string: "123.45")
        
        // Test USD formatting
        let usdFormatted = currencyService.formatAmount(amount, currencyCode: "USD")
        XCTAssertTrue(usdFormatted.contains("123.45"), "Should contain the amount")
        XCTAssertTrue(usdFormatted.contains("$"), "USD should contain dollar symbol")
        
        // Test EUR formatting
        let eurFormatted = currencyService.formatAmount(amount, currencyCode: "EUR")
        XCTAssertTrue(eurFormatted.contains("123.45"), "Should contain the amount")
        XCTAssertTrue(eurFormatted.contains("€"), "EUR should contain euro symbol")
        
        // Test JPY formatting (no decimal places)
        let jpyAmount = NSDecimalNumber(string: "1000")
        let jpyFormatted = currencyService.formatAmount(jpyAmount, currencyCode: "JPY")
        XCTAssertTrue(jpyFormatted.contains("1000") || jpyFormatted.contains("1,000"), "Should contain the amount")
        XCTAssertTrue(jpyFormatted.contains("¥"), "JPY should contain yen symbol")
    }
    
    func testFormatAmountWithLocalCurrency() {
        let amount = NSDecimalNumber(string: "50.00")
        let formatted = currencyService.formatAmountWithLocalCurrency(amount)
        
        XCTAssertFalse(formatted.isEmpty, "Formatted amount should not be empty")
        XCTAssertTrue(formatted.contains("50"), "Should contain the amount")
    }
    
    // MARK: - Currency Detection Tests
    
    func testDetectCurrencyFromText() {
        // Test USD detection
        let usdText = "Total: $25.99 USD"
        let detectedUSD = currencyService.detectCurrencyFromText(usdText)
        XCTAssertEqual(detectedUSD, "USD", "Should detect USD from text with dollar symbol")
        
        // Test EUR detection
        let eurText = "Total: €19.50 EUR"
        let detectedEUR = currencyService.detectCurrencyFromText(eurText)
        XCTAssertEqual(detectedEUR, "EUR", "Should detect EUR from text with euro symbol")
        
        // Test GBP detection
        let gbpText = "Total: £15.75"
        let detectedGBP = currencyService.detectCurrencyFromText(gbpText)
        XCTAssertEqual(detectedGBP, "GBP", "Should detect GBP from text with pound symbol")
        
        // Test JPY detection
        let jpyText = "Total: ¥1500"
        let detectedJPY = currencyService.detectCurrencyFromText(jpyText)
        XCTAssertEqual(detectedJPY, "JPY", "Should detect JPY from text with yen symbol")
        
        // Test currency code detection
        let cadText = "Amount: 45.00 CAD"
        let detectedCAD = currencyService.detectCurrencyFromText(cadText)
        XCTAssertEqual(detectedCAD, "CAD", "Should detect CAD from currency code")
        
        // Test no currency detection
        let noCurrencyText = "Just some random text"
        let detectedNone = currencyService.detectCurrencyFromText(noCurrencyText)
        XCTAssertNil(detectedNone, "Should return nil when no currency is detected")
    }
    
    // MARK: - Currency Conversion Tests
    
    func testConvertAmountSameCurrency() {
        let amount = NSDecimalNumber(string: "100.00")
        let converted = currencyService.convertAmount(amount, from: "USD", to: "USD")
        XCTAssertEqual(converted, amount, "Converting to same currency should return original amount")
    }
    
    func testConvertAmountDifferentCurrencies() {
        let amount = NSDecimalNumber(string: "100.00")
        let converted = currencyService.convertAmount(amount, from: "USD", to: "EUR")
        
        // Since we're using mock rates, we can't test exact values
        // but we can test that conversion happened
        XCTAssertNotEqual(converted, amount, "Converting to different currency should change the amount")
        XCTAssertGreaterThan(converted.doubleValue, 0, "Converted amount should be positive")
    }
    
    func testConvertAmountInvalidCurrency() {
        let amount = NSDecimalNumber(string: "100.00")
        let converted = currencyService.convertAmount(amount, from: "INVALID", to: "USD")
        
        // Should return original amount when currency is invalid
        XCTAssertEqual(converted, amount, "Should return original amount for invalid currency")
    }
    
    // MARK: - Performance Tests
    
    func testCurrencySearchPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = currencyService.searchCurrencies("Dollar")
            }
        }
    }
    
    func testCurrencyFormattingPerformance() {
        let amount = NSDecimalNumber(string: "123.45")
        measure {
            for _ in 0..<1000 {
                _ = currencyService.formatAmount(amount, currencyCode: "USD")
            }
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testFormatZeroAmount() {
        let zeroAmount = NSDecimalNumber.zero
        let formatted = currencyService.formatAmount(zeroAmount, currencyCode: "USD")
        XCTAssertTrue(formatted.contains("0"), "Should format zero amount")
    }
    
    func testFormatNegativeAmount() {
        let negativeAmount = NSDecimalNumber(string: "-50.00")
        let formatted = currencyService.formatAmount(negativeAmount, currencyCode: "USD")
        XCTAssertTrue(formatted.contains("50"), "Should format negative amount")
    }
    
    func testFormatLargeAmount() {
        let largeAmount = NSDecimalNumber(string: "1000000.99")
        let formatted = currencyService.formatAmount(largeAmount, currencyCode: "USD")
        XCTAssertTrue(formatted.contains("1000000") || formatted.contains("1,000,000"), "Should format large amount")
    }
    
    func testDetectCurrencyFromComplexText() {
        let complexText = """
        RECEIPT
        Store Name: Test Store
        Date: 2024-01-15
        
        Item 1: $5.99
        Item 2: $12.50
        Tax: $1.48
        
        Total: $19.97 USD
        Payment: Credit Card
        """
        
        let detected = currencyService.detectCurrencyFromText(complexText)
        XCTAssertEqual(detected, "USD", "Should detect USD from complex receipt text")
    }
}