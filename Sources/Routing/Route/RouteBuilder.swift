import Foundation

public protocol RouteBuilder {
    associatedtype Value
    func add(
        host: String,
        method: String,
        path: [String],
        handler: RouteHandler<Value>
    )
}

extension RouteBuilder {
    public func dynamic(
        host: String?,
        method: String?,
        path: [String],
        filter: (Value) -> (Value) = { $0 },
        closure: (RouteBuilderShim<Value, Self>) -> ()
    ) {
        // create the template for this
        // route that makes use of fallbacks
        var template: [String] = []
        //template += prefix
        template += path
        //template += ["*"]

        let shim = RouteBuilderShim(builder: self, host: host, method: method, prefix: path)
        closure(shim)

        /*let handler = RouteHandler<Value>.dynamic { remaining, container in
            // create a new router for registering
            // the grouped routes
            let router: Router<Value> = Router()
            closure(router)

            // cut out the path that has already been routed
            var full = prefix
            full += remaining

            // create a new routeable item from the
            // fixed path
            guard let value = router.route(path: full, with: container) else {
                return nil
            }

            // optionally filter the value
            // this is useful for injecting middleware
            return filter(value)
        }

        add(path: template, handler: handler, behavior: .wildcard)*/
    }

    public func add(path: [String], handler: RouteHandler<Value>) {
        add(host: path[0], method: path[1], path: Array(path[2..<path.count]), handler: handler)
    }
}

public class RouteBuilderShim<Wrapped, Builder: RouteBuilder where Builder.Value == Wrapped> {
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

extension RouteBuilderShim: RouteBuilder {
    public typealias Value = Wrapped

    public func add(host: String, method: String, path: [String], handler: RouteHandler<Value>) {
        let host = self.host ?? host
        let method = self.method ?? method
        let path = self.prefix + path
        builder.add(host: host, method: method, path: path, handler: handler)
    }
}

extension Router: RouteBuilder {
    public typealias Value = Wrapped

    public func add(host: String, method: String, path: [String], handler: RouteHandler<Value>) {
        var p = [host, method]
        p += path
        register(path: p, handler: handler)
    }
}
