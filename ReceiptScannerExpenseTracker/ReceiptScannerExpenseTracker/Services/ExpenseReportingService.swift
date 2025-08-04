import Foundation
import CoreData
import Combine
import os.log

// MARK: - Reporting Data Models

/// Time period for reporting
enum TimePeriod: Equatable {
    case week
    case month
    case quarter
    case year
    case custom(DateInterval)
    
    /// Static cases for common periods (excluding custom)
    static let commonCases: [TimePeriod] = [.week, .month, .quarter, .year]
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        case .custom: return "Custom"
        }
    }
    
    /// Gets the date interval for the current period
    func dateInterval(for date: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 604800) // 7 days
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 2592000) // 30 days
        case .quarter:
            return calendar.dateInterval(of: .quarter, for: date) ?? DateInterval(start: date, duration: 7776000) // 90 days
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, duration: 31536000) // 365 days
        case .custom(let interval):
            return interval
        }
    }
    
    /// Gets the previous period's date interval
    func previousPeriodInterval(for date: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        let currentInterval = dateInterval(for: date)
        
        switch self {
        case .week:
            let previousWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentInterval.start) ?? currentInterval.start
            return calendar.dateInterval(of: .weekOfYear, for: previousWeekStart) ?? currentInterval
        case .month:
            let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) ?? currentInterval.start
            return calendar.dateInterval(of: .month, for: previousMonthStart) ?? currentInterval
        case .quarter:
            let previousQuarterStart = calendar.date(byAdding: .month, value: -3, to: currentInterval.start) ?? currentInterval.start
            return calendar.dateInterval(of: .quarter, for: previousQuarterStart) ?? currentInterval
        case .year:
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentInterval.start) ?? currentInterval.start
            return calendar.dateInterval(of: .year, for: previousYearStart) ?? currentInterval
        case .custom(let interval):
            let duration = interval.duration
            let previousStart = Date(timeInterval: -duration, since: interval.start)
            return DateInterval(start: previousStart, duration: duration)
        }
    }
}

/// Spending summary for a specific period
struct SpendingSummary {
    let period: TimePeriod
    let dateInterval: DateInterval
    let totalAmount: Decimal
    let transactionCount: Int
    let averageTransaction: Decimal
    let categoryBreakdown: [CategorySpending]
    let vendorBreakdown: [VendorSpending]
    let dailySpending: [DailySpending]
    
    var formattedTotalAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: totalAmount)) ?? "$0.00"
    }
    
    var formattedAverageTransaction: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: averageTransaction)) ?? "$0.00"
    }
}

/// Category spending breakdown
struct CategorySpending {
    let category: CategoryData
    let amount: Decimal
    let percentage: Double
    let transactionCount: Int
    let averageAmount: Decimal
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    var formattedPercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: percentage)) ?? "0%"
    }
}

/// Vendor spending breakdown
struct VendorSpending {
    let vendorName: String
    let amount: Decimal
    let transactionCount: Int
    let averageAmount: Decimal
    let lastTransactionDate: Date
    let categoryDistribution: [CategorySpending]
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
    
    var formattedLastTransaction: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: lastTransactionDate)
    }
}

/// Daily spending data for trend analysis
struct DailySpending {
    let date: Date
    let amount: Decimal
    let transactionCount: Int
    
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "$0.00"
    }
}

/// Spending trends analysis
struct SpendingTrends {
    let period: TimePeriod
    let currentPeriodSummary: SpendingSummary
    let previousPeriodSummary: SpendingSummary
    let changeAmount: Decimal
    let changePercentage: Double
    let trendDirection: TrendDirection
    let categoryTrends: [CategoryTrend]
    let spendingPattern: SpendingPattern
    
    var formattedChangeAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.positivePrefix = "+"
        return formatter.string(from: NSDecimalNumber(decimal: changeAmount)) ?? "$0.00"
    }
    
    var formattedChangePercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: changePercentage)) ?? "0%"
    }
}

/// Category-specific trend analysis
struct CategoryTrend {
    let category: CategoryData
    let currentAmount: Decimal
    let previousAmount: Decimal
    let changeAmount: Decimal
    let changePercentage: Double
    let trendDirection: TrendDirection
}

