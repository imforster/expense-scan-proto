import Foundation
import SwiftUI
import Combine

// MARK: - ExpenseListViewModel Summary Extension

extension ExpenseListViewModel {
    
    /// Published property for summary data
    var summaryData: [SummaryData] {
        return SpendingAnalyticsService.generateSummaryData(from: displayedExpenses)
    }
    
    /// Calculates and updates summary data based on current expenses
    func updateSummaryData() {
        // Summary data is now computed automatically via the computed property
        // This method is kept for backward compatibility but doesn't need to do anything
    }
    
    /// Gets current month total spending
    var currentMonthTotal: Decimal {
        let expenses = Array(displayedExpenses)
        return SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
    }
    
    /// Gets previous month total spending for comparison
    var previousMonthTotal: Decimal {
        let expenses = Array(displayedExpenses)
        return SpendingAnalyticsService.calculatePreviousMonthTotal(from: expenses)
    }
    
    /// Gets current week total spending
    var currentWeekTotal: Decimal {
        let expenses = Array(displayedExpenses)
        return SpendingAnalyticsService.calculateCurrentWeekTotal(from: expenses)
    }
    
    /// Gets average daily spending for current month
    var averageDailySpending: Decimal {
        let expenses = Array(displayedExpenses)
        return SpendingAnalyticsService.calculateAverageDailySpending(from: expenses)
    }
    
    /// Refreshes summary data when expenses change
    func setupSummaryDataObserver() {
        // This should be called in the main init method of ExpenseListViewModel
        $displayedExpenses
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expenses in
                self?.updateSummaryData()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Summary Data Helpers

extension ExpenseListViewModel {
    
    /// Creates a basic summary data structure for testing
    static func createBasicSummaryData(
        title: String,
        amount: Decimal,
        previousAmount: Decimal? = nil
    ) -> SummaryData {
        let trend = previousAmount.map { prev in
            TrendData(previousAmount: prev, currentAmount: amount)
        }
        
        return SummaryData(
            title: title,
            amount: amount,
            trend: trend
        )
    }
    
    /// Validates summary data calculations
    func validateSummaryCalculations() -> Bool {
        let expenses = Array(displayedExpenses)
        let generatedSummary = SpendingAnalyticsService.generateSummaryData(from: expenses)
        
        // Verify that generated summary matches expected calculations
        let expectedCurrentMonth = SpendingAnalyticsService.calculateCurrentMonthTotal(from: expenses)
        let currentMonthSummary = generatedSummary.first { $0.title == "This Month" }
        
        return currentMonthSummary?.amount == expectedCurrentMonth
    }
}