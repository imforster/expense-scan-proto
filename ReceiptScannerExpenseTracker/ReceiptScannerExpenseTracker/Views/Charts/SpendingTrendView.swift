import SwiftUI

/// Comprehensive spending trend visualization component
struct SpendingTrendView: View {
    let data: [TimeSeriesDataPoint]
    let configuration: ChartConfiguration
    let trendMetadata: TrendChartMetadata?
    
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var showComparison: Bool = false
    @State private var interactionState = TimeSeriesInteractionState()
    @State private var animationProgress: Double = 0
    
    private let chartHeight: CGFloat = 250
    
    init(
        data: [TimeSeriesDataPoint],
        configuration: ChartConfiguration = ChartConfiguration(),
        trendMetadata: TrendChartMetadata? = nil
    ) {
        self.data = data.sorted { $0.date < $1.date }
        self.configuration = configuration
        self.trendMetadata = trendMetadata
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with controls
            headerView
            
            // Main chart
            chartContainerView
            
            // Trend insights
            if let metadata = trendMetadata {
                trendInsightsView(metadata)
            }
            
            // Interactive details
            if let selectedPoint = interactionState.selectedDataPoint {
                selectedDataPointView(selectedPoint)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: configuration.animationDuration)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spending Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let metadata = trendMetadata {
                    trendSummaryText(metadata)
                }
            }
            
            Spacer()
            
