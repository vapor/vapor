public var app: (() throws -> Application) = {
    fatalError("implement static app generator")
}

open class XCTVaporTests: XCTestCase {
    open var app: Application!
    
    open override func setUpWithError() throws {
        super.setUp()
        self.app = try XCTVapor.app()
    }
    
    open override func tearDown() {
        super.tearDown()
        self.app?.shutdown()
        app = nil
    }
}
