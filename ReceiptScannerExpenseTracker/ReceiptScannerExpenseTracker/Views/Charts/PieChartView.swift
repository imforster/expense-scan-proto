import SwiftUI

/// Reusable pie chart component with interactive elements
struct PieChartView: View {
    let data: [FlexibleChartDataPoint]
    let configuration: ChartConfiguration
    @State private var interactionState = FlexibleChartInteractionState()
    @State private var animationProgress: Double = 0
    
    private let totalValue: Double
    private let chartSize: CGFloat = 200
    
    init(data: [FlexibleChartDataPoint], configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data
        self.configuration = configuration
        self.totalValue = data.reduce(0) { $0 + $1.value }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                // Pie chart
                pieChartView
                
                // Legend
                if configuration.showLegend {
                    legendView
                }
            }
            
            // Selected data point details
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
    
    // MARK: - Pie Chart View
    private var pieChartView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.gray.opacity(0.1))
                .frame(width: chartSize, height: chartSize)
            
            // Pie slices
            ForEach(Array(pieSlices.enumerated()), id: \.element.id) { index, slice in
                pieSliceView(slice: slice, index: index)
            }
            
            // Center circle for donut effect
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: chartSize * 0.5, height: chartSize * 0.5)
            
            // Center content
            centerContentView
        }
        .frame(width: chartSize, height: chartSize)
    }
    
    // MARK: - Pie Slice View
    private func pieSliceView(slice: PieSlice, index: Int) -> some View {
        let isSelected = interactionState.selectedDataPoint?.id == slice.dataPoint.id
        let isHovered = interactionState.hoveredDataPoint?.id == slice.dataPoint.id
        let scale: CGFloat = isSelected ? 1.1 : (isHovered ? 1.05 : 1.0)
        
        return PieSliceShape(
            startAngle: .degrees(slice.startAngle * animationProgress),
            endAngle: .degrees(slice.endAngle * animationProgress)
        )
        .fill(
            RadialGradient(
                gradient: Gradient(colors: [
                    slice.dataPoint.color.opacity(0.9),
                    slice.dataPoint.color
                ]),
                center: .center,
                startRadius: chartSize * 0.25,
                endRadius: chartSize * 0.5
            )
        )
        .scaleEffect(scale)
        .shadow(
            color: slice.dataPoint.color.opacity(0.3),
            radius: isSelected ? 8 : (isHovered ? 4 : 2),
            x: 0,
            y: isSelected ? 4 : (isHovered ? 2 : 1)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onTapGesture {
            if configuration.interactionEnabled {
                handleTap(on: slice.dataPoint)
            }
        }
        .onHover { isHovering in
            if configuration.interactionEnabled {
                handleHover(on: slice.dataPoint, isHovering: isHovering)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(slice.dataPoint.label): \(formatValue(slice.dataPoint.value)), \(formatPercentage(slice.percentage))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to select this segment")
    }
    
    // MARK: - Center Content View
    private var centerContentView: some View {
        VStack(spacing: 4) {
            if let selectedPoint = interactionState.selectedDataPoint {
                Text(formatValue(selectedPoint.value))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedPoint.color)
                
                Text(formatPercentage(selectedPoint.value / totalValue))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(formatValue(totalValue))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: interactionState.selectedDataPoint?.id)
    }
    
    // MARK: - Legend View
    private var legendView: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(data, id: \.id) { dataPoint in
                legendItemView(for: dataPoint)
            }
        }
        .frame(maxWidth: 120)
    }
    
    private func legendItemView(for dataPoint: FlexibleChartDataPoint) -> some View {
        let isSelected = interactionState.selectedDataPoint?.id == dataPoint.id
        let percentage = dataPoint.value / totalValue
        
        return HStack(spacing: 8) {
            Circle()
                .fill(dataPoint.color)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dataPoint.label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(.primary)
                
                if configuration.showValues {
                    HStack(spacing: 4) {
                        Text(formatValue(dataPoint.value))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("(\(formatPercentage(percentage)))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
        .opacity(isSelected || interactionState.selectedDataPoint == nil ? 1.0 : 0.6)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            if configuration.interactionEnabled {
                handleTap(on: dataPoint)
            }
        }
    }
    
    // MARK: - Selected Data Point View
    private func selectedDataPointView(_ dataPoint: FlexibleChartDataPoint) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(dataPoint.color)
                .frame(width: 16, height: 16)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dataPoint.label)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Text(formatValue(dataPoint.value))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(dataPoint.color)
                    
                    Text("(\(formatPercentage(dataPoint.value / totalValue)))")
                        .font(.subheadline)
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
    private var pieSlices: [PieSlice] {
        var slices: [PieSlice] = []
        var currentAngle: Double = -90 // Start from top
        
        for dataPoint in data {
            let percentage = dataPoint.value / totalValue
            let sliceAngle = percentage * 360
            
            let slice = PieSlice(
                dataPoint: dataPoint,
                startAngle: currentAngle,
                endAngle: currentAngle + sliceAngle,
                percentage: percentage
            )
            
            slices.append(slice)
            currentAngle += sliceAngle
        }
        
        return slices
    }
    
    // MARK: - Interaction Handlers
    private func handleTap(on dataPoint: FlexibleChartDataPoint) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if interactionState.selectedDataPoint?.id == dataPoint.id {
                interactionState.clearInteraction()
            } else {
                interactionState.selectDataPoint(dataPoint)
            }
        }
    }
    
    private func handleHover(on dataPoint: FlexibleChartDataPoint, isHovering: Bool) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if isHovering {
                interactionState.hoverDataPoint(dataPoint)
            } else {
                interactionState.hoverDataPoint(nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "0%"
    }
}

// MARK: - Supporting Types
private struct PieSlice: Identifiable {
    let id = UUID()
    let dataPoint: FlexibleChartDataPoint
    let startAngle: Double
    let endAngle: Double
    let percentage: Double
}

private struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let innerRadius = radius * 0.5 // For donut effect
        
        var path = Path()
        
        // Outer arc
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        // Line to inner arc start
        let innerStartPoint = CGPoint(
            x: center.x + innerRadius * Foundation.cos(endAngle.radians),
            y: center.y + innerRadius * Foundation.sin(endAngle.radians)
        )
        path.addLine(to: innerStartPoint)
        
        // Inner arc (reverse direction)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )
        
        // Close the path
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [FlexibleChartDataPoint] = [
        FlexibleChartDataPoint(label: "Food", value: 450.0, color: .blue, flexibleMetadata: ["test": "value"]),
        FlexibleChartDataPoint(label: "Transport", value: 320.0, color: .green, flexibleMetadata: ["test": "value"]),
        FlexibleChartDataPoint(label: "Shopping", value: 280.0, color: .orange, flexibleMetadata: ["test": "value"]),
        FlexibleChartDataPoint(label: "Entertainment", value: 150.0, color: .red, flexibleMetadata: ["test": "value"]),
        FlexibleChartDataPoint(label: "Health", value: 200.0, color: .purple, flexibleMetadata: ["test": "value"])
    ]
    
    VStack(spacing: 20) {
        Text("Monthly Spending Distribution")
            .font(.title2)
            .fontWeight(.semibold)
        
        PieChartView(data: sampleData)
            .padding()
    }
    .background(Color(.systemBackground))
}
