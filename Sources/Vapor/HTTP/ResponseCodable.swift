//import HTTP
import Foundation

/// Can be converted from a response.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responseinitializable)
public protocol ResponseDecodable {
    static func decode(from res: Response, for req: Request) throws -> Future<Self>
}

/// Can be converted to a response
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/response/#responserepresentable)
public protocol ResponseEncodable {
    /// Makes a response using the context provided by the HTTPRequest
    func encode(for req: Request) throws -> Future<Response>
}

/// Can be converted from and to a response
public typealias ResponseCodable = ResponseDecodable & ResponseEncodable

// MARK: Response Conformance

extension Response: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(for req: Request) throws -> Future<Response> {
        return Future.map(on: req) { self }
    }
}

//extension HTTPResponse: ResponseEncodable {
//    /// See ResponseRepresentable.makeResponse
//    public func encode(for req: Request) throws -> Future<Response> {
//        let new = req.makeResponse()
//        new.http = self
//        return Future(new)
//    }
//}
//
//extension HTTPStatus: ResponseEncodable {
//    /// See ResponseRepresentable.makeResponse
//    public func encode(for req: Request) throws -> Future<Response> {
//        let new = req.makeResponse()
//        new.http = HTTPResponse(status: self)
//        return Future(new)
//    }
//}

extension StaticString: ResponseEncodable {
    /// See ResponseRepresentable.makeResponse
    public func encode(for req: Request) throws -> Future<Response> {
        let new = req.makeResponse()
        new.http.headers.replaceOrAdd(name: .contentType, value: "text/plain; charset=utf-8")
        new.http.body = HTTPBody(staticString: self)
        return Future.map(on: req) { new }
    }
}