/// Spending pattern analysis
struct SpendingPattern {
    let averageDailySpending: Decimal
    let peakSpendingDay: Date?
    let peakSpendingAmount: Decimal
    let consistencyScore: Double // 0-1, higher means more consistent spending
    let seasonalityIndicator: SeasonalityIndicator
}

/// Trend direction enumeration for reporting
enum ReportingTrendDirection {
    case increasing
    case decreasing
    case stable
    
    var displayName: String {
        switch self {
        case .increasing: return "Increasing"
        case .decreasing: return "Decreasing"
        case .stable: return "Stable"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
}

/// Seasonality indicator for spending patterns
enum SeasonalityIndicator {
    case weekdayHeavy
    case weekendHeavy
    case monthStartHeavy
    case monthEndHeavy
    case balanced
    
    var displayName: String {
        switch self {
        case .weekdayHeavy: return "Higher weekday spending"
        case .weekendHeavy: return "Higher weekend spending"
        case .monthStartHeavy: return "Higher early-month spending"
        case .monthEndHeavy: return "Higher late-month spending"
        case .balanced: return "Balanced spending pattern"
        }
    }
}

/// Time period comparison result
struct PeriodComparison {
    let currentPeriod: SpendingSummary
    let previousPeriod: SpendingSummary
    let changeAmount: Decimal
    let changePercentage: Double
    let significantChanges: [CategoryChange]
    
    var formattedChangeAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.positivePrefix = "+"
        return formatter.string(from: NSDecimalNumber(decimal: changeAmount)) ?? "$0.00"
    }
    
    var formattedChangePercentage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        return formatter.string(from: NSNumber(value: changePercentage)) ?? "0%"
    }
}

/// Category change analysis
struct CategoryChange {
    let category: CategoryData
    let currentAmount: Decimal
    let previousAmount: Decimal
    let changeAmount: Decimal
    let changePercentage: Double
    let isSignificant: Bool // Change > 20% or > $100
    
    var formattedChangeAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.positivePrefix = "+"
        return formatter.string(from: NSDecimalNumber(decimal: changeAmount)) ?? "$0.00"
    }
}

// MARK: - Expense Reporting Service Protocol

protocol ExpenseReportingServiceProtocol {
    func getSpendingSummary(for period: TimePeriod, date: Date) async throws -> SpendingSummary
    func getCategorySpendingAnalysis(for period: TimePeriod, date: Date) async throws -> [CategorySpending]
    func getVendorSpendingAnalysis(for period: TimePeriod, date: Date) async throws -> [VendorSpending]
    func getSpendingTrends(for period: TimePeriod, date: Date) async throws -> SpendingTrends
    func comparePeriods(period: TimePeriod, currentDate: Date) async throws -> PeriodComparison
    func getDailySpendingData(for period: TimePeriod, date: Date) async throws -> [DailySpending]
}

// MARK: - Expense Reporting Service Implementation

@MainActor
class ExpenseReportingService: ObservableObject, ExpenseReportingServiceProtocol {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var error: ExpenseError?
    
    // MARK: - Private Properties
    private let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.receiptscanner.expensetracker", category: "ExpenseReportingService")
    private var reportCache: [String: Any] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes
    
    // MARK: - Initialization
    init(context: NSManagedObjectContext = CoreDataManager.shared.viewContext) {
        self.context = context
    }
    
    // MARK: - Public Methods
    
