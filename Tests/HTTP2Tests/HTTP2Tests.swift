import XCTest
@testable import HTTP2
import Async

public class HTTP2Tests: XCTestCase {
    static let allTests = [
        ("testClient", testClient)
    ]
    
    func testClient() throws {
        let queue = DispatchQueue(label: "http2.client")
        
        let client = try HTTP2Client.connect(hostname: "google.com", worker: Worker(queue: queue)).blockingAwait()
    }
}
