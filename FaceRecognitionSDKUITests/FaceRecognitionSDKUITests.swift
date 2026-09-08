import XCTest

final class FaceRecognitionSDKUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Face Recognition"].waitForExistence(timeout: 10))
    }
}
