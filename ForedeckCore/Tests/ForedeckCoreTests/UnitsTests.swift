import XCTest
@testable import ForedeckCore

final class UnitsTests: XCTestCase {
    func testDepthConversionsUseExactFactors() {
        XCTAssertEqual(DepthUnit.meters.value(fromMeters: 10), 10, accuracy: 1e-9)
        XCTAssertEqual(DepthUnit.feet.value(fromMeters: 0.3048), 1, accuracy: 1e-9)
        // A fathom is exactly six feet, which is what makes the sounding
        // markings on old leadlines line up.
        XCTAssertEqual(DepthUnit.fathoms.value(fromMeters: 1.8288), 1, accuracy: 1e-9)
        XCTAssertEqual(DepthUnit.fathoms.metersPerUnit, DepthUnit.feet.metersPerUnit * 6, accuracy: 1e-12)
    }

    func testDepthRoundTripsThroughEveryUnit() {
        for unit in DepthUnit.allCases {
            for meters in stride(from: 0.0, through: 100.0, by: 3.7) {
                XCTAssertEqual(unit.meters(from: unit.value(fromMeters: meters)), meters, accuracy: 1e-9)
            }
        }
    }

    func testDepthFormatting() {
        XCTAssertEqual(DepthUnit.meters.format(meters: 4.26), "4.3 m")
        XCTAssertEqual(DepthUnit.feet.format(meters: 3.048), "10 ft")
        XCTAssertEqual(DepthUnit.fathoms.format(meters: 3.6576), "2.0 fm")
    }

    func testDistanceRoundTripsAndFormats() {
        for unit in DistanceUnit.allCases {
            XCTAssertEqual(unit.meters(from: unit.value(fromMeters: 47)), 47, accuracy: 1e-9)
        }
        XCTAssertEqual(DistanceUnit.meters.format(meters: 42.4), "42 m")
        XCTAssertEqual(DistanceUnit.feet.format(meters: 30.48), "100 ft")
    }

    func testStepperMovesByOneStepAndSnapsToTheGrid() {
        let range = 0.0...200.0
        // 32 m snaps to 30, then one step up is 35.
        XCTAssertEqual(DistanceUnit.meters.adjusted(meters: 32, bySteps: 1, clampedTo: range), 35, accuracy: 1e-9)
        XCTAssertEqual(DistanceUnit.meters.adjusted(meters: 32, bySteps: -1, clampedTo: range), 25, accuracy: 1e-9)
    }

    func testStepperClampsAtBothEnds() {
        let range = 0.0...200.0
        XCTAssertEqual(DistanceUnit.meters.adjusted(meters: 0, bySteps: -1, clampedTo: range), 0)
        XCTAssertEqual(DistanceUnit.meters.adjusted(meters: 200, bySteps: 1, clampedTo: range), 200)
    }

    func testSteppingInFeetStaysOnWholeFeet() {
        let range = 0.0...200.0
        // 100 ft snaps to the nearest 15 ft grid point (105) and then steps.
        let after = DistanceUnit.feet.adjusted(meters: 30.48, bySteps: 1, clampedTo: range)  // 100 ft
        XCTAssertEqual(DistanceUnit.feet.value(fromMeters: after), 120, accuracy: 1e-6)
    }

    /// Pressing + then - must land back where it started, in either unit.
    /// Otherwise the alarm radius drifts every time somebody fiddles with it.
    func testSteppingIsReversible() {
        let range = 0.0...300.0
        for unit in DistanceUnit.allCases {
            for start in stride(from: 20.0, through: 120.0, by: 10.0) {
                let up = unit.adjusted(meters: start, bySteps: 1, clampedTo: range)
                let back = unit.adjusted(meters: up, bySteps: -1, clampedTo: range)
                XCTAssertEqual(back, unit.adjusted(meters: start, bySteps: 0, clampedTo: range), accuracy: 1e-6)
            }
        }
    }
}
