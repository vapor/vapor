import Foundation

public protocol Controller {
    init()
    static var middleware: [Middleware.Type] { get }
}

extension Controller {
    public static var middleware: [Middleware.Type] {
        return []
    }
}

