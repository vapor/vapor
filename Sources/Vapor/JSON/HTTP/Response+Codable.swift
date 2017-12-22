import Foundation
import HTTP

#if swift(>=4.0)
public extension Encodable {
    public func makeResponse(using encoder: JSONEncoder = JSONEncoder(),
                      status: Status = .ok,
                      headers: [HeaderKey: String] = [:]) throws -> Response {
        let response = Response(status: status)
        try response.encodeJSONBody(self, using: encoder)

        headers.forEach { (key, value) in
            response.headers[key] = value
        }

        return response
    }
}
#endif