    /// Gets comprehensive spending summary for a specific period
    func getSpendingSummary(for period: TimePeriod, date: Date = Date()) async throws -> SpendingSummary {
        logger.info("Generating spending summary for period: \(period.displayName)")
        
        let cacheKey = "summary_\(period.displayName)_\(date.timeIntervalSince1970)"
        if let cachedSummary = getCachedResult(for: cacheKey) as? SpendingSummary {
            logger.info("Returning cached spending summary")
            return cachedSummary
        }
        
        isLoading = true
        error = nil
        
        do {
            let dateInterval = period.dateInterval(for: date)
            let expenses = try await fetchExpenses(for: dateInterval)
            
            let totalAmount = expenses.reduce(Decimal.zero) { $0 + $1.amount.decimalValue }
            let transactionCount = expenses.count
            let averageTransaction = transactionCount > 0 ? totalAmount / Decimal(transactionCount) : Decimal.zero
            
            let categoryBreakdown = try await calculateCategoryBreakdown(expenses: expenses, totalAmount: totalAmount)
            let vendorBreakdown = try await calculateVendorBreakdown(expenses: expenses)
            let dailySpending = try await calculateDailySpending(expenses: expenses, dateInterval: dateInterval)
            
            let summary = SpendingSummary(
                period: period,
                dateInterval: dateInterval,
                totalAmount: totalAmount,
                transactionCount: transactionCount,
                averageTransaction: averageTransaction,
                categoryBreakdown: categoryBreakdown,
                vendorBreakdown: vendorBreakdown,
                dailySpending: dailySpending
            )
            
            cacheResult(summary, for: cacheKey)
            isLoading = false
            
            logger.info("Generated spending summary: \(summary.formattedTotalAmount) across \(transactionCount) transactions")
            return summary
            
        } catch {
            isLoading = false
            self.error = ExpenseErrorFactory.fromCoreDataError(error)
            logger.error("Failed to generate spending summary: \(error.localizedDescription)")
            throw self.error!
        }
    }
    
    /// Gets detailed category spending analysis
    func getCategorySpendingAnalysis(for period: TimePeriod, date: Date = Date()) async throws -> [CategorySpending] {
        logger.info("Generating category spending analysis for period: \(period.displayName)")
        
        let summary = try await getSpendingSummary(for: period, date: date)
        return summary.categoryBreakdown
    }
    
    /// Gets detailed vendor spending analysis
    func getVendorSpendingAnalysis(for period: TimePeriod, date: Date = Date()) async throws -> [VendorSpending] {
        logger.info("Generating vendor spending analysis for period: \(period.displayName)")
        
        let summary = try await getSpendingSummary(for: period, date: date)
        return summary.vendorBreakdown
    }
    
    /// Analyzes spending trends and patterns
    func getSpendingTrends(for period: TimePeriod, date: Date = Date()) async throws -> SpendingTrends {
        logger.info("Analyzing spending trends for period: \(period.displayName)")
        
        let cacheKey = "trends_\(period.displayName)_\(date.timeIntervalSince1970)"
        if let cachedTrends = getCachedResult(for: cacheKey) as? SpendingTrends {
            logger.info("Returning cached spending trends")
            return cachedTrends
        }
        
        isLoading = true
        error = nil
        
        do {
            let currentSummary = try await getSpendingSummary(for: period, date: date)
            let previousInterval = period.previousPeriodInterval(for: date)
            let previousSummary = try await getSpendingSummary(for: .custom(previousInterval), date: previousInterval.start)
            
            let changeAmount = currentSummary.totalAmount - previousSummary.totalAmount
            let changePercentage = previousSummary.totalAmount > 0 ? 
                Double(truncating: (changeAmount / previousSummary.totalAmount) as NSNumber) : 0.0
            
            let trendDirection = determineTrendDirection(changePercentage: changePercentage)
            let categoryTrends = calculateCategoryTrends(current: currentSummary, previous: previousSummary)
            let spendingPattern = try await analyzeSpendingPattern(for: period, date: date)
            
            let trends = SpendingTrends(
                period: period,
                currentPeriodSummary: currentSummary,
                previousPeriodSummary: previousSummary,
                changeAmount: changeAmount,
                changePercentage: changePercentage,
                trendDirection: trendDirection,
                categoryTrends: categoryTrends,
                spendingPattern: spendingPattern
            )
            
            cacheResult(trends, for: cacheKey)
            isLoading = false
            
            logger.info("Generated spending trends: \(trends.formattedChangeAmount) (\(trends.formattedChangePercentage)) - \(trendDirection.displayName)")
            return trends
            
        } catch {
            isLoading = false
            self.error = ExpenseErrorFactory.fromCoreDataError(error)
            logger.error("Failed to analyze spending trends: \(error.localizedDescription)")
            throw self.error!
        }
    }
    
