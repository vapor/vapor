public var app: (() throws -> Application)!

open class XCTVaporTests: XCTestCase {
    open var app: Application!

    open override func setUp() {
        super.setUp()
        if self.app == nil, let _app = XCTVapor.app {
            // this was the behavior of this class pre 4.41.5
            // keeping for compatability
            self.app = try! _app()
        } else {
            fatalError("implement static app generator")
        }
    }
    
    open override func setUpWithError() throws {
        try super.setUpWithError()
        if let _app = XCTVapor.app {
            self.app = try _app()
        }
    }
    
    open override func tearDown() {
        super.tearDown()
        self.app?.shutdown()
        self.app = nil
    }
}
