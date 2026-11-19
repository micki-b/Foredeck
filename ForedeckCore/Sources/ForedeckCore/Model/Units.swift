import Foundation

/// Display units.
///
/// Everything is stored in metres throughout the app, matching Signal K, and
/// converted only at the edges -- on screen and at the steppers. Storing what
/// the user last looked at would mean the wire format and the anchor state
/// changed meaning depending on a preference, which is a good way to lose a
/// boat.
public enum DepthUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case meters
    case feet
    case fathoms

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .meters: return "Meters"
        case .feet: return "Feet"
        case .fathoms: return "Fathoms"
        }
    }

    public var abbreviation: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        case .fathoms: return "fm"
        }
    }

    public var metersPerUnit: Double {
        switch self {
        case .meters: return 1.0
        case .feet: return 0.3048
        case .fathoms: return 1.8288  // exactly six feet
        }
    }

    public func value(fromMeters meters: Double) -> Double {
        meters / metersPerUnit
    }

    public func meters(from value: Double) -> Double {
        value * metersPerUnit
    }

    /// Feet get no decimal: at 30 ft under the keel the tenth of a foot is
    /// noise, and a shorter number is quicker to read.
    public var fractionDigits: Int {
        self == .feet ? 0 : 1
    }

    public func format(meters: Double) -> String {
        let number = String(format: "%.\(fractionDigits)f", value(fromMeters: meters))
        return "\(number) \(abbreviation)"
    }
}

/// Horizontal distances: rode paid out, alarm radius, distance from the anchor.
/// Fathoms deliberately absent -- nobody measures a swing circle in fathoms.
public enum DistanceUnit: String, Codable, CaseIterable, Sendable, Identifiable {
    case meters
    case feet

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .meters: return "Meters"
        case .feet: return "Feet"
        }
    }

    public var abbreviation: String {
        switch self {
        case .meters: return "m"
        case .feet: return "ft"
        }
    }

    public var metersPerUnit: Double {
        switch self {
        case .meters: return 1.0
        case .feet: return 0.3048
        }
    }

    /// One press of a stepper. 5 m and 15 ft are both roughly "a bit more
    /// rode", which keeps the control feeling the same in either unit.
    public var step: Double {
        switch self {
        case .meters: return 5
        case .feet: return 15
        }
    }

    public func value(fromMeters meters: Double) -> Double {
        meters / metersPerUnit
    }

    public func meters(from value: Double) -> Double {
        value * metersPerUnit
    }

    public func format(meters: Double) -> String {
        let number = String(format: "%.0f", value(fromMeters: meters))
        return "\(number) \(abbreviation)"
    }

    /// Move by whole steps, snapping to the step grid first so repeated
    /// pressing does not accumulate the rounding error of unit conversion.
    public func adjusted(
        meters: Double,
        bySteps steps: Double,
        clampedTo range: ClosedRange<Double>
    ) -> Double {
        let snapped = (value(fromMeters: meters) / step).rounded() * step
        let moved = snapped + steps * step
        return min(max(self.meters(from: moved), range.lowerBound), range.upperBound)
    }
}
