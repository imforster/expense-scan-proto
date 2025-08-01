import XCTest
@testable import ReceiptScannerExpenseTracker

final class ChartDataTransformersTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createSampleCategorySpending() -> [CategorySpending] {
        let foodCategory = CategoryData(id: UUID(), name: "Food", icon: "fork.knife", colorHex: "#FF0000")
        let transportCategory = CategoryData(id: UUID(), name: "Transport", icon: "car", colorHex: "#00FF00")
        
        return [
            CategorySpending(
                category: foodCategory,
                amount: Decimal(450.0),
                percentage: 0.6,
                transactionCount: 15,
                averageAmount: Decimal(30.0)
            ),
            CategorySpending(
                category: transportCategory,
                amount: Decimal(300.0),
                percentage: 0.4,
                transactionCount: 8,
                averageAmount: Decimal(37.5)
            )
        ]
    }
    
    private func createSampleVendorSpending() -> [VendorSpending] {
        let foodCategory = CategoryData(id: UUID(), name: "Food")
        
        return [
            VendorSpending(
                vendorName: "Starbucks",
                amount: Decimal(120.0),
                transactionCount: 6,
                averageAmount: Decimal(20.0),
                lastTransactionDate: Date(),
                categoryDistribution: [
                    CategorySpending(
                        category: foodCategory,
                        amount: Decimal(120.0),
                        percentage: 1.0,
                        transactionCount: 6,
                        averageAmount: Decimal(20.0)
                    )
                ]
            )
        ]
    }
    
    private func createSampleDailySpending() -> [DailySpending] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            return DailySpending(
                date: date,
                amount: Decimal(Double.random(in: 50...200)),
                transactionCount: Int.random(in: 1...5)
            )
        }
    }
    
    private func createSampleBudgetData() -> [(name: String, current: Double, limit: Double, percentage: Float)] {
        return [
            (name: "Food", current: 350.0, limit: 500.0, percentage: 0.7)
        ]
    }
    
    // MARK: - Category Spending Transformation Tests
    
    func testTransformCategorySpending() {
        // Given
        let categorySpending = createSampleCategorySpending()
        
        // When
        let chartData = ChartDataTransformers.transformCategorySpending(categorySpending)
        
        // Then
        XCTAssertEqual(chartData.count, 2)
        
        let foodData = chartData.first { $0.label == "Food" }
        XCTAssertNotNil(foodData)
        XCTAssertEqual(foodData?.value, 450.0)
        XCTAssertEqual(foodData?.metadata?.transactionCount, 15)
        XCTAssertEqual(foodData?.metadata?.percentage, 0.6)
        
        let transportData = chartData.first { $0.label == "Transport" }
        XCTAssertNotNil(transportData)
        XCTAssertEqual(transportData?.value, 300.0)
        XCTAssertEqual(transportData?.metadata?.transactionCount, 8)
    }
    
    func testTransformCategorySpendingFlexible() {
        // Given
        let categorySpending = createSampleCategorySpending()
        
        // When
        let chartData = ChartDataTransformers.transformCategorySpendingFlexible(categorySpending)
        
        // Then
        XCTAssertEqual(chartData.count, 2)
        
        let foodData = chartData.first { $0.label == "Food" }
        XCTAssertNotNil(foodData)
        XCTAssertEqual(foodData?.value, 450.0)
        XCTAssertEqual(foodData?.getMetadata(for: "transactionCount", as: Int.self), 15)
        XCTAssertEqual(foodData?.getMetadata(for: "percentage", as: Double.self), 0.6)
    }
    
    func testTransformVendorSpending() {
        // Given
        let vendorSpending = createSampleVendorSpending()
        
        // When
        let chartData = ChartDataTransformers.transformVendorSpending(vendorSpending)
        
        // Then
        XCTAssertEqual(chartData.count, 1)
        
        let starbucksData = chartData.first
        XCTAssertNotNil(starbucksData)
        XCTAssertEqual(starbucksData?.label, "Starbucks")
        XCTAssertEqual(starbucksData?.value, 120.0)
        XCTAssertEqual(starbucksData?.getMetadata(for: "transactionCount", as: Int.self), 6)
    }
    
    // MARK: - Time Series Transformation Tests
    
    func testTransformDailySpending() {
        // Given
        let dailySpending = createSampleDailySpending()
        
        // When
        let timeSeriesData = ChartDataTransformers.transformDailySpending(dailySpending)
        
        // Then
        XCTAssertEqual(timeSeriesData.count, dailySpending.count)
        
        for (index, dataPoint) in timeSeriesData.enumerated() {
            let originalData = dailySpending[index]
            XCTAssertEqual(dataPoint.date, originalData.date)
            XCTAssertEqual(dataPoint.value, Double(truncating: originalData.amount as NSNumber))
            XCTAssertTrue(dataPoint.label?.contains("transactions") ?? false)
        }
    }
    
    func testTransformBudgetStatusPlaceholder() {
        // Given
        let budgetData = createSampleBudgetData()
        
        // When
        let chartData = ChartDataTransformers.transformBudgetStatusPlaceholder(budgetData)
        
        // Then
        XCTAssertEqual(chartData.count, 1)
        
        let budgetChartData = chartData.first
        XCTAssertNotNil(budgetChartData)
        XCTAssertEqual(budgetChartData?.label, "Food")
        XCTAssertEqual(budgetChartData?.value, 350.0)
        XCTAssertEqual(budgetChartData?.getMetadata(for: "percentageUsed", as: Float.self), 0.7)
        
        // Test color assignment based on budget usage
        // 70% usage should result in orange color (warning level)
        XCTAssertEqual(budgetChartData?.color, .orange)
    }
    
    // MARK: - Data Aggregation Tests
    
    func testAggregateSpendingByPeriod() {
        // Given
        let dailySpending = createSampleDailySpending()
        
        // When - Daily aggregation (should be same as input)
        let dailyAggregated = ChartDataTransformers.aggregateSpendingByPeriod(dailySpending, period: .daily)
        
        // Then
        XCTAssertEqual(dailyAggregated.count, dailySpending.count)
        
        // When - Weekly aggregation
        let weeklyAggregated = ChartDataTransformers.aggregateSpendingByPeriod(dailySpending, period: .weekly)
        
        // Then - Should have fewer data points (grouped by week)
        XCTAssertLessThanOrEqual(weeklyAggregated.count, dailySpending.count)
        
        // Verify total amount is preserved
        let originalTotal = dailySpending.reduce(0) { $0 + Double(truncating: $1.amount as NSNumber) }
        let aggregatedTotal = weeklyAggregated.reduce(0) { $0 + $1.value }
        XCTAssertEqual(originalTotal, aggregatedTotal, accuracy: 0.01)
    }
    
    // MARK: - Data Filtering Tests
    
    func testFilterChartData() {
        // Given
        let chartData = [
            FlexibleChartDataPoint(label: "A", value: 100.0, color: .blue),
            FlexibleChartDataPoint(label: "B", value: 200.0, color: .green),
            FlexibleChartDataPoint(label: "C", value: 300.0, color: .red),
            FlexibleChartDataPoint(label: "D", value: 400.0, color: .orange)
        ]
        
        // When - Filter by minimum value
        let minFiltered = ChartDataTransformers.filterChartData(chartData, minValue: 250.0)
        
        // Then
        XCTAssertEqual(minFiltered.count, 2)
        XCTAssertTrue(minFiltered.allSatisfy { $0.value >= 250.0 })
        
        // When - Filter by maximum value
        let maxFiltered = ChartDataTransformers.filterChartData(chartData, maxValue: 250.0)
        
        // Then
        XCTAssertEqual(maxFiltered.count, 2)
        XCTAssertTrue(maxFiltered.allSatisfy { $0.value <= 250.0 })
        
        // When - Filter top N
        let topNFiltered = ChartDataTransformers.filterChartData(chartData, topN: 2)
        
        // Then
        XCTAssertEqual(topNFiltered.count, 2)
        XCTAssertEqual(topNFiltered[0].value, 400.0) // Highest value first
        XCTAssertEqual(topNFiltered[1].value, 300.0) // Second highest
    }
    
    // MARK: - Data Normalization Tests
    
    func testNormalizeChartData() {
        // Given
        let chartData = [
            FlexibleChartDataPoint(label: "A", value: 100.0, color: .blue),
            FlexibleChartDataPoint(label: "B", value: 200.0, color: .green),
            FlexibleChartDataPoint(label: "C", value: 300.0, color: .red)
        ]
        
        // When
        let normalizedData = ChartDataTransformers.normalizeChartData(chartData, to: 0...1)
        
        // Then
        XCTAssertEqual(normalizedData.count, 3)
        XCTAssertEqual(normalizedData[0].value, 0.0, accuracy: 0.01) // Min value -> 0
        XCTAssertEqual(normalizedData[1].value, 0.5, accuracy: 0.01) // Mid value -> 0.5
        XCTAssertEqual(normalizedData[2].value, 1.0, accuracy: 0.01) // Max value -> 1
        
        // Labels and colors should be preserved
        XCTAssertEqual(normalizedData[0].label, "A")
        XCTAssertEqual(normalizedData[0].color, .blue)
    }
    
    func testNormalizeChartDataWithSameValues() {
        // Given - All same values
        let chartData = [
            FlexibleChartDataPoint(label: "A", value: 100.0, color: .blue),
            FlexibleChartDataPoint(label: "B", value: 100.0, color: .green),
            FlexibleChartDataPoint(label: "C", value: 100.0, color: .red)
        ]
        
        // When
        let normalizedData = ChartDataTransformers.normalizeChartData(chartData, to: 0...1)
        
        // Then - Should return original data when all values are the same
        XCTAssertEqual(normalizedData.count, 3)
        for dataPoint in normalizedData {
            XCTAssertEqual(dataPoint.value, 100.0)
        }
    }
    
    // MARK: - Chart Data Point Extension Tests
    
    func testChartDataPointMetadata() {
        // Given
        let metadata: [String: AnyHashable] = [
            "count": 5,
            "percentage": 0.25,
            "name": "Test"
        ]
        let dataPoint = FlexibleChartDataPoint(label: "Test", value: 100.0, color: .blue, flexibleMetadata: metadata)
        
        // When & Then
        XCTAssertEqual(dataPoint.getMetadata(for: "count", as: Int.self), 5)
        XCTAssertEqual(dataPoint.getMetadata(for: "percentage", as: Double.self), 0.25)
        XCTAssertEqual(dataPoint.getMetadata(for: "name", as: String.self), "Test")
        XCTAssertNil(dataPoint.getMetadata(for: "nonexistent", as: String.self))
    }
    
    func testChartDataPointFormattedDescription() {
        // Given
        let dataPoint = FlexibleChartDataPoint(label: "Food", value: 123.45, color: .blue)
        
        // When
        let description = dataPoint.formattedDescription
        
        // Then
        XCTAssertTrue(description.contains("Food"))
        XCTAssertTrue(description.contains("$123"))
    }
    
    // MARK: - Time Series Data Point Extension Tests
    
    func testTimeSeriesDataPointFormattedDescription() {
        // Given
        let date = Date()
        let dataPoint = TimeSeriesDataPoint(date: date, value: 123.45)
        
        // When
        let description = dataPoint.formattedDescription
        
        // Then
        XCTAssertTrue(description.contains("$123"))
        // Should contain some date representation
        XCTAssertTrue(description.count > 5) // More than just the value
    }
    
    // MARK: - Color Scheme Tests
    
    func testChartColorSchemeColors() {
        // Test automatic color scheme
        let automaticColors = ChartColorScheme.automatic.colors(for: 5)
        XCTAssertEqual(automaticColors.count, 5)
        
        // Test category color scheme
        let categoryColors = ChartColorScheme.category.colors(for: 3)
        XCTAssertEqual(categoryColors.count, 3)
        
        // Test monochromatic color scheme
        let monoColors = ChartColorScheme.monochromatic(.blue).colors(for: 4)
        XCTAssertEqual(monoColors.count, 4)
        
        // Test custom color scheme
        let customColors = ChartColorScheme.custom([.red, .green, .blue]).colors(for: 2)
        XCTAssertEqual(customColors.count, 2)
        XCTAssertEqual(customColors[0], .red)
        XCTAssertEqual(customColors[1], .green)
    }
    
    // MARK: - Performance Tests
    
    func testTransformLargeDatasetPerformance() {
        // Given - Large dataset
        let largeDataset = (0..<1000).map { index in
            CategorySpending(
                category: CategoryData(id: UUID(), name: "Category \(index)"),
                amount: Decimal(Double.random(in: 10...1000)),
                percentage: Double.random(in: 0...1),
                transactionCount: Int.random(in: 1...50),
                averageAmount: Decimal(Double.random(in: 10...100))
            )
        }
        
        // When & Then - Should complete within reasonable time
        measure {
            let _ = ChartDataTransformers.transformCategorySpending(largeDataset)
        }
    }
}