import XCTest
@testable import ReceiptScannerExpenseTracker

final class SummaryDataTests: XCTestCase {
    
    // MARK: - SummaryData Initialization Tests
    
    func testSummaryDataInitialization() {
        // Given
        let title = "Test Summary"
        let amount = Decimal(150.50)
        
        // When
        let summaryData = SummaryData(title: title, amount: amount)
        
        // Then
        XCTAssertEqual(summaryData.title, title)
        XCTAssertEqual(summaryData.amount, amount)
        XCTAssertNil(summaryData.trend)
        XCTAssertNotNil(summaryData.id)
    }
    
    func testSummaryDataInitializationWithTrend() {
        // Given
        let title = "Test Summary with Trend"
        let amount = Decimal(200.00)
        let previousAmount = Decimal(150.00)
        let trend = TrendData(previousAmount: previousAmount, currentAmount: amount)
        
        // When
        let summaryData = SummaryData(title: title, amount: amount, trend: trend)
        
        // Then
        XCTAssertEqual(summaryData.title, title)
        XCTAssertEqual(summaryData.amount, amount)
        XCTAssertNotNil(summaryData.trend)
        XCTAssertEqual(summaryData.trend?.previousAmount, previousAmount)
        XCTAssertEqual(summaryData.trend?.changeAmount, amount - previousAmount)
    }
    
    func testSummaryDataEquality() {
        // Given
        let summaryData1 = SummaryData(title: "Test", amount: Decimal(100))
        let summaryData2 = SummaryData(title: "Test", amount: Decimal(100))
        
        // Then
        XCTAssertNotEqual(summaryData1, summaryData2) // Different IDs
        XCTAssertEqual(summaryData1, summaryData1) // Same instance
    }
    
    // MARK: - TrendData Tests
    
    func testTrendDataIncreasingTrend() {
        // Given
        let previousAmount = Decimal(100.00)
        let currentAmount = Decimal(150.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.previousAmount, previousAmount)
        XCTAssertEqual(trendData.changeAmount, Decimal(50.00))
        XCTAssertEqual(trendData.changePercentage, 0.5, accuracy: 0.001)
        XCTAssertEqual(trendData.direction, .increasing)
        XCTAssertTrue(trendData.isSignificant) // 50% change is significant
    }
    
    func testTrendDataDecreasingTrend() {
        // Given
        let previousAmount = Decimal(200.00)
        let currentAmount = Decimal(150.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.previousAmount, previousAmount)
        XCTAssertEqual(trendData.changeAmount, Decimal(-50.00))
        XCTAssertEqual(trendData.changePercentage, -0.25, accuracy: 0.001)
        XCTAssertEqual(trendData.direction, .decreasing)
        XCTAssertTrue(trendData.isSignificant) // 25% change is significant
    }
    
    func testTrendDataStableTrend() {
        // Given
        let previousAmount = Decimal(100.00)
        let currentAmount = Decimal(100.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.previousAmount, previousAmount)
        XCTAssertEqual(trendData.changeAmount, Decimal(0.00))
        XCTAssertEqual(trendData.changePercentage, 0.0, accuracy: 0.001)
        XCTAssertEqual(trendData.direction, .stable)
        XCTAssertFalse(trendData.isSignificant)
    }
    
    func testTrendDataZeroPreviousAmount() {
        // Given
        let previousAmount = Decimal(0.00)
        let currentAmount = Decimal(100.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.previousAmount, previousAmount)
        XCTAssertEqual(trendData.changeAmount, Decimal(100.00))
        XCTAssertEqual(trendData.changePercentage, 1.0, accuracy: 0.001) // 100% increase from zero
        XCTAssertEqual(trendData.direction, .increasing)
        XCTAssertTrue(trendData.isSignificant)
    }
    
