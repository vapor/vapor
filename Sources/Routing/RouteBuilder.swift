import Foundation

public protocol RouteBuilder {
    associatedtype Value

    func add(path: [String], value: Value)
}

extension Router: RouteBuilder {
    public typealias Value = Output

    public func add(path: [String], value: Value) {
        register(path: path, output: value)
    }
}