            // Period selector
            Picker("Period", selection: $selectedPeriod) {
                ForEach(TrendPeriod.allCases, id: \.self) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(width: 200)
        }
    }
    
    // MARK: - Chart Container
    private var chartContainerView: some View {
        VStack(spacing: 12) {
            // Chart area
            GeometryReader { geometry in
                ZStack {
                    // Background and grid
                    chartBackgroundView(in: geometry)
                    
                    // Trend line with area fill
                    trendLineView(in: geometry)
                    
                    // Data points
                    dataPointsView(in: geometry)
                    
                    // Interaction overlay
                    if configuration.interactionEnabled {
                        interactionOverlay(in: geometry)
                    }
                    
                    // Trend annotations
                    trendAnnotationsView(in: geometry)
                }
            }
            .frame(height: chartHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
            .clipped()
            
            // Time axis labels
            if configuration.showLabels {
                timeAxisLabelsView
            }
        }
    }
    
    // MARK: - Chart Background
    private func chartBackgroundView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Horizontal grid lines
            ForEach(0..<6, id: \.self) { index in
                let y = CGFloat(index) * (geometry.size.height / 5)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
            
            // Vertical grid lines (monthly markers)
            ForEach(Array(monthlyMarkers.enumerated()), id: \.offset) { index, date in
                let x = xPosition(for: date, in: geometry)
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Trend Line View
    private func trendLineView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Area fill with gradient
            areaPath(in: geometry)
                .fill(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: trendColor.opacity(0.3), location: 0),
                            .init(color: trendColor.opacity(0.1), location: 0.5),
                            .init(color: Color.clear, location: 1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(animationProgress)
            
            // Main trend line
            linePath(in: geometry)
                .trim(from: 0, to: animationProgress)
                .stroke(
                    trendColor,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
            
            // Moving average line (if enabled)
            if showComparison {
                movingAveragePath(in: geometry)
                    .trim(from: 0, to: animationProgress)
                    .stroke(
                        Color.orange.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [5, 3])
                    )
            }
        }
    }
    
    // MARK: - Data Points View
    private func dataPointsView(in geometry: GeometryProxy) -> some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
            let position = pointPosition(for: dataPoint, at: index, in: geometry)
            let isSelected = interactionState.selectedDataPoint?.id == dataPoint.id
            let isHovered = interactionState.hoveredDataPoint?.id == dataPoint.id
            
            Circle()
                .fill(trendColor)
                .frame(width: isSelected ? 10 : (isHovered ? 8 : 6))
                .position(position)
                .scaleEffect(animationProgress)
                .shadow(
                    color: trendColor.opacity(0.4),
                    radius: isSelected ? 4 : (isHovered ? 3 : 2),
                    x: 0,
                    y: isSelected ? 2 : 1
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .onTapGesture {
                    if configuration.interactionEnabled {
                        handleTap(on: dataPoint)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(dataPoint.formattedDescription)
                .accessibilityAddTraits(.isButton)
        }
    }
    
    // MARK: - Trend Annotations
    private func trendAnnotationsView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Peak and valley markers
            ForEach(significantPoints, id: \.id) { point in
                let position = pointPosition(for: point, at: dataIndex(for: point), in: geometry)
                
                VStack(spacing: 2) {
                    Image(systemName: point.value == maxValue ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                        .foregroundColor(point.value == maxValue ? .green : .red)
                        .font(.caption)
                    
                    Text(formatValue(point.value))
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(UIColor.systemBackground))
                                .shadow(radius: 1)
                        )
                }
                .position(x: position.x, y: position.y - 30)
                .opacity(animationProgress)
            }
        }
    }
    
    // MARK: - Time Axis Labels
    private var timeAxisLabelsView: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(monthlyMarkers.enumerated()), id: \.offset) { index, date in
                    Text(formatDateLabel(date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(height: 20)
    }
    
    // MARK: - Trend Insights View
    private func trendInsightsView(_ metadata: TrendChartMetadata) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend Analysis")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                // Change indicator
                HStack(spacing: 4) {
                    Image(systemName: trendDirectionIcon(metadata.trendDirection))
                        .foregroundColor(trendDirectionColor(metadata.trendDirection))
                    
                    Text(metadata.trendDirection.capitalized)
                        .font(.caption)
                        .foregroundColor(trendDirectionColor(metadata.trendDirection))
                }
                
                // Change amount
                if let changeAmount = metadata.changeAmount {
                    Text(formatValue(abs(changeAmount)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Change percentage
                if let changePercentage = metadata.changePercentage {
                    Text("(\(formatPercentage(changePercentage)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Significance indicator
                if metadata.isSignificantChange {
                    Text("Significant Change")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
    
    // MARK: - Selected Data Point View
    private func selectedDataPointView(_ dataPoint: TimeSeriesDataPoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(trendColor)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(dataPoint.date))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(formatValue(dataPoint.value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(trendColor)
                
                if let label = dataPoint.label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Clear") {
                withAnimation(.easeInOut(duration: 0.3)) {
                    interactionState.clearInteraction()
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // MARK: - Computed Properties
    
    private var trendColor: Color {
        guard let metadata = trendMetadata else { return .blue }
        
        switch metadata.trendDirection {
        case "increasing":
            return .green
        case "decreasing":
            return .red
        default:
            return .blue
        }
    }
    
    private var maxValue: Double {
        data.map(\.value).max() ?? 1.0
    }
    
    private var minValue: Double {
        data.map(\.value).min() ?? 0.0
    }
    
    private var valueRange: Double {
        maxValue - minValue
    }
    
    private var monthlyMarkers: [Date] {
        guard !data.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let startDate = data.first!.date
        let endDate = data.last!.date
        
        var markers: [Date] = []
        var currentDate = calendar.dateInterval(of: .month, for: startDate)?.start ?? startDate
        
        while currentDate <= endDate {
            markers.append(currentDate)
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return markers
    }
    
    private var significantPoints: [TimeSeriesDataPoint] {
        guard data.count > 2 else { return [] }
        
        let maxPoint = data.max { $0.value < $1.value }!
        let minPoint = data.min { $0.value < $1.value }!
        
        return [maxPoint, minPoint]
    }
    
    // MARK: - Helper Methods
    
    private func trendSummaryText(_ metadata: TrendChartMetadata) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trendDirectionIcon(metadata.trendDirection))
                .foregroundColor(trendDirectionColor(metadata.trendDirection))
                .font(.caption)
            
            if let changePercentage = metadata.changePercentage {
                Text("\(formatPercentage(changePercentage)) vs previous period")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Spending trend analysis")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func trendDirectionIcon(_ direction: String) -> String {
        switch direction {
        case "increasing":
            return "arrow.up.right"
        case "decreasing":
            return "arrow.down.right"
        default:
            return "arrow.right"
        }
    }
    
    private func trendDirectionColor(_ direction: String) -> Color {
        switch direction {
        case "increasing":
            return .red
        case "decreasing":
            return .green
        default:
            return .blue
        }
    }
    
    private func dataIndex(for point: TimeSeriesDataPoint) -> Int {
        data.firstIndex { $0.id == point.id } ?? 0
    }
    
    // MARK: - Path Creation and Positioning (similar to LineChartView)
    
    private func linePath(in geometry: GeometryProxy) -> Path {
        var path = Path()
        guard !data.isEmpty else { return path }
        
        let firstPoint = pointPosition(for: data[0], at: 0, in: geometry)
        path.move(to: firstPoint)
        
        for (index, dataPoint) in data.enumerated().dropFirst() {
            let point = pointPosition(for: dataPoint, at: index, in: geometry)
            path.addLine(to: point)
        }
        
        return path
    }
    
    private func areaPath(in geometry: GeometryProxy) -> Path {
        var path = linePath(in: geometry)
        guard !data.isEmpty else { return path }
        
        let lastPoint = pointPosition(for: data.last!, at: data.count - 1, in: geometry)
        path.addLine(to: CGPoint(x: lastPoint.x, y: geometry.size.height))
        
        let firstPoint = pointPosition(for: data[0], at: 0, in: geometry)
        path.addLine(to: CGPoint(x: firstPoint.x, y: geometry.size.height))
        
        path.closeSubpath()
        return path
    }
    
    private func movingAveragePath(in geometry: GeometryProxy) -> Path {
        var path = Path()
        guard data.count >= 3 else { return path }
        
        let movingAverageData = calculateMovingAverage(data, window: 3)
        guard !movingAverageData.isEmpty else { return path }
        
        let firstPoint = pointPosition(for: movingAverageData[0], at: 0, in: geometry)
        path.move(to: firstPoint)
        
        for (index, dataPoint) in movingAverageData.enumerated().dropFirst() {
            let point = pointPosition(for: dataPoint, at: index, in: geometry)
            path.addLine(to: point)
        }
        
        return path
    }
    
    private func calculateMovingAverage(_ data: [TimeSeriesDataPoint], window: Int) -> [TimeSeriesDataPoint] {
        guard data.count >= window else { return [] }
        
        var result: [TimeSeriesDataPoint] = []
        
        for i in (window - 1)..<data.count {
            let windowData = Array(data[(i - window + 1)...i])
            let average = windowData.reduce(0) { $0 + $1.value } / Double(window)
            
            result.append(TimeSeriesDataPoint(
                date: data[i].date,
                value: average,
                label: "Moving Average"
            ))
        }
        
        return result
    }
    
    private func xPosition(for date: Date, in geometry: GeometryProxy) -> CGFloat {
        guard !data.isEmpty else { return 0 }
        
        let startDate = data.first!.date
        let endDate = data.last!.date
        let totalDuration = endDate.timeIntervalSince(startDate)
        
        guard totalDuration > 0 else { return geometry.size.width / 2 }
        
        let dateOffset = date.timeIntervalSince(startDate)
        let normalizedPosition = dateOffset / totalDuration
        
        return CGFloat(normalizedPosition) * geometry.size.width
    }
    
    private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        guard valueRange > 0 else { return geometry.size.height / 2 }
        let normalizedValue = (value - minValue) / valueRange
        return geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)
    }
    
    private func pointPosition(for dataPoint: TimeSeriesDataPoint, at index: Int, in geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: xPosition(for: dataPoint.date, in: geometry),
            y: yPosition(for: dataPoint.value, in: geometry)
        )
    }
    
    // MARK: - Interaction Handlers
    
    private func handleTap(on dataPoint: TimeSeriesDataPoint) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if interactionState.selectedDataPoint?.id == dataPoint.id {
                interactionState.clearInteraction()
            } else {
                interactionState.selectDataPoint(dataPoint)
            }
        }
    }
    
    private func interactionOverlay(in geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDrag(at: value.location, in: geometry)
                    }
                    .onEnded { _ in
                        interactionState.hoveredDataPoint = nil
                    }
            )
    }
    
    private func handleDrag(at location: CGPoint, in geometry: GeometryProxy) {
        var closestDistance: CGFloat = .infinity
        var closestDataPoint: TimeSeriesDataPoint?
        
        for (index, dataPoint) in data.enumerated() {
            let pointPosition = pointPosition(for: dataPoint, at: index, in: geometry)
            let distance = sqrt(pow(location.x - pointPosition.x, 2) + pow(location.y - pointPosition.y, 2))
            
            if distance < closestDistance && distance < 30 {
                closestDistance = distance
                closestDataPoint = dataPoint
            }
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            interactionState.hoveredDataPoint = closestDataPoint
        }
    }
    
    // MARK: - Formatting Methods
    
    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

// MARK: - Supporting Types

enum TrendPeriod: CaseIterable {
    case week
    case month
    case quarter
    case year
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        case .year: return "Year"
        }
    }
}

// MARK: - Preview
#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let sampleData = (0..<30).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        let baseValue = 200.0
        let variation = Double.random(in: -100...100)
        let trend = Double(dayOffset) * 5 // Increasing trend
        return TimeSeriesDataPoint(date: date, value: max(50, baseValue + variation + trend))
    }.reversed()
    
    let trendMetadata = TrendChartMetadata(
        previousValue: 150.0,
        changeAmount: 50.0,
        changePercentage: 0.25,
        trendDirection: "increasing",
        isSignificantChange: true
    )
    
    VStack(spacing: 20) {
        Text("Spending Trend Analysis")
            .font(.title2)
            .fontWeight(.semibold)
        
        SpendingTrendView(
            data: Array(sampleData),
            trendMetadata: trendMetadata
        )
        .padding()
    }
    .background(Color(UIColor.systemBackground))
}