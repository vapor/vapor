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
    public func group(
        host: String?,
        method: String?,
        path: [String],
        filter: ((Value) -> (Value))?,
        closure: (GroupRouteBuilder<Value, Self>) -> ()
    ) {
        let group = grouped(host: host, method: method, path: path, filter: filter)
        closure(group)
    }

    public func grouped(
        host: String?,
        method: String?,
        path: [String],
        filter: ((Value) -> (Value))?
    ) -> GroupRouteBuilder<Value, Self> {
         return GroupRouteBuilder(
            builder: self,
            host: host,
            method: method,
            prefix: path,
            filter: filter
        )
    }
}

public class GroupRouteBuilder<Wrapped, Builder: RouteBuilder where Builder.Value == Wrapped> {
    public typealias Filter = (Value) -> (Value)

    public let builder: Builder
    public let host: String?
    public let method: String?
    public let prefix: [String]
    public let filter: Filter?

    init(
        builder: Builder,
        host: String?,
        method: String?,
        prefix: [String],
        filter: Filter?
    ) {
        self.builder = builder
        self.host = host
        self.method = method
        self.prefix = prefix
        self.filter = filter
    }
}

extension GroupRouteBuilder: RouteBuilder {
    public typealias Value = Wrapped

    public func add(host: String?, method: String?, path: [String], value: Value) {
        let host = self.host ?? host
        let method = self.method ?? method
        let path = self.prefix + path
        var value = value
        if let filter = filter {
            value = filter(value)
        }
        builder.add(host: host, method: method, path: path, value: value)
    }
}

extension Router: RouteBuilder {
    public typealias Value = Output

    public func add(host: String?, method: String?, path: [String], value: Value) {
        register(host: host, method: method, path: path, output: value)
    }
}
