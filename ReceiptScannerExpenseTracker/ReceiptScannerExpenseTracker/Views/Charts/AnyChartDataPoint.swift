import Foundation
import SwiftUI

/// Type-erased wrapper for any ChartDataPoint
struct AnyChartDataPoint: Identifiable {
    let id: UUID
    let label: String
    let value: Double
    let color: Color
    private let _metadata: Any?

    init<Metadata: Equatable>(_ dataPoint: ChartDataPoint<Metadata>) {
        self.id = dataPoint.id
        self.label = dataPoint.label
        self.value = dataPoint.value
        self.color = dataPoint.color
        self._metadata = dataPoint.metadata
    }

    /// Returns the metadata cast to the specified type, if possible.
    func metadata<T>(as type: T.Type) -> T? {
        return _metadata as? T
    }
}