    /// Compares current period with previous period
    func comparePeriods(period: TimePeriod, currentDate: Date = Date()) async throws -> PeriodComparison {
        logger.info("Comparing periods for: \(period.displayName)")
        
        let currentSummary = try await getSpendingSummary(for: period, date: currentDate)
        let previousInterval = period.previousPeriodInterval(for: currentDate)
        let previousSummary = try await getSpendingSummary(for: .custom(previousInterval), date: previousInterval.start)
        
        let changeAmount = currentSummary.totalAmount - previousSummary.totalAmount
        let changePercentage = previousSummary.totalAmount > 0 ? 
            Double(truncating: (changeAmount / previousSummary.totalAmount) as NSNumber) : 0.0
        
        let significantChanges = calculateSignificantCategoryChanges(current: currentSummary, previous: previousSummary)
        
        let comparison = PeriodComparison(
            currentPeriod: currentSummary,
            previousPeriod: previousSummary,
            changeAmount: changeAmount,
            changePercentage: changePercentage,
            significantChanges: significantChanges
        )
        
        logger.info("Period comparison: \(comparison.formattedChangeAmount) (\(comparison.formattedChangePercentage))")
        return comparison
    }
    
    /// Gets daily spending data for trend visualization
    func getDailySpendingData(for period: TimePeriod, date: Date = Date()) async throws -> [DailySpending] {
        logger.info("Getting daily spending data for period: \(period.displayName)")
        
        let summary = try await getSpendingSummary(for: period, date: date)
        return summary.dailySpending
    }
    
    // MARK: - Private Helper Methods
    
