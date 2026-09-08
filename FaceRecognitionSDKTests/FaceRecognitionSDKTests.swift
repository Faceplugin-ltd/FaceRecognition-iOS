import XCTest
@testable import FaceRecognitionSDK

final class FaceRecognitionSDKTests: XCTestCase {
    func testAppSettingsDefaults() {
        AppSettings.restoreDefaults()
        XCTAssertTrue(AppSettings.useFrontCamera)
        XCTAssertEqual(AppSettings.livenessThreshold, 0.5, accuracy: 0.001)
        XCTAssertEqual(AppSettings.identifyThreshold, 0.67, accuracy: 0.001)
        XCTAssertEqual(AppSettings.livenessLevel, 0)
        XCTAssertEqual(AppSettings.yawThreshold, 40, accuracy: 0.001)
        XCTAssertEqual(AppSettings.rollThreshold, 40, accuracy: 0.001)
        XCTAssertEqual(AppSettings.pitchThreshold, 40, accuracy: 0.001)
        XCTAssertEqual(AppSettings.eyecloseThreshold, 0.5, accuracy: 0.001)
    }

    func testUseFrontCameraBackLens() {
        AppSettings.restoreDefaults()
        AppSettings.useFrontCamera = false
        XCTAssertFalse(AppSettings.useFrontCamera)
        AppSettings.useFrontCamera = true
        XCTAssertTrue(AppSettings.useFrontCamera)
    }

    func testLivenessPassed() {
        AppSettings.restoreDefaults()
        XCTAssertFalse(AppSettings.livenessPassed(score: 0.99, label: "spoof"))
        XCTAssertFalse(AppSettings.livenessPassed(score: 0.99, label: "Fake"))
        XCTAssertTrue(AppSettings.livenessPassed(score: 0.5, label: "real"))
        XCTAssertFalse(AppSettings.livenessPassed(score: 0.49, label: nil))
    }
}
