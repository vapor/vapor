import XCTest
import Development

open class XCTVaporTestCase: XCTestCase {
    open var app: Application!
    open var client: SpyClient!
    
    open override func setUpWithError() throws {
        try super.setUpWithError()
        
        app = Application(.testing)
        
        client = SpyClient(
            eventLoop: app.eventLoopGroup.next()
        )

        app.clients.use { [unowned self] _ in
            return self.client
        }
        
        try configure(app)
    }

    open override func tearDownWithError() throws {
        client = nil
        
        app.shutdown()
        app = nil

        try super.tearDownWithError()
    }
}