    /// Fetches expenses for a specific date interval
    private func fetchExpenses(for dateInterval: DateInterval) async throws -> [Expense] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let fetchRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "date >= %@ AND date <= %@",
                    dateInterval.start as NSDate,
                    dateInterval.end as NSDate
                )
                fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: true)]
                
                do {
                    let expenses = try self.context.fetch(fetchRequest)
                    continuation.resume(returning: expenses)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Calculates category spending breakdown
    private func calculateCategoryBreakdown(expenses: [Expense], totalAmount: Decimal) async throws -> [CategorySpending] {
        return calculateCategoryBreakdownSync(expenses: expenses, totalAmount: totalAmount)
    }
    
    /// Synchronous version of category breakdown calculation
    private func calculateCategoryBreakdownSync(expenses: [Expense], totalAmount: Decimal) -> [CategorySpending] {
        var categoryTotals: [UUID: (category: CategoryData, amount: Decimal, count: Int)] = [:]
        
        for expense in expenses {
            if let category = expense.category {
                let categoryData = CategoryData(from: category)
                let existing = categoryTotals[category.id] ?? (categoryData, Decimal.zero, 0)
                categoryTotals[category.id] = (existing.category, existing.amount + expense.amount.decimalValue, existing.count + 1)
            }
        }
        
        return categoryTotals.values.map { (categoryData, amount, count) in
            let percentage = totalAmount > 0 ? Double(truncating: (amount / totalAmount) as NSNumber) : 0.0
            let averageAmount = count > 0 ? amount / Decimal(count) : Decimal.zero
            
            return CategorySpending(
                category: categoryData,
                amount: amount,
                percentage: percentage,
                transactionCount: count,
                averageAmount: averageAmount
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    /// Calculates vendor spending breakdown
    private func calculateVendorBreakdown(expenses: [Expense]) async throws -> [VendorSpending] {
        var vendorTotals: [String: (amount: Decimal, count: Int, lastDate: Date, expenses: [Expense])] = [:]
        
        for expense in expenses {
            let vendor = expense.merchant
            let existing = vendorTotals[vendor] ?? (Decimal.zero, 0, expense.date, [])
            let newLastDate = max(existing.lastDate, expense.date)
            var newExpenses = existing.expenses
            newExpenses.append(expense)
            
            vendorTotals[vendor] = (existing.amount + expense.amount.decimalValue, existing.count + 1, newLastDate, newExpenses)
        }
        
        return vendorTotals.map { (vendor, data) in
            let averageAmount = data.count > 0 ? data.amount / Decimal(data.count) : Decimal.zero
            let categoryDistribution = calculateCategoryBreakdownSync(expenses: data.expenses, totalAmount: data.amount)
            
            return VendorSpending(
                vendorName: vendor,
                amount: data.amount,
                transactionCount: data.count,
                averageAmount: averageAmount,
                lastTransactionDate: data.lastDate,
                categoryDistribution: categoryDistribution
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    /// Calculates daily spending data
    private func calculateDailySpending(expenses: [Expense], dateInterval: DateInterval) async throws -> [DailySpending] {
        let calendar = Calendar.current
        var dailyTotals: [Date: (amount: Decimal, count: Int)] = [:]
        
        // Initialize all days in the interval with zero
        var currentDate = calendar.startOfDay(for: dateInterval.start)
        let endDate = calendar.startOfDay(for: dateInterval.end)
        
        while currentDate <= endDate {
            dailyTotals[currentDate] = (Decimal.zero, 0)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add actual spending data
        for expense in expenses {
            let dayStart = calendar.startOfDay(for: expense.date)
            let existing = dailyTotals[dayStart] ?? (Decimal.zero, 0)
            dailyTotals[dayStart] = (existing.amount + expense.amount.decimalValue, existing.count + 1)
        }
        
        return dailyTotals.map { (date, data) in
            DailySpending(date: date, amount: data.amount, transactionCount: data.count)
        }.sorted { $0.date < $1.date }
    }
    
    /// Determines trend direction based on percentage change
    private func determineTrendDirection(changePercentage: Double) -> TrendDirection {
        if changePercentage > 0.05 { // > 5% increase
            return .increasing
        } else if changePercentage < -0.05 { // > 5% decrease
            return .decreasing
        } else {
            return .stable
        }
    }
    
    /// Calculates category-specific trends
    private func calculateCategoryTrends(current: SpendingSummary, previous: SpendingSummary) -> [CategoryTrend] {
        var trends: [CategoryTrend] = []
        
        // Create lookup for previous period categories
        let previousCategories = Dictionary(uniqueKeysWithValues: previous.categoryBreakdown.map { ($0.category.id, $0) })
        
        for currentCategory in current.categoryBreakdown {
            let previousAmount = previousCategories[currentCategory.category.id]?.amount ?? Decimal.zero
            let changeAmount = currentCategory.amount - previousAmount
            let changePercentage = previousAmount > 0 ? 
                Double(truncating: (changeAmount / previousAmount) as NSNumber) : 0.0
            
            let trend = CategoryTrend(
                category: currentCategory.category,
                currentAmount: currentCategory.amount,
                previousAmount: previousAmount,
                changeAmount: changeAmount,
                changePercentage: changePercentage,
                trendDirection: determineTrendDirection(changePercentage: changePercentage)
            )
            
            trends.append(trend)
        }
        
        return trends.sorted { abs($0.changePercentage) > abs($1.changePercentage) }
    }
    
    /// Analyzes spending patterns for insights
    private func analyzeSpendingPattern(for period: TimePeriod, date: Date) async throws -> SpendingPattern {
        let dailyData = try await getDailySpendingData(for: period, date: date)
        
        let totalAmount = dailyData.reduce(Decimal.zero) { $0 + $1.amount }
        let daysWithSpending = dailyData.filter { $0.amount > 0 }.count
        let averageDailySpending = daysWithSpending > 0 ? totalAmount / Decimal(daysWithSpending) : Decimal.zero
        
        let peakDay = dailyData.max { $0.amount < $1.amount }
        let peakSpendingDay = peakDay?.date
        let peakSpendingAmount = peakDay?.amount ?? Decimal.zero
        
        // Calculate consistency score (lower standard deviation = higher consistency)
        let amounts = dailyData.map { Double(truncating: $0.amount as NSNumber) }
        let mean = amounts.reduce(0, +) / Double(amounts.count)
        let variance = amounts.map { pow($0 - mean, 2) }.reduce(0, +) / Double(amounts.count)
        let standardDeviation = sqrt(variance)
        let consistencyScore = mean > 0 ? max(0, 1 - (standardDeviation / mean)) : 0
        
        // Determine seasonality
        let seasonality = determineSeasonality(dailyData: dailyData)
        
        return SpendingPattern(
            averageDailySpending: averageDailySpending,
            peakSpendingDay: peakSpendingDay,
            peakSpendingAmount: peakSpendingAmount,
            consistencyScore: consistencyScore,
            seasonalityIndicator: seasonality
        )
    }
    
    /// Determines spending seasonality patterns
    private func determineSeasonality(dailyData: [DailySpending]) -> SeasonalityIndicator {
        let calendar = Calendar.current
        
        var weekdayTotal = Decimal.zero
        var weekendTotal = Decimal.zero
        var monthStartTotal = Decimal.zero // Days 1-10
        var monthEndTotal = Decimal.zero   // Days 21-31
        
        for dayData in dailyData {
            let weekday = calendar.component(.weekday, from: dayData.date)
            let dayOfMonth = calendar.component(.day, from: dayData.date)
            
            // Weekend vs weekday
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                weekendTotal += dayData.amount
            } else {
                weekdayTotal += dayData.amount
            }
            
            // Month start vs end
            if dayOfMonth <= 10 {
                monthStartTotal += dayData.amount
            } else if dayOfMonth >= 21 {
                monthEndTotal += dayData.amount
            }
        }
        
        let totalSpending = weekdayTotal + weekendTotal
        
        if totalSpending > 0 {
            let weekendPercentage = Double(truncating: (weekendTotal / totalSpending) as NSNumber)
            let monthStartPercentage = Double(truncating: (monthStartTotal / totalSpending) as NSNumber)
            let monthEndPercentage = Double(truncating: (monthEndTotal / totalSpending) as NSNumber)
            
            if weekendPercentage > 0.4 { // More than 40% on weekends (expected ~28.6%)
                return .weekendHeavy
            } else if weekendPercentage < 0.2 { // Less than 20% on weekends
                return .weekdayHeavy
            } else if monthStartPercentage > 0.4 {
                return .monthStartHeavy
            } else if monthEndPercentage > 0.4 {
                return .monthEndHeavy
            }
        }
        
        return .balanced
    }
    
    /// Calculates significant category changes between periods
    private func calculateSignificantCategoryChanges(current: SpendingSummary, previous: SpendingSummary) -> [CategoryChange] {
        var changes: [CategoryChange] = []
        let previousCategories = Dictionary(uniqueKeysWithValues: previous.categoryBreakdown.map { ($0.category.id, $0) })
        
        for currentCategory in current.categoryBreakdown {
            let previousAmount = previousCategories[currentCategory.category.id]?.amount ?? Decimal.zero
            let changeAmount = currentCategory.amount - previousAmount
            let changePercentage = previousAmount > 0 ? 
                Double(truncating: (changeAmount / previousAmount) as NSNumber) : 0.0
            
            // Consider significant if change > 20% or > $100
            let isSignificant = abs(changePercentage) > 0.2 || abs(changeAmount) > 100
            
            if isSignificant {
                let change = CategoryChange(
                    category: currentCategory.category,
                    currentAmount: currentCategory.amount,
                    previousAmount: previousAmount,
                    changeAmount: changeAmount,
                    changePercentage: changePercentage,
                    isSignificant: isSignificant
                )
                changes.append(change)
            }
        }
        
        return changes.sorted { abs($0.changePercentage) > abs($1.changePercentage) }
    }
    
    // MARK: - Caching Methods
    
    private func getCachedResult(for key: String) -> Any? {
        return reportCache[key]
    }
    
    private func cacheResult(_ result: Any, for key: String) {
        reportCache[key] = result
        
        // Clean up old cache entries
        if reportCache.count > 20 {
            let keysToRemove = Array(reportCache.keys.prefix(5))
            for key in keysToRemove {
                reportCache.removeValue(forKey: key)
            }
        }
    }
    
    /// Clears the report cache
    func clearCache() {
        reportCache.removeAll()
        logger.info("Report cache cleared")
    }
}