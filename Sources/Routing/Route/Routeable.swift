public protocol Routeable {
    var routeablePath: [String] { get }
}

public struct BasicRouteable: Routeable {
    public var routeablePath: [String]
    public init(_ path: [String]) {
        self.routeablePath = path
    }
}
