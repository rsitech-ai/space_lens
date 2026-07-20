import SwiftUI

extension SafetyLevel {
    var color: Color {
        switch self {
        case .safeTemp:
            .green
        case .rebuildableCache:
            .teal
        case .generatedOutput:
            .blue
        case .largeButValuable:
            .purple
        case .activeOrInUse:
            .orange
        case .systemCritical:
            .red
        case .unknownReview:
            .secondary
        }
    }
}
