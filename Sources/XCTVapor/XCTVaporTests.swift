public var app: (() throws -> Application) = {
    fatalError("implement static app generator")
}

open class XCTVaporTests: XCTestCase {
    open var app: Application!
    
    open override func setUp() {
        super.setUp()
        self.app = try! XCTVapor.app()
    }
    
    open override func tearDown() {
        super.tearDown()
        try! self.app.shutdown()
    }
}
