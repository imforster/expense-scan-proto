import Foundation

/// Service for handling currency operations including formatting, detection, and conversion
class CurrencyService {
    static let shared = CurrencyService()
    private init() {}
    // MARK: - Currency Data

    /// Popular currencies with their codes, names, and symbols
    static let popularCurrencies: [CurrencyInfo] = [
        CurrencyInfo(code: "CAD", name: "Canadian Dollar", symbol: "C$"),
        CurrencyInfo(code: "USD", name: "US Dollar", symbol: "$"), CurrencyInfo(code: "EUR", name: "Euro", symbol: "€"),
        CurrencyInfo(code: "GBP", name: "British Pound", symbol: "£"),
        CurrencyInfo(code: "JPY", name: "Japanese Yen", symbol: "¥"),
        CurrencyInfo(code: "AUD", name: "Australian Dollar", symbol: "A$"),
        CurrencyInfo(code: "CHF", name: "Swiss Franc", symbol: "CHF"),
        CurrencyInfo(code: "CNY", name: "Chinese Yuan", symbol: "¥"),
        CurrencyInfo(code: "SEK", name: "Swedish Krona", symbol: "kr"),
        CurrencyInfo(code: "NZD", name: "New Zealand Dollar", symbol: "NZ$"),
        CurrencyInfo(code: "MXN", name: "Mexican Peso", symbol: "$"),
        CurrencyInfo(code: "SGD", name: "Singapore Dollar", symbol: "S$"),
        CurrencyInfo(code: "HKD", name: "Hong Kong Dollar", symbol: "HK$"),
        CurrencyInfo(code: "NOK", name: "Norwegian Krone", symbol: "kr"),
        CurrencyInfo(code: "KRW", name: "South Korean Won", symbol: "₩"),
        CurrencyInfo(code: "TRY", name: "Turkish Lira", symbol: "₺"),
        CurrencyInfo(code: "RUB", name: "Russian Ruble", symbol: "₽"),
        CurrencyInfo(code: "INR", name: "Indian Rupee", symbol: "₹"),
        CurrencyInfo(code: "BRL", name: "Brazilian Real", symbol: "R$"),
        CurrencyInfo(code: "ZAR", name: "South African Rand", symbol: "R")
    ]
    /// Get the local currency code based on the user's locale
    func getLocalCurrencyCode() -> String { return Locale.current.currency?.identifier ?? "CAD" }
    /// Get the user's preferred currency code (from settings or local currency as fallback)
    func getPreferredCurrencyCode() -> String {
        return UserDefaults.standard.string(forKey: "preferredCurrencyCode") ?? getLocalCurrencyCode()
    }
    /// Get currency info for a given currency code
    func getCurrencyInfo(for code: String) -> CurrencyInfo? { return Self.popularCurrencies.first { $0.code == code } }
    /// Get all available currencies sorted alphabetically
    func getAllCurrencies() -> [CurrencyInfo] { return Self.popularCurrencies.sorted { $0.name < $1.name } }
    /// Search currencies by name or code
    func searchCurrencies(_ query: String) -> [CurrencyInfo] {
        guard !query.isEmpty else { return getAllCurrencies() }
        let lowercaseQuery = query.lowercased()
        return Self.popularCurrencies.filter { currency in
            currency.name.lowercased().contains(lowercaseQuery) || currency.code.lowercased().contains(lowercaseQuery)
        }.sorted { $0.name < $1.name }
    }
    // MARK: - Currency Formatting

    /// Format an amount with the specified currency
    func formatAmount(_ amount: NSDecimalNumber, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        // Try to get the currency info for custom symbol handling
        if let currencyInfo = getCurrencyInfo(for: currencyCode) { formatter.currencySymbol = currencyInfo.symbol }
        return formatter.string(from: amount) ?? "\(currencyCode) 0.00"
    }
    /// Format an amount with the local currency
    func formatAmountWithLocalCurrency(_ amount: NSDecimalNumber) -> String {
        return formatAmount(amount, currencyCode: getLocalCurrencyCode())
    }
    // MARK: - Currency Detection

    /// Detect currency from receipt text using common patterns
    func detectCurrencyFromText(_ text: String) -> String? {
        let patterns = [
            // Currency symbols
            ("\\$", "USD"), ("€", "EUR"), ("£", "GBP"), ("¥", "JPY"), ("₩", "KRW"), ("₺", "TRY"), ("₽", "RUB"),
            ("₹", "INR"),
            // Currency codes
            ("\\bUSD\\b", "USD"), ("\\bEUR\\b", "EUR"), ("\\bGBP\\b", "GBP"), ("\\bJPY\\b", "JPY"),
            ("\\bCAD\\b", "CAD"), ("\\bAUD\\b", "AUD"), ("\\bCHF\\b", "CHF"), ("\\bCNY\\b", "CNY"),
            ("\\bSEK\\b", "SEK"), ("\\bNZD\\b", "NZD"), ("\\bMXN\\b", "MXN"), ("\\bSGD\\b", "SGD"),
            ("\\bHKD\\b", "HKD"), ("\\bNOK\\b", "NOK"), ("\\bKRW\\b", "KRW"), ("\\bTRY\\b", "TRY"),
            ("\\bRUB\\b", "RUB"), ("\\bINR\\b", "INR"), ("\\bBRL\\b", "BRL"), ("\\bZAR\\b", "ZAR")
        ]
        for (pattern, currencyCode) in patterns where text.range(of: pattern, options: .regularExpression) != nil {
            return currencyCode
        }
        return nil
    }
    // MARK: - Currency Conversion (Basic Implementation)

    /// Convert amount from one currency to another
    /// Note: This is a basic implementation. In a production app, you would use real exchange rates
    func convertAmount(_ amount: NSDecimalNumber, from fromCurrency: String, to toCurrency: String) -> NSDecimalNumber {
        // If same currency, return original amount
        if fromCurrency == toCurrency { return amount }
        // Basic mock conversion rates (in production, fetch from API)
        let mockRates: [String: Double] = [
            "USD": 1.0, "EUR": 0.85, "GBP": 0.73, "JPY": 110.0, "CAD": 1.25, "AUD": 1.35, "CHF": 0.92, "CNY": 6.45,
            "SEK": 8.5, "NZD": 1.42, "MXN": 20.0, "SGD": 1.35, "HKD": 7.8, "NOK": 8.6, "KRW": 1180.0, "TRY": 8.5,
            "RUB": 75.0, "INR": 74.0, "BRL": 5.2, "ZAR": 14.5
        ]
        guard let fromRate = mockRates[fromCurrency], let toRate = mockRates[toCurrency] else {
            return amount  // Return original if rates not found
        }
        // Convert to USD first, then to target currency
        let usdAmount = amount.doubleValue / fromRate
        let convertedAmount = usdAmount * toRate
        return NSDecimalNumber(value: convertedAmount)
    }
}

// MARK: - Supporting Types

struct CurrencyInfo: Identifiable, Hashable {
    let id = UUID()
    let code: String
    let name: String
    let symbol: String
    var displayName: String { return "\(name) (\(code))" }
}
