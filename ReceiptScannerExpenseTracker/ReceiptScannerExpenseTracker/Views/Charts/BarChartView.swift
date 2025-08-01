import SwiftUI

/// Reusable bar chart component with interactive elements
struct BarChartView: View {
    let data: [FlexibleChartDataPoint]
    let configuration: ChartConfiguration
    @State private var interactionState = FlexibleChartInteractionState()
    @State private var animationProgress: Double = 0
    
    private let maxValue: Double
    private let chartHeight: CGFloat = 200
    
    init(data: [FlexibleChartDataPoint], configuration: ChartConfiguration = ChartConfiguration()) {
        self.data = data
        self.configuration = configuration
        self.maxValue = data.map(\.value).max() ?? 1.0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if configuration.showLegend {
                legendView
            }
            
            chartView
            
            if configuration.showLabels {
                labelsView
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
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, dataPoint in
                    barView(for: dataPoint, at: index, in: geometry)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: chartHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    // MARK: - Bar View
    private func barView(for dataPoint: FlexibleChartDataPoint, at index: Int, in geometry: GeometryProxy) -> some View {
        let barWidth = calculateBarWidth(geometry: geometry)
        let barHeight = CGFloat(dataPoint.value / maxValue) * chartHeight * animationProgress
        let isSelected = interactionState.selectedDataPoint?.id == dataPoint.id
        let isHovered = interactionState.hoveredDataPoint?.id == dataPoint.id
        
        return VStack(spacing: 4) {
            // Value label on top of bar
            if configuration.showValues && (isSelected || isHovered || !configuration.interactionEnabled) {
                Text(formatValue(dataPoint.value))
                    .font(.caption2)
                    .foregroundColor(.primary)
                    .opacity(isSelected || isHovered || !configuration.interactionEnabled ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            
            Spacer()
            
            // Bar
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            dataPoint.color,
                            dataPoint.color.opacity(0.7)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: barWidth, height: barHeight)
                .scaleEffect(isSelected ? 1.05 : (isHovered ? 1.02 : 1.0))
                .shadow(
                    color: dataPoint.color.opacity(0.3),
                    radius: isSelected ? 8 : (isHovered ? 4 : 2),
                    x: 0,
                    y: isSelected ? 4 : (isHovered ? 2 : 1)
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .onTapGesture {
                    if configuration.interactionEnabled {
                        handleTap(on: dataPoint)
                    }
                }
                .onHover { isHovering in
                    if configuration.interactionEnabled {
                        handleHover(on: dataPoint, isHovering: isHovering)
                    }
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dataPoint.label): \(formatValue(dataPoint.value))")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to select this data point")
    }
    
    // MARK: - Legend View
    private var legendView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(data, id: \.id) { dataPoint in
                    legendItemView(for: dataPoint)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    private func legendItemView(for dataPoint: FlexibleChartDataPoint) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(dataPoint.color)
                .frame(width: 12, height: 12)
            
            Text(dataPoint.label)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .opacity(interactionState.selectedDataPoint?.id == dataPoint.id || interactionState.selectedDataPoint == nil ? 1.0 : 0.5)
        .onTapGesture {
            if configuration.interactionEnabled {
                handleTap(on: dataPoint)
            }
        }
    }
    
    // MARK: - Labels View
    private var labelsView: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 4) {
                ForEach(data, id: \.id) { dataPoint in
                    Text(dataPoint.label)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
    }
    
    // MARK: - Helper Methods
    
    private func calculateBarWidth(geometry: GeometryProxy) -> CGFloat {
        guard data.count > 0 else { return 0 }
        let totalSpacing = CGFloat(data.count - 1) * 4
        let availableWidth = geometry.size.width - 16 - totalSpacing
        return availableWidth / CGFloat(data.count)
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
    
    private func formatValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$0"
    }
}

// MARK: - Preview

#Preview {
    let sampleData: [ChartDataPoint<String>] = [
        ChartDataPoint(label: "Food", value: 450.0, color: .blue, metadata: "Test"),
        ChartDataPoint(label: "Transport", value: 320.0, color: .green, metadata: "Test"),
        ChartDataPoint(label: "Shopping", value: 280.0, color: .orange, metadata: "Test"),
        ChartDataPoint(label: "Entertainment", value: 150.0, color: .red, metadata: "Test"),
        ChartDataPoint(label: "Health", value: 200.0, color: .purple, metadata: "Test")
    ]
    
    VStack(spacing: 20) {
        Text("Monthly Spending by Category")
            .font(.title2)
            .fontWeight(.semibold)
        
        BarChartView(data: sampleData.map { ChartDataPoint(label: $0.label, value: $0.value, color: $0.color, metadata: [:]) })
            .padding()
    }
    .background(Color(UIColor.systemBackground))
}
