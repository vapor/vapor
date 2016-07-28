public struct StaticRouteable: Routeable {
    public var routeablePath: [String]
    public init(_ path: [String]) {
        self.routeablePath = path
    }
}

public protocol Routeable {
    var routeablePath: [String] { get }
}
