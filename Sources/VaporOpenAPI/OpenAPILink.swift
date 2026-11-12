#if OpenAPI
import OpenAPIKit

/// A type that ties the two ends of an OpenAPI link together.
///
/// Declare one per kind of value you pass between operations, such as `enum UserID: OpenAPILinkKey {}`.
/// Operations that use the same key are linked: where it's in a response, to where it's in a request.
public protocol OpenAPILinkKey: Sendable {
    /// A description of the link, shown in the generated document.
    ///
    /// Declare it as `static var description: String?`. A non-optional `String` compiles but
    /// doesn't satisfy this requirement, so the default `nil` is used instead.
    static var description: String? { get }
}

extension OpenAPILinkKey {
    public static var description: String? { nil }

    static var linkKeyID: LinkKeyID {
        LinkKeyID(type: Self.self)
    }
}

/// A key type, compared by identity so links can be grouped by the key they share.
struct LinkKeyID: Hashable, Sendable {
    var type: any OpenAPILinkKey.Type

    func hash(into hasher: inout Hasher) {
        ObjectIdentifier(type).hash(into: &hasher)
    }

    static func == (_ lhs: Self, _ rhs: Self) -> Bool {
        lhs.type == rhs.type
    }
}

/// One end of an OpenAPI link: a value called `name`, found at `location`.
///
/// A link's source is a response location, such as the `id` in a response body. Its target is a
/// request location, such as the `userId` path parameter of another operation.
public struct OpenAPILink: Hashable, Sendable {
    /// The value's name: a parameter or header name, or a field in the body.
    ///
    /// In a body, `/` reaches into nested fields, such as `data/id`, and an empty name refers to
    /// the whole body.
    public var name: String

    /// Where the value is found.
    public var location: Location

    /// The key the link is stored under in `components.links`, such as `ResponseBodyId`.
    var identifier: String {
        "\(location.description).\(name)"
            .split(omittingEmptySubsequences: false) { $0 == "." || $0 == "/" }
            .map { String($0).upFirst }
            .joined()
            .componentKeySafe
    }

    /// The runtime expression that reads this value, such as `$response.body#/id`.
    ///
    /// `nil` for a cookie: runtime expressions can't read cookies, so a cookie can only be a target.
    var expression: OpenAPI.RuntimeExpression? {
        switch location {
        case .request(let location):
            switch location {
            case .query: .request(.query(name: name))
            case .header: .request(.header(name: name))
            case .path: .request(.path(name: name))
            case .cookie: nil
            case .body: .request(.body(bodyReference))
            }
        case .response(let location):
            switch location {
            case .header: .response(.header(name: name))
            case .body: .response(.body(bodyReference))
            }
        }
    }

    /// A JSON pointer to the field called `name`, or `nil` for the whole body.
    private var bodyReference: JSONReference<JSONSchema>.InternalReference? {
        name.isEmpty ? nil : .path(.init(rawValue: name))
    }

    /// Creates a link end for the value called `name` at `location`.
    public init(_ name: String, in location: Location) {
        self.name = name
        self.location = location
    }
}

extension OpenAPILink {
    /// Where a linked value is found, in a request or a response.
    public enum Location: Hashable, Sendable, CustomStringConvertible {
        case request(RequestLocation)
        case response(ResponseLocation)

        /// The location as written in a runtime expression, such as `response.body`.
        public var description: String {
            switch self {
            case .request(let location): return "request.\(location.rawValue)"
            case .response(let location): return "response.\(location.rawValue)"
            }
        }
    }

    /// Where a linked value is found in a request.
    public enum RequestLocation: String, Sendable {
        case query
        case header
        case path
        case cookie
        case body
    }

    /// Where a linked value is found in a response.
    public enum ResponseLocation: String, Sendable {
        case header
        case body
    }
}

#endif
