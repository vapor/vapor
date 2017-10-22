import XCTest
import HTTP
@testable import HTTP2
import Async

public class HTTP2Tests: XCTestCase {
    static let allTests = [
        ("testClient", testClient)
    ]
    
    func testClient() throws {
        let queue = DispatchQueue(label: "http2.client")
        let worker = Worker(queue: queue)
        
        let response = try HTTP2Client.connect(hostname: "google.com", worker: worker).flatten { client -> Future<Response> in
            let request = Request(method: .get, uri: "/", headers: [
                :
            ], body: Body())
            
            return try client.send(request)
        }.blockingAwait()
        
        print(response)
    }
}
