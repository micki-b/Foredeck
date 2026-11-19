import XCTest
@testable import ForedeckCore

final class GeoTests: XCTestCase {
    func testOneDegreeOfLongitudeAtTheEquator() {
        let distance = Geo.distance(
            from: GeoPoint(latitude: 0, longitude: 0),
            to: GeoPoint(latitude: 0, longitude: 1)
        )
        XCTAssertEqual(distance, 111_195, accuracy: 5)
    }

    func testZeroDistanceToSelf() {
        let point = GeoPoint(latitude: 54.32, longitude: 10.12)
        XCTAssertEqual(Geo.distance(from: point, to: point), 0, accuracy: 1e-6)
    }

    func testDistanceIsSymmetric() {
        let a = GeoPoint(latitude: 54.32, longitude: 10.12)
        let b = GeoPoint(latitude: 54.33, longitude: 10.14)
        XCTAssertEqual(Geo.distance(from: a, to: b), Geo.distance(from: b, to: a), accuracy: 1e-6)
    }

    func testCardinalBearings() {
        let origin = GeoPoint(latitude: 0, longitude: 0)
        XCTAssertEqual(Geo.bearing(from: origin, to: GeoPoint(latitude: 1, longitude: 0)), 0, accuracy: 0.01)
        XCTAssertEqual(Geo.bearing(from: origin, to: GeoPoint(latitude: 0, longitude: 1)), 90, accuracy: 0.01)
        XCTAssertEqual(Geo.bearing(from: origin, to: GeoPoint(latitude: -1, longitude: 0)), 180, accuracy: 0.01)
    }

    func testWesterlyBearingIsNormalisedIntoRange() {
        let bearing = Geo.bearing(
            from: GeoPoint(latitude: 0, longitude: 0),
            to: GeoPoint(latitude: 0, longitude: -1)
        )
        XCTAssertEqual(bearing, 270, accuracy: 0.01)
    }

    /// Bearings live on a circle, so 359.999999 and 0.0 are the same heading a
    /// hair apart. Comparing them as plain numbers fails at due north for a
    /// rounding error of 1e-10 degrees, which is a bug in the assertion rather
    /// than in the arithmetic.
    private func angularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        let difference = abs(lhs - rhs).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    func testOffsetThenMeasureReturnsTheOriginalDistance() {
        let origin = GeoPoint(latitude: 54.32, longitude: 10.12)
        for bearing in stride(from: 0.0, to: 360.0, by: 45.0) {
            let moved = Geo.offset(from: origin, bearingDegrees: bearing, distanceMeters: 100)
            XCTAssertEqual(Geo.distance(from: origin, to: moved), 100, accuracy: 0.01)
            XCTAssertEqual(angularDifference(Geo.bearing(from: origin, to: moved), bearing), 0, accuracy: 0.01)
        }
    }

    /// Swing-circle scale, at a latitude the app will actually be used at.
    func testAnchorScaleAccuracy() {
        let drop = GeoPoint(latitude: 54.32, longitude: 10.12)
        let moved = Geo.offset(from: drop, bearingDegrees: 137, distanceMeters: 45)
        XCTAssertEqual(Geo.distance(from: drop, to: moved), 45, accuracy: 0.01)
    }

    func testUnitConversions() {
        XCTAssertEqual(Geo.metersToFeet(1), 3.2808, accuracy: 1e-3)
        XCTAssertEqual(Geo.metersToNauticalMiles(1852), 1, accuracy: 1e-9)
    }
}
