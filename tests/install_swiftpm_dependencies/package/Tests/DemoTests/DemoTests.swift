import XCTest
@testable import Demo

final class DemoTests: XCTestCase {
    func testHello() throws {
        XCTAssertEqual(Demo.sayHello(), "Hello, world!")
    }
}
