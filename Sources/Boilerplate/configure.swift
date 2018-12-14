import Vapor

public func configure(_ s: inout Services) throws {
    s.extend(HTTPRoutes.self) { r, c in
        try routes(r, c)
    }
}
