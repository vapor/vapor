import Foundation

public protocol RouteBuilder {
    associatedtype Value
    func add(
        host: String?,
        method: String?,
        path: [String],
        value: Value
    )
}

extension RouteBuilder {
    public func dynamic(
        host: String?,
        method: String?,
        path: [String],
        filter: (Value) -> (Value) = { $0 },
        closure: (DynamicRouteBuilder<Value, Self>) -> ()
    ) {
        let dynamic = DynamicRouteBuilder(builder: self, host: host, method: method, prefix: path)
        closure(dynamic)
    }

}

public class DynamicRouteBuilder<Wrapped, Builder: RouteBuilder where Builder.Value == Wrapped> {
    var builder: Builder
    var host: String?
    var method: String?
    var prefix: [String]

    init(builder: Builder, host: String?, method: String?, prefix: [String]) {
        self.builder = builder
        self.host = host
        self.method = method
        self.prefix = prefix
    }
}

extension DynamicRouteBuilder: RouteBuilder {
    public typealias Value = Wrapped

    public func add(host: String?, method: String?, path: [String], value: Value) {
        let host = self.host ?? host
        let method = self.method ?? method
        let path = self.prefix + path
        builder.add(host: host, method: method, path: path, value: value)
    }
}

extension Router: RouteBuilder {
    public typealias Value = Output

    public func add(host: String?, method: String?, path: [String], value: Value) {
        register(host: host, method: method, path: path, output: value)
    }
}