    func testTrendDataSmallChange() {
        // Given
        let previousAmount = Decimal(100.00)
        let currentAmount = Decimal(105.00) // 5% increase
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changePercentage, 0.05, accuracy: 0.001)
        XCTAssertEqual(trendData.direction, .increasing)
        XCTAssertFalse(trendData.isSignificant) // 5% change is not significant
    }
    
    // MARK: - TrendDirection Tests
    
    func testTrendDirectionDisplayNames() {
        XCTAssertEqual(TrendDirection.increasing.displayName, "Increasing")
        XCTAssertEqual(TrendDirection.decreasing.displayName, "Decreasing")
        XCTAssertEqual(TrendDirection.stable.displayName, "Stable")
    }
    
    func testTrendDirectionColors() {
        XCTAssertEqual(TrendDirection.increasing.color, .red)
        XCTAssertEqual(TrendDirection.decreasing.color, .green)
        XCTAssertEqual(TrendDirection.stable.color, .blue)
    }
    
    func testTrendDirectionIcons() {
        XCTAssertEqual(TrendDirection.increasing.iconName, "arrow.up.right")
        XCTAssertEqual(TrendDirection.decreasing.iconName, "arrow.down.right")
        XCTAssertEqual(TrendDirection.stable.iconName, "arrow.right")
    }
    
    // MARK: - SummaryData Extensions Tests
    
    func testSummaryDataFormattedAmount() {
        // Given
        let summaryData = SummaryData(title: "Test", amount: Decimal(123.45))
        
        // When
        let formattedAmount = summaryData.formattedAmount
        
        // Then
        XCTAssertTrue(formattedAmount.contains("$123"))
        XCTAssertFalse(formattedAmount.contains(".45")) // Should not show cents
    }
    
    func testSummaryDataFormattedTrendWithTrend() {
        // Given
        let trend = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(120))
        let summaryData = SummaryData(title: "Test", amount: Decimal(120), trend: trend)
        
        // When
        let formattedTrend = summaryData.formattedTrend
        
        // Then
        XCTAssertNotNil(formattedTrend)
        XCTAssertTrue(formattedTrend!.contains("%"))
        XCTAssertTrue(formattedTrend!.contains("vs last month"))
    }
    
    func testSummaryDataFormattedTrendWithoutTrend() {
        // Given
        let summaryData = SummaryData(title: "Test", amount: Decimal(120))
        
        // When
        let formattedTrend = summaryData.formattedTrend
        
        // Then
        XCTAssertNil(formattedTrend)
    }
    
    // MARK: - TrendData Extensions Tests
    
    func testTrendDataFormattedChangeAmountPositive() {
        // Given
        let trendData = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(150))
        
        // When
        let formattedChange = trendData.formattedChangeAmount
        
        // Then
        XCTAssertTrue(formattedChange.contains("+"))
        XCTAssertTrue(formattedChange.contains("$50"))
    }
    
    func testTrendDataFormattedChangeAmountNegative() {
        // Given
        let trendData = TrendData(previousAmount: Decimal(150), currentAmount: Decimal(100))
        
        // When
        let formattedChange = trendData.formattedChangeAmount
        
        // Then
        XCTAssertTrue(formattedChange.contains("-"))
        XCTAssertTrue(formattedChange.contains("$50"))
    }
    
    // MARK: - Edge Cases Tests
    
    func testSummaryDataWithZeroAmount() {
        // Given
        let summaryData = SummaryData(title: "Zero Amount", amount: Decimal(0))
        
        // When & Then
        XCTAssertEqual(summaryData.amount, Decimal(0))
        XCTAssertTrue(summaryData.formattedAmount.contains("$0"))
    }
    
    func testSummaryDataWithNegativeAmount() {
        // Given
        let summaryData = SummaryData(title: "Negative Amount", amount: Decimal(-50))
        
        // When & Then
        XCTAssertEqual(summaryData.amount, Decimal(-50))
        XCTAssertTrue(summaryData.formattedAmount.contains("-"))
    }
    
    func testTrendDataWithVerySmallChange() {
        // Given - Change less than 0.01
        let previousAmount = Decimal(100.00)
        let currentAmount = Decimal(100.005)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then - Should be considered stable due to small change
        XCTAssertEqual(trendData.direction, .stable)
        XCTAssertFalse(trendData.isSignificant)
    }
    
    func testTrendDataEquality() {
        // Given
        let trend1 = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(120))
        let trend2 = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(120))
        
        // Then
        XCTAssertEqual(trend1, trend2)
    }
    
    // MARK: - Additional Edge Cases Tests
    
    func testTrendDataWithBothZeroAmounts() {
        // Given
        let previousAmount = Decimal(0.00)
        let currentAmount = Decimal(0.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changeAmount, Decimal(0.00))
        XCTAssertEqual(trendData.changePercentage, 0.0, accuracy: 0.001)
        XCTAssertEqual(trendData.direction, .stable)
        XCTAssertFalse(trendData.isSignificant)
    }
    
    func testTrendDataWithZeroCurrentAmount() {
        // Given
        let previousAmount = Decimal(100.00)
        let currentAmount = Decimal(0.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changeAmount, Decimal(-100.00))
        XCTAssertEqual(trendData.changePercentage, -1.0, accuracy: 0.001) // 100% decrease
        XCTAssertEqual(trendData.direction, .decreasing)
        XCTAssertTrue(trendData.isSignificant)
    }
    
    func testTrendDataWithVeryLargeAmounts() {
        // Given
        let previousAmount = Decimal(999999.99)
        let currentAmount = Decimal(1000000.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changeAmount, Decimal(0.01))
        XCTAssertLessThan(abs(trendData.changePercentage), 0.001) // Very small percentage change
        XCTAssertEqual(trendData.direction, .stable) // Should be considered stable due to small change
        XCTAssertFalse(trendData.isSignificant)
    }
    
    func testTrendDataWithNegativeAmounts() {
        // Given
        let previousAmount = Decimal(-50.00)
        let currentAmount = Decimal(-25.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changeAmount, Decimal(25.00))
        XCTAssertEqual(trendData.changePercentage, -0.5, accuracy: 0.001) // Negative percentage due to negative base
        XCTAssertEqual(trendData.direction, .increasing) // Amount increased (became less negative)
        XCTAssertTrue(trendData.isSignificant)
    }
    
    func testTrendDataWithNegativeToPosiveChange() {
        // Given
        let previousAmount = Decimal(-50.00)
        let currentAmount = Decimal(50.00)
        
        // When
        let trendData = TrendData(previousAmount: previousAmount, currentAmount: currentAmount)
        
        // Then
        XCTAssertEqual(trendData.changeAmount, Decimal(100.00))
        XCTAssertEqual(trendData.changePercentage, -2.0, accuracy: 0.001) // 200% increase from negative base
        XCTAssertEqual(trendData.direction, .increasing)
        XCTAssertTrue(trendData.isSignificant)
    }
    
    func testSummaryDataWithVeryLongTitle() {
        // Given
        let longTitle = String(repeating: "A", count: 1000)
        let summaryData = SummaryData(title: longTitle, amount: Decimal(100))
        
        // When & Then
        XCTAssertEqual(summaryData.title, longTitle)
        XCTAssertEqual(summaryData.amount, Decimal(100))
    }
    
    func testSummaryDataWithEmptyTitle() {
        // Given
        let summaryData = SummaryData(title: "", amount: Decimal(100))
        
        // When & Then
        XCTAssertEqual(summaryData.title, "")
        XCTAssertEqual(summaryData.amount, Decimal(100))
    }
    
    func testSummaryDataWithSpecialCharactersInTitle() {
        // Given
        let specialTitle = "💰 This Month's 📊 Summary! @#$%^&*()"
        let summaryData = SummaryData(title: specialTitle, amount: Decimal(100))
        
        // When & Then
        XCTAssertEqual(summaryData.title, specialTitle)
        XCTAssertEqual(summaryData.amount, Decimal(100))
    }
    
    func testFormattedAmountWithVerySmallAmount() {
        // Given
        let summaryData = SummaryData(title: "Test", amount: Decimal(0.01))
        
        // When
        let formattedAmount = summaryData.formattedAmount
        
        // Then
        XCTAssertTrue(formattedAmount.contains("$0") || formattedAmount.contains("$1"), "Should format small amounts correctly")
    }
    
    func testFormattedAmountWithVeryLargeAmount() {
        // Given
        let summaryData = SummaryData(title: "Test", amount: Decimal(1234567.89))
        
        // When
        let formattedAmount = summaryData.formattedAmount
        
        // Then
        XCTAssertTrue(formattedAmount.contains("$1,234,568") || formattedAmount.contains("$1234568"), "Should format large amounts correctly")
    }
    
    func testFormattedTrendWithZeroPercentageChange() {
        // Given
        let trend = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(100))
        let summaryData = SummaryData(title: "Test", amount: Decimal(100), trend: trend)
        
        // When
        let formattedTrend = summaryData.formattedTrend
        
        // Then
        XCTAssertNotNil(formattedTrend)
        XCTAssertTrue(formattedTrend!.contains("0%"), "Should show 0% for no change")
    }
    
    func testFormattedTrendWithLargePercentageChange() {
        // Given
        let trend = TrendData(previousAmount: Decimal(10), currentAmount: Decimal(1000))
        let summaryData = SummaryData(title: "Test", amount: Decimal(1000), trend: trend)
        
        // When
        let formattedTrend = summaryData.formattedTrend
        
        // Then
        XCTAssertNotNil(formattedTrend)
        XCTAssertTrue(formattedTrend!.contains("%"), "Should format large percentage changes")
    }
    
    func testTrendDataFormattedChangeAmountWithZero() {
        // Given
        let trendData = TrendData(previousAmount: Decimal(100), currentAmount: Decimal(100))
        
        // When
        let formattedChange = trendData.formattedChangeAmount
        
        // Then
        XCTAssertTrue(formattedChange.contains("$0"), "Should format zero change correctly")
    }
    
    // MARK: - Thread Safety Tests
    
    func testSummaryDataThreadSafety() {
        let expectation = XCTestExpectation(description: "Thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let summaryData = SummaryData(
                    title: "Thread Test \(i)",
                    amount: Decimal(Double(i) * 10.0)
                )
                XCTAssertEqual(summaryData.title, "Thread Test \(i)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testTrendDataThreadSafety() {
        let expectation = XCTestExpectation(description: "Trend data thread safety test")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global().async {
                let trendData = TrendData(
                    previousAmount: Decimal(Double(i)),
                    currentAmount: Decimal(Double(i) * 1.5)
                )
                XCTAssertEqual(trendData.previousAmount, Decimal(Double(i)))
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    // MARK: - Performance Tests
    
    func testSummaryDataCreationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = SummaryData(
                    title: "Performance Test \(i)",
                    amount: Decimal(Double(i) * 10.5)
                )
            }
        }
    }
    
    func testTrendDataCalculationPerformance() {
        measure {
            for i in 0..<1000 {
                let _ = TrendData(
                    previousAmount: Decimal(Double(i)),
                    currentAmount: Decimal(Double(i) * 1.2)
                )
            }
        }
    }
    
    func testFormattingPerformance() {
        let summaryData = SummaryData(
            title: "Performance Test",
            amount: Decimal(1234.56),
            trend: TrendData(previousAmount: Decimal(1000), currentAmount: Decimal(1234.56))
        )
        
        measure {
            for _ in 0..<1000 {
                let _ = summaryData.formattedAmount
                let _ = summaryData.formattedTrend
                let _ = summaryData.trend?.formattedChangeAmount
            }
        }
    }
}