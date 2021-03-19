/**
 We recommend configuring this in your test’s `class func setUp()`
 */
public var app: (() throws -> Application)!

open class XCTVaporTests: XCTestCase {
    open var app: Application!

    open override func setUpWithError() throws {

        // The XCTest runner calls this function before setUp()

        try super.setUpWithError()

        // this optional check due to prior usage by users
        // see: https://github.com/vapor/vapor/pull/2585#issuecomment-802144636
        if let _app = XCTVapor.app {
            self.app = try _app()
        }
    }

    open override func setUp() {

        // The XCTest runner calls this after setupWithError()

        super.setUp()

        guard let _app = XCTVapor.app else {
            fatalError("implement static app generator")
        }

        if self.app == nil {
            self.app = try! _app()
        }
    }

    open override func tearDown() {
        super.tearDown()
        self.app?.shutdown()
        self.app = nil
    }
}
