import XCTest
import SwiftUI
@testable import ReceiptScannerExpenseTracker

final class ChartComponentsTests: XCTestCase {
    
    // MARK: - Test Data Setup
    
    private func createSampleChartData() -> [FlexibleChartDataPoint] {
        return [
            FlexibleChartDataPoint(label: "Food", value: 450.0, color: .blue),
            FlexibleChartDataPoint(label: "Transport", value: 320.0, color: .green),
            FlexibleChartDataPoint(label: "Shopping", value: 280.0, color: .orange),
            FlexibleChartDataPoint(label: "Entertainment", value: 150.0, color: .red)
        ]
    }
    
    private func createSampleTimeSeriesData() -> [TimeSeriesDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            return TimeSeriesDataPoint(
                date: date,
                value: Double.random(in: 50...500),
                label: "Day \(dayOffset + 1)"
            )
        }.reversed()
    }
    
    // MARK: - Chart Data Models Tests
    
    func testChartDataPointInitialization() {
        // Given
        let metadata: [String: AnyHashable] = ["count": 5, "category": "test"]
        
        // When
        let dataPoint = FlexibleChartDataPoint(
            label: "Test Label",
            value: 123.45,
            color: .blue,
            flexibleMetadata: metadata
        )
        
        // Then
        XCTAssertEqual(dataPoint.label, "Test Label")
        XCTAssertEqual(dataPoint.value, 123.45)
        XCTAssertEqual(dataPoint.color, .blue)
        XCTAssertNotNil(dataPoint.metadata)
        XCTAssertEqual(dataPoint.getMetadata(for: "count", as: Int.self), 5)
    }
    
    func testChartDataPointEquality() {
        // Given
        let dataPoint1 = FlexibleChartDataPoint(label: "Test", value: 100.0, color: .blue)
        let dataPoint2 = FlexibleChartDataPoint(label: "Test", value: 100.0, color: .blue)
        
        // Then
        XCTAssertNotEqual(dataPoint1, dataPoint2) // Different IDs
        XCTAssertEqual(dataPoint1, dataPoint1) // Same instance
    }
    
    func testTimeSeriesDataPointInitialization() {
        // Given
        let date = Date()
        
        // When
        let dataPoint = TimeSeriesDataPoint(
            date: date,
            value: 123.45,
            label: "Test Label"
        )
        
        // Then
        XCTAssertEqual(dataPoint.date, date)
        XCTAssertEqual(dataPoint.value, 123.45)
        XCTAssertEqual(dataPoint.label, "Test Label")
    }
    
    // MARK: - Chart Configuration Tests
    
    func testChartConfigurationDefaults() {
        // When
        let config = ChartConfiguration()
        
        // Then
        XCTAssertTrue(config.showLabels)
        XCTAssertTrue(config.showValues)
        XCTAssertTrue(config.showLegend)
        XCTAssertEqual(config.animationDuration, 0.8)
        XCTAssertTrue(config.interactionEnabled)
    }
    
    func testChartConfigurationCustomization() {
        // When
        let config = ChartConfiguration(
            showLabels: false,
            showValues: false,
            showLegend: false,
            animationDuration: 1.5,
            interactionEnabled: false,
            colorScheme: .monochromatic(.red)
        )
        
        // Then
        XCTAssertFalse(config.showLabels)
        XCTAssertFalse(config.showValues)
        XCTAssertFalse(config.showLegend)
        XCTAssertEqual(config.animationDuration, 1.5)
        XCTAssertFalse(config.interactionEnabled)
    }
    
    // MARK: - Chart Interaction State Tests
    
    func testChartInteractionStateInitialization() {
        // When
        let state = FlexibleChartInteractionState()
        
        // Then
        XCTAssertNil(state.selectedDataPoint)
        XCTAssertNil(state.hoveredDataPoint)
        XCTAssertFalse(state.isInteracting)
    }
    
    func testChartInteractionStateSelection() {
        // Given
        var state = FlexibleChartInteractionState()
        let dataPoint = FlexibleChartDataPoint(label: "Test", value: 100.0, color: .blue)
        
        // When
        state.selectDataPoint(dataPoint)
        
        // Then
        XCTAssertEqual(state.selectedDataPoint?.id, dataPoint.id)
        XCTAssertTrue(state.isInteracting)
    }
    
    func testChartInteractionStateClearInteraction() {
        // Given
        var state = FlexibleChartInteractionState()
        let dataPoint = FlexibleChartDataPoint(label: "Test", value: 100.0, color: .blue)
        state.selectDataPoint(dataPoint)
        state.hoverDataPoint(dataPoint)
        
        // When
        state.clearInteraction()
        
        // Then
        XCTAssertNil(state.selectedDataPoint)
        XCTAssertNil(state.hoveredDataPoint)
        XCTAssertFalse(state.isInteracting)
    }
    
    // MARK: - Chart Color Scheme Tests
    
    func testAutomaticColorScheme() {
        // When
        let colors = ChartColorScheme.automatic.colors(for: 5)
        
        // Then
        XCTAssertEqual(colors.count, 5)
        XCTAssertEqual(colors[0], .blue)
        XCTAssertEqual(colors[1], .green)
        XCTAssertEqual(colors[2], .orange)
    }
    
    func testCategoryColorScheme() {
        // When
        let colors = ChartColorScheme.category.colors(for: 3)
        
        // Then
        XCTAssertEqual(colors.count, 3)
        // Should return category-specific colors
        XCTAssertNotEqual(colors[0], colors[1])
        XCTAssertNotEqual(colors[1], colors[2])
    }
    
    func testMonochromaticColorScheme() {
        // When
        let colors = ChartColorScheme.monochromatic(.blue).colors(for: 4)
        
        // Then
        XCTAssertEqual(colors.count, 4)
        // All colors should be variations of blue
        for color in colors {
            // This is a basic test - in a real scenario, you might want to test
            // the actual color components
            XCTAssertNotNil(color)
        }
    }
    
    func testCustomColorScheme() {
        // Given
        let customColors: [Color] = [.red, .yellow, .purple]
        
        // When
        let colors = ChartColorScheme.custom(customColors).colors(for: 2)
        
        // Then
        XCTAssertEqual(colors.count, 2)
        XCTAssertEqual(colors[0], .red)
        XCTAssertEqual(colors[1], .yellow)
    }
    
    func testCustomColorSchemeMoreThanAvailable() {
        // Given
        let customColors: [Color] = [.red, .yellow]
        
        // When
        let colors = ChartColorScheme.custom(customColors).colors(for: 5)
        
        // Then
        XCTAssertEqual(colors.count, 2) // Should only return available colors
        XCTAssertEqual(colors[0], .red)
        XCTAssertEqual(colors[1], .yellow)
    }
    
    // MARK: - Chart View Creation Tests
    
    func testBarChartViewCreation() {
        // Given
        let data = createSampleChartData()
        let config = ChartConfiguration()
        
        // When
        let barChart = BarChartView(data: data, configuration: config)
        
        // Then
        XCTAssertNotNil(barChart)
        // Additional UI testing would require ViewInspector or similar
    }
    
    func testPieChartViewCreation() {
        // Given
        let data = createSampleChartData()
        let config = ChartConfiguration()
        
        // When
        let pieChart = PieChartView(data: data, configuration: config)
        
        // Then
        XCTAssertNotNil(pieChart)
    }
    
    func testLineChartViewCreation() {
        // Given
        let data = createSampleTimeSeriesData()
        let config = ChartConfiguration()
        
        // When
        let lineChart = LineChartView(data: data, configuration: config)
        
        // Then
        XCTAssertNotNil(lineChart)
    }
    
    // MARK: - Chart Data Validation Tests
    
    func testEmptyDataHandling() {
        // Given
        let emptyData: [FlexibleChartDataPoint] = []
        let emptyTimeSeriesData: [TimeSeriesDataPoint] = []
        
        // When & Then - Should not crash
        let barChart = BarChartView(data: emptyData)
        let pieChart = PieChartView(data: emptyData)
        let lineChart = LineChartView(data: emptyTimeSeriesData)
        
        XCTAssertNotNil(barChart)
        XCTAssertNotNil(pieChart)
        XCTAssertNotNil(lineChart)
    }
    
    func testSingleDataPointHandling() {
        // Given
        let singleData = [FlexibleChartDataPoint(label: "Single", value: 100.0, color: .blue)]
        let singleTimeSeriesData = [TimeSeriesDataPoint(date: Date(), value: 100.0)]
        
        // When & Then - Should not crash
        let barChart = BarChartView(data: singleData)
        let pieChart = PieChartView(data: singleData)
        let lineChart = LineChartView(data: singleTimeSeriesData)
        
        XCTAssertNotNil(barChart)
        XCTAssertNotNil(pieChart)
        XCTAssertNotNil(lineChart)
    }
    
    func testNegativeValueHandling() {
        // Given
        let dataWithNegatives = [
            FlexibleChartDataPoint(label: "Positive", value: 100.0, color: .blue),
            FlexibleChartDataPoint(label: "Negative", value: -50.0, color: .red),
            FlexibleChartDataPoint(label: "Zero", value: 0.0, color: .gray)
        ]
        
        // When & Then - Should handle gracefully
        let barChart = BarChartView(data: dataWithNegatives)
        let pieChart = PieChartView(data: dataWithNegatives)
        
        XCTAssertNotNil(barChart)
        XCTAssertNotNil(pieChart)
    }
    
    // MARK: - Chart Accessibility Tests
    
    func testChartDataPointAccessibilityDescription() {
        // Given
        let dataPoint = FlexibleChartDataPoint(label: "Food Expenses", value: 123.45, color: .blue)
        
        // When
        let description = dataPoint.formattedDescription
        
        // Then
        XCTAssertTrue(description.contains("Food Expenses"))
        XCTAssertTrue(description.contains("$"))
        XCTAssertTrue(description.contains("123"))
    }
    
    func testTimeSeriesDataPointAccessibilityDescription() {
        // Given
        let date = Date()
        let dataPoint = TimeSeriesDataPoint(date: date, value: 123.45, label: "Test Day")
        
        // When
        let description = dataPoint.formattedDescription
        
        // Then
        XCTAssertTrue(description.contains("$"))
        XCTAssertTrue(description.contains("123"))
        // Should contain some date representation
        XCTAssertGreaterThan(description.count, 10)
    }
    
    // MARK: - Performance Tests
    
    func testLargeDatasetPerformance() {
        // Given - Large dataset
        let largeDataset = (0..<1000).map { index in
            FlexibleChartDataPoint(
                label: "Item \(index)",
                value: Double.random(in: 1...1000),
                color: Color.blue
            )
        }
        
        // When & Then - Should create charts without performance issues
        measure {
            let _ = BarChartView(data: largeDataset)
            let _ = PieChartView(data: largeDataset)
        }
    }
    
    func testTimeSeriesPerformance() {
        // Given - Large time series dataset
        let calendar = Calendar.current
        let startDate = Date()
        let largeTimeSeriesDataset = (0..<365).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: startDate) ?? startDate
            return TimeSeriesDataPoint(
                date: date,
                value: Double.random(in: 1...1000),
                label: "Day \(dayOffset)"
            )
        }
        
        // When & Then - Should create line chart without performance issues
        measure {
            let _ = LineChartView(data: largeTimeSeriesDataset)
        }
    }
    
    // MARK: - Chart Configuration Edge Cases
    
    func testZeroAnimationDuration() {
        // Given
        let config = ChartConfiguration(animationDuration: 0.0)
        let data = createSampleChartData()
        
        // When & Then - Should handle zero animation duration
        let barChart = BarChartView(data: data, configuration: config)
        XCTAssertNotNil(barChart)
    }
    
    func testNegativeAnimationDuration() {
        // Given
        let config = ChartConfiguration(animationDuration: -1.0)
        let data = createSampleChartData()
        
        // When & Then - Should handle negative animation duration gracefully
        let barChart = BarChartView(data: data, configuration: config)
        XCTAssertNotNil(barChart)
    }
    
    func testDisabledInteractions() {
        // Given
        let config = ChartConfiguration(interactionEnabled: false)
        let data = createSampleChartData()
        
        // When & Then - Should create charts with interactions disabled
        let barChart = BarChartView(data: data, configuration: config)
        let pieChart = PieChartView(data: data, configuration: config)
        let lineChart = LineChartView(data: createSampleTimeSeriesData(), configuration: config)
        
        XCTAssertNotNil(barChart)
        XCTAssertNotNil(pieChart)
        XCTAssertNotNil(lineChart)
    }
}