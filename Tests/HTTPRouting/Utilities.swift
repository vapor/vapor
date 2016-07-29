import XCTest
import HTTP
import HTTPRouting

extension Request {
    convenience init(method: HTTPMethod, path: String, host: String = "0.0.0.0") {
        let uri = URI(host: host, path: path)
        self.init(method: method, uri: uri)
    }

    enum BytesError: Error {
        case routingFailed
        case invalidResponse
    }

    func bytes(running router: Router) throws -> Bytes {
        guard let responder = router.route(self) else {
            throw BytesError.routingFailed
        }

        guard let bytes = try responder.respond(to: self).body.bytes else {
            throw BytesError.invalidResponse
        }

        return bytes
    }
}
