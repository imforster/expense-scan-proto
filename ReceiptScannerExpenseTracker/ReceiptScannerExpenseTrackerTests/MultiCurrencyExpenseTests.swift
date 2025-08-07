import XCTest
import CoreData
@testable import ReceiptScannerExpenseTracker

final class MultiCurrencyExpenseTests: CoreDataTestCase {
    
    var currencyService: CurrencyService!
    
    override func setUp() {
        super.setUp()
        currencyService = CurrencyService.shared
    }
    
    override func tearDown() {
        currencyService = nil
        super.tearDown()
    }
    
    // MARK: - Expense Currency Tests
    
    func testExpenseCreationWithCurrency() {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "100.00")
        expense.currencyCode = "EUR"
        expense.merchant = "Test Merchant"
        expense.date = Date()
        
        XCTAssertEqual(expense.currencyCode, "EUR", "Expense should have EUR currency code")
        
        let formatted = expense.formattedAmount()
        XCTAssertTrue(formatted.contains("€") || formatted.contains("EUR"), "Formatted amount should contain EUR symbol or code")
    }
    
    func testExpenseDefaultCurrency() {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: "50.00")
        expense.currencyCode = currencyService.getLocalCurrencyCode()
        expense.merchant = "Local Merchant"
        expense.date = Date()
        
        XCTAssertEqual(expense.currencyCode, currencyService.getPreferredCurrencyCode(), "Should use preferred currency by default")
    }
    
    func testExpenseFormattingWithDifferentCurrencies() {
        // Test USD
        let usdExpense = createTestExpense(amount: "25.99", currency: "USD")
        let usdFormatted = usdExpense.formattedAmount()
        XCTAssertTrue(usdFormatted.contains("$"), "USD expense should contain dollar symbol")
        
        // Test EUR
        let eurExpense = createTestExpense(amount: "19.50", currency: "EUR")
        let eurFormatted = eurExpense.formattedAmount()
        XCTAssertTrue(eurFormatted.contains("€"), "EUR expense should contain euro symbol")
        
        // Test GBP
        let gbpExpense = createTestExpense(amount: "15.75", currency: "GBP")
        let gbpFormatted = gbpExpense.formattedAmount()
        XCTAssertTrue(gbpFormatted.contains("£"), "GBP expense should contain pound symbol")
    }
    
    // MARK: - Currency Grouping Tests
    
    func testExpenseGroupingByCurrency() {
        // Create expenses in different currencies
        let expenses = [
            createTestExpense(amount: "100.00", currency: "USD"),
            createTestExpense(amount: "200.00", currency: "USD"),
            createTestExpense(amount: "150.00", currency: "EUR"),
            createTestExpense(amount: "75.00", currency: "GBP")
        ]
        
        let currencySummaries = expenses.groupedByCurrency()
        
        XCTAssertEqual(currencySummaries.count, 3, "Should have 3 different currencies")
        
        // Find USD summary
        let usdSummary = currencySummaries.first { $0.currencyCode == "USD" }
        XCTAssertNotNil(usdSummary, "Should have USD summary")
        XCTAssertEqual(usdSummary?.totalAmount, Decimal(300), "USD total should be 300")
        XCTAssertEqual(usdSummary?.expenseCount, 2, "Should have 2 USD expenses")
        
        // Find EUR summary
        let eurSummary = currencySummaries.first { $0.currencyCode == "EUR" }
        XCTAssertNotNil(eurSummary, "Should have EUR summary")
        XCTAssertEqual(eurSummary?.totalAmount, Decimal(150), "EUR total should be 150")
        XCTAssertEqual(eurSummary?.expenseCount, 1, "Should have 1 EUR expense")
    }
    
    func testPrimaryCurrencyDetection() {
        let expenses = [
            createTestExpense(amount: "50.00", currency: "USD"),
            createTestExpense(amount: "200.00", currency: "EUR"),
            createTestExpense(amount: "100.00", currency: "EUR"),
            createTestExpense(amount: "25.00", currency: "GBP")
        ]
        
        let primaryCurrency = expenses.primaryCurrency()
        XCTAssertEqual(primaryCurrency, "EUR", "EUR should be primary currency (highest total amount)")
    }
    
    func testUniqueCurrencies() {
        let expenses = [
            createTestExpense(amount: "100.00", currency: "USD"),
            createTestExpense(amount: "200.00", currency: "USD"),
            createTestExpense(amount: "150.00", currency: "EUR"),
            createTestExpense(amount: "75.00", currency: "GBP"),
            createTestExpense(amount: "50.00", currency: "EUR")
        ]
        
        let uniqueCurrencies = expenses.uniqueCurrencies()
        XCTAssertEqual(uniqueCurrencies.count, 3, "Should have 3 unique currencies")
        XCTAssertTrue(uniqueCurrencies.contains("USD"), "Should contain USD")
        XCTAssertTrue(uniqueCurrencies.contains("EUR"), "Should contain EUR")
        XCTAssertTrue(uniqueCurrencies.contains("GBP"), "Should contain GBP")
    }
    
    func testTotalAmountInSpecificCurrency() {
        let expenses = [
            createTestExpense(amount: "100.00", currency: "USD"),
            createTestExpense(amount: "200.00", currency: "USD"),
            createTestExpense(amount: "150.00", currency: "EUR"),
            createTestExpense(amount: "75.00", currency: "GBP")
        ]
        
        let usdTotal = expenses.totalAmount(in: "USD")
        XCTAssertEqual(usdTotal, Decimal(300), "USD total should be 300")
        
        let eurTotal = expenses.totalAmount(in: "EUR")
        XCTAssertEqual(eurTotal, Decimal(150), "EUR total should be 150")
        
        let cadTotal = expenses.totalAmount(in: "CAD")
        XCTAssertEqual(cadTotal, Decimal.zero, "CAD total should be zero (no CAD expenses)")
    }
    
    // MARK: - Receipt Currency Tests
    
    func testReceiptCreationWithCurrency() {
        let receipt = Receipt(context: testContext)
        receipt.id = UUID()
        receipt.totalAmount = NSDecimalNumber(string: "45.99")
        receipt.currencyCode = "CAD"
        receipt.merchantName = "Canadian Store"
        receipt.date = Date()
        receipt.dateProcessed = Date()
        receipt.imageURL = URL(fileURLWithPath: "/test/path")
        
        XCTAssertEqual(receipt.currencyCode, "CAD", "Receipt should have CAD currency code")
        
        let formatted = receipt.formattedTotalAmount()
        XCTAssertTrue(formatted.contains("C$") || formatted.contains("CAD"), "Formatted amount should contain CAD symbol or code")
    }
    
    func testReceiptToExpenseCurrencyTransfer() {
        // Create receipt with EUR currency
        let receipt = Receipt(context: testContext)
        receipt.id = UUID()
        receipt.totalAmount = NSDecimalNumber(string: "89.50")
        receipt.currencyCode = "EUR"
        receipt.merchantName = "European Store"
        receipt.date = Date()
        receipt.dateProcessed = Date()
        receipt.imageURL = URL(fileURLWithPath: "/test/path")
        
        // Create expense from receipt
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = receipt.totalAmount
        expense.currencyCode = receipt.currencyCode
        expense.merchant = receipt.merchantName
        expense.date = receipt.date
        expense.receipt = receipt
        
        XCTAssertEqual(expense.currencyCode, "EUR", "Expense should inherit currency from receipt")
        XCTAssertEqual(expense.currencyCode, receipt.currencyCode, "Expense and receipt should have same currency")
    }
    
    // MARK: - Currency Summary Tests
    
    func testCurrencySummaryFormatting() {
        let summary = CurrencySummary(
            currencyCode: "USD",
            totalAmount: Decimal(string: "1234.56")!,
            expenseCount: 5
        )
        
        XCTAssertEqual(summary.currencyCode, "USD")
        XCTAssertEqual(summary.totalAmount, Decimal(string: "1234.56")!)
        XCTAssertEqual(summary.expenseCount, 5)
        XCTAssertNotNil(summary.currencyInfo, "Should have currency info for USD")
        XCTAssertEqual(summary.symbol, "$", "Should have correct symbol")
        
        let formatted = summary.formattedAmount
        XCTAssertTrue(formatted.contains("1234.56") || formatted.contains("1,234.56"), "Should format amount correctly")
    }
    
    func testCurrencySummaryWithUnknownCurrency() {
        let summary = CurrencySummary(
            currencyCode: "XYZ",
            totalAmount: Decimal(100),
            expenseCount: 1
        )
        
        XCTAssertNil(summary.currencyInfo, "Should not have currency info for unknown currency")
        XCTAssertEqual(summary.symbol, "XYZ", "Should fallback to currency code as symbol")
        XCTAssertEqual(summary.displayName, "XYZ", "Should fallback to currency code as display name")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyExpenseArrayCurrencyGrouping() {
        let expenses: [Expense] = []
        let summaries = expenses.groupedByCurrency()
        XCTAssertTrue(summaries.isEmpty, "Empty expense array should return empty summaries")
        
        let primaryCurrency = expenses.primaryCurrency()
        XCTAssertEqual(primaryCurrency, currencyService.getPreferredCurrencyCode(), "Should return preferred currency for empty array")
    }
    
    func testSingleCurrencyGrouping() {
        let expenses = [
            createTestExpense(amount: "100.00", currency: "USD"),
            createTestExpense(amount: "200.00", currency: "USD")
        ]
        
        let summaries = expenses.groupedByCurrency()
        XCTAssertEqual(summaries.count, 1, "Should have only one currency summary")
        XCTAssertEqual(summaries.first?.currencyCode, "USD", "Should be USD")
        XCTAssertEqual(summaries.first?.totalAmount, Decimal(300), "Total should be 300")
    }
    
    // MARK: - Helper Methods
    
    private func createTestExpense(amount: String, currency: String) -> Expense {
        let expense = Expense(context: testContext)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(string: amount)
        expense.currencyCode = currency
        expense.merchant = "Test Merchant"
        expense.date = Date()
        return expense
    }
}