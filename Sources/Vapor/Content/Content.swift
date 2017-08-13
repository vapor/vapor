import Core
import Foundation
import HTTP
import Transport

public protocol ContentDecodable {
    static func decodeContent(from message: Message) throws -> Self
}

public protocol ContentEncodable {
    func encodeContent(to message: Message) throws
}

public typealias ContentCodable = ContentDecodable & ContentEncodable


extension Message {
    public func content<C: ContentEncodable>(_ content: C) throws {
        try content.encodeContent(to: self)
    }

    public func content<C: ContentDecodable>(_ content: C.Type) throws -> C {
        return try C.decodeContent(from: self)
    }
}

extension ContentEncodable where Self: JSONEncodable {
    public func encodeContent(to message: Message) throws {
        let json = "\(self)"
        message.body = .data(json.makeBytes())
        message.headers[.contentType] = "application/json"
    }
}

extension ContentDecodable where Self: JSONDecodable {
    public static func decodeContent(from message: Message) throws -> Self {
        // FIXME: mediatype
        guard message.contentType?.contains("application/json") == true else {
            throw "needs to be json"
        }

        let data = Data(message.body.bytes!)
        return try self.init(json: data)
    }
}

public protocol ResponseEncodable: ResponseRepresentable {
    func encodeResponse(to stream: Transport.Stream) throws
}


extension ResponseEncodable where Self: ContentEncodable {
    public func encodeResponse(to stream: Transport.Stream) throws {
        var res = try makeResponse()
        // send on stream

    }

    public func makeResponse() throws -> Response {
        let res = Response(status: .ok)
        try res.content(self)
        return res
    }
}

//import PathIndexable
//import Node
//
//public protocol RequestContentSubscript {}
//
//extension String: RequestContentSubscript { }
//extension Int: RequestContentSubscript {}
//
///// The data received from the request in json body or url query
/////
///// Can be extended by third party droplets and middleware
//public final class Content {
//
//    public typealias ContentLoader = ([PathIndexer]) -> Node?
//
//    // MARK: Initialization
//
//    private var content: [ContentLoader] = []
//
//    public init() {}
//
//    // Some closure weirdness to allow more complex capturing or lazy loading internally
//
//    public func append<W: StructuredDataWrapper>(_ element: @escaping () -> W?) {
//        let finder: ContentLoader = { indexes in
//            guard let w = element()?[indexes] else { return nil }
//            return Node(w)
//        }
//        content.append(finder)
//    }
//
//    public func append(_ element: @escaping ContentLoader) {
//        content.append(element)
//    }
//
//    public func append<W: StructuredDataWrapper>(_ element: W?) {
//        guard let element = element else { return }
//        let finder: ContentLoader = { indexes in
//            guard let w = element[indexes] else { return nil }
//            return Node(w)
//        }
//        content.append(finder)
//    }
//
//    // MARK: Subscripting
//
//    public subscript(indexes: PathIndexer...) -> Node? {
//        return self[indexes]
//    }
//
//    public subscript(indexes: [PathIndexer]) -> Node? {
//        return content.lazy.flatMap { loader in loader(indexes) } .first
//    }
//}
//
//extension Content {
//    public func get<T : NodeInitializable>(
//        _ indexers: PathIndexer...)
//        throws -> T {
//            return try get(indexers)
//    }
//
//    public func get<T : NodeInitializable>(
//        _ indexers: [PathIndexer])
//        throws -> T {
//            let value = self[indexers] ?? .null
//            return try T(node: value)
//    }
//}

