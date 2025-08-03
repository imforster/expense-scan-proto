import SwiftUI

/// Time Series Interaction State
struct TimeSeriesInteractionState {
    var selectedDataPoint: TimeSeriesDataPoint?
    var hoveredDataPoint: TimeSeriesDataPoint?
    var isInteracting: Bool = false
    
    mutating func selectDataPoint(_ dataPoint: TimeSeriesDataPoint?) {
        selectedDataPoint = dataPoint
        isInteracting = dataPoint != nil
    }
    
    mutating func hoverDataPoint(_ dataPoint: TimeSeriesDataPoint?) {
        hoveredDataPoint = dataPoint
    }
    
    mutating func clearInteraction() {
        selectedDataPoint = nil
        hoveredDataPoint = nil
        isInteracting = false
    }
}

/// Reusable line chart component for time series data with interactive elements
struct LineChartView: View {
    let data: [TimeSeriesDataPoint]
    let configuration: ChartConfiguration
    @State private var interactionState = TimeSeriesInteractionState()
    @State private var animationProgress: Double = 0
    
    private let chartHeight: CGFloat = 200
    private let minValue: Double
    private let maxValue: Double
    private let valueRange: Double
    
    init(data: [TimeSeriesDataPoint], configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data.sorted { $0.date < $1.date }
        self.configuration = configuration
        
        let values = data.map(\.value)
        self.minValue = values.min() ?? 0
        self.maxValue = values.max() ?? 1
        self.valueRange = maxValue - minValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            chartView
            
            if configuration.showLabels {
                timeLabelsView
            }
            
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
    
    // MARK: - Chart View
    private var chartView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background grid
                gridView(in: geometry)
                
                // Line path
                linePathView(in: geometry)
                
                // Data points
                dataPointsView(in: geometry)
                
                // Interaction overlay
                if configuration.interactionEnabled {
                    interactionOverlay(in: geometry)
                }
            }
        }
        .frame(height: chartHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
        .clipped()
    }
    
    // MARK: - Grid View
    private func gridView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Horizontal grid lines
            ForEach(0..<5, id: \.self) { index in
                let y = CGFloat(index) * (geometry.size.height / 4)
                Path { path in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            }
            
            // Vertical grid lines
            ForEach(0..<data.count, id: \.self) { index in
                let x = xPosition(for: index, in: geometry)
                Path { path in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            }
        }
    }
    
    // MARK: - Line Path View
    private func linePathView(in geometry: GeometryProxy) -> some View {
        ZStack {
            // Area fill
            areaPath(in: geometry)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.blue.opacity(0.3),
                            Color.blue.opacity(0.1),
                            Color.clear
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(animationProgress)
            
            // Line stroke
            linePath(in: geometry)
                .trim(from: 0, to: animationProgress)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )
        }
    }
    
    // MARK: - Data Points View
    private func dataPointsView(in geometry: GeometryProxy) -> some View {
        ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
            let position = pointPosition(for: dataPoint, at: index, in: geometry)
            let isSelected = interactionState.selectedDataPoint?.id == dataPoint.id
            let isHovered = interactionState.hoveredDataPoint?.id == dataPoint.id
            
            Circle()
                .fill(Color.blue)
                .frame(width: isSelected ? 12 : (isHovered ? 10 : 8))
                .position(position)
                .scaleEffect(animationProgress)
                .shadow(
                    color: Color.blue.opacity(0.3),
                    radius: isSelected ? 6 : (isHovered ? 4 : 2),
                    x: 0,
                    y: isSelected ? 3 : (isHovered ? 2 : 1)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .onTapGesture {
                    if configuration.interactionEnabled {
                        handleTap(on: dataPoint)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(formatDate(dataPoint.date)): \(formatValue(dataPoint.value))")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Double tap to select this data point")
            
            // Value label
            if configuration.showValues && (isSelected || isHovered) {
                Text(formatValue(dataPoint.value))
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(UIColor.systemBackground))
                            .shadow(radius: 2)
                    )
                    .position(x: position.x, y: position.y - 20)
                    .opacity(isSelected || isHovered ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
        }
    }
    
    // MARK: - Interaction Overlay
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
    
    // MARK: - Time Labels View
    private var timeLabelsView: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
                    Text(formatDateLabel(dataPoint.date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(height: 30)
    }
    
    // MARK: - Selected Data Point View
    private func selectedDataPointView(_ dataPoint: TimeSeriesDataPoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(formatDate(dataPoint.date))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(formatValue(dataPoint.value))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
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
    
    // MARK: - Path Creation
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
        
        // Close the area by adding lines to bottom corners
        let lastPoint = pointPosition(for: data.last!, at: data.count - 1, in: geometry)
        path.addLine(to: CGPoint(x: lastPoint.x, y: geometry.size.height))
        
        let firstPoint = pointPosition(for: data[0], at: 0, in: geometry)
        path.addLine(to: CGPoint(x: firstPoint.x, y: geometry.size.height))
        
        path.closeSubpath()
        
        return path
    }
    
    // MARK: - Position Calculations
    private func xPosition(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        guard data.count > 1 else { return geometry.size.width / 2 }
        return CGFloat(index) * (geometry.size.width / CGFloat(data.count - 1))
    }
    
    private func yPosition(for value: Double, in geometry: GeometryProxy) -> CGFloat {
        guard valueRange > 0 else { return geometry.size.height / 2 }
        let normalizedValue = (value - minValue) / valueRange
        return geometry.size.height - (CGFloat(normalizedValue) * geometry.size.height)
    }
    
    private func pointPosition(for dataPoint: TimeSeriesDataPoint, at index: Int, in geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: xPosition(for: index, in: geometry),
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
    
    private func handleDrag(at location: CGPoint, in geometry: GeometryProxy) {
        // Find the closest data point to the drag location
        var closestDistance: CGFloat = .infinity
        var closestDataPoint: TimeSeriesDataPoint?
        
        for (index, dataPoint) in data.enumerated() {
            let pointPosition = pointPosition(for: dataPoint, at: index, in: geometry)
            let distance = sqrt(pow(location.x - pointPosition.x, 2) + pow(location.y - pointPosition.y, 2))
            
            if distance < closestDistance && distance < 30 { // 30 point threshold
                closestDistance = distance
                closestDataPoint = dataPoint
            }
        }
        
        withAnimation(.easeInOut(duration: 0.1)) {
            interactionState.hoveredDataPoint = closestDataPoint
        }
    }
    
    // MARK: - Helper Methods
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
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    let calendar = Calendar.current
    let today = Date()
    
    let sampleData = (0..<30).map { dayOffset in
        let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
        let value = Double.random(in: 50...500)
        return TimeSeriesDataPoint(date: date, value: value)
    }.reversed()
    
    VStack(spacing: 20) {
        Text("Daily Spending Trend")
            .font(.title2)
            .fontWeight(.semibold)
        
        LineChartView(data: Array(sampleData))
            .padding()
    }
    .background(Color(UIColor.systemBackground))
}