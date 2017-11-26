import Async
import HTTP
import Service

/// Capable of being used as a route parameter.
///
/// [Learn More →](https://docs.vapor.codes/3.0/routing/parameters/#creating-custom-parameters)
public protocol Parameter {
    /// the type of this parameter after it has been resolved.
    associatedtype ResolvedParameter

    /// the unique key to use as a slug in route building
    static var uniqueSlug: String { get }

    // returns the found model for the resolved url parameter
    static func make(for parameter: String, in request: Request) throws -> ResolvedParameter
}

extension Parameter {
    /// The path component for this route parameter
    public static var parameter: PathComponent {
        return .parameter(uniqueSlug)
    }
}

extension Parameter {
    /// See Parameter.uniqueSlug
    public static var uniqueSlug: String {
        return "\(Self.self)"
    }
}

extension Parameter where Self: EphemeralWorkerFindable {
    /// See Parameter.make
    public static func make(for parameter: String, in request: Request) throws -> EphemeralWorkerFindableResult {
        return try find(identifier: parameter, for: request)
    }
}
