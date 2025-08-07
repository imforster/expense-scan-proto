import Foundation

/// Represents spending summary grouped by currency
struct CurrencySummary {
    let currencyCode: String
    let totalAmount: Decimal
    let expenseCount: Int
    let currencyInfo: CurrencyInfo?
    init(currencyCode: String, totalAmount: Decimal, expenseCount: Int) {
        self.currencyCode = currencyCode
        self.totalAmount = totalAmount
        self.expenseCount = expenseCount
        self.currencyInfo = CurrencyService.shared.getCurrencyInfo(for: currencyCode)
    }
    /// Formatted amount with currency symbol
    var formattedAmount: String {
        return CurrencyService.shared.formatAmount(NSDecimalNumber(decimal: totalAmount), currencyCode: currencyCode)
    }
    /// Display name for the currency
    var displayName: String { return currencyInfo?.displayName ?? currencyCode }
    /// Currency symbol
    var symbol: String { return currencyInfo?.symbol ?? currencyCode }
}

/// Extension to group expenses by currency
extension Array where Element == Expense {
    /// Groups expenses by currency and returns summary data
    func groupedByCurrency() -> [CurrencySummary] {
        let grouped = Dictionary(grouping: self) { expense in expense.currencyCode }
        return grouped.map { (currencyCode, expenses) in
            let totalAmount = expenses.reduce(Decimal.zero) { total, expense in total + expense.amount.decimalValue }
            return CurrencySummary(currencyCode: currencyCode, totalAmount: totalAmount, expenseCount: expenses.count)
        }.sorted { $0.totalAmount > $1.totalAmount }  // Sort by amount descending
    }
    /// Gets the primary currency (most used currency by amount)
    func primaryCurrency() -> String {
        let currencySummaries = groupedByCurrency()
        return currencySummaries.first?.currencyCode ?? CurrencyService.shared.getPreferredCurrencyCode()
    }
    /// Gets total amount in a specific currency
    func totalAmount(in currencyCode: String) -> Decimal {
        return self.filter { $0.currencyCode == currencyCode }.reduce(Decimal.zero) { total, expense in
            total + expense.amount.decimalValue
        }
    }
    /// Gets all unique currencies used in the expenses
    func uniqueCurrencies() -> [String] {
        var uniqueCodes = Set<String>()
        for expense in self { uniqueCodes.insert(expense.currencyCode) }
        return uniqueCodes.sorted()
    }
}
