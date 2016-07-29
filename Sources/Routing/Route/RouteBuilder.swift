import Foundation

public protocol RouteBuilder {
    associatedtype Value
    func add(path: [String], handler: RouteHandler<Value>)
}

extension RouteBuilder {
    public func dynamic(
        prefix: [String],
        path: [String],
        filter: (Value) -> (Value) = { $0 },
        closure: (Router<Value>) -> ()
    ) {
        // create the template for this
        // route that makes use of fallbacks
        var template: [String] = []
        template += prefix
        template += path
        template += ["*"]

        let handler = RouteHandler<Value>.dynamic { routeable, container in
            // create a new router for registering
            // the grouped routes
            let router: Router<Value> = Router()
            closure(router)

            // cut out the path that has already been routed
            var keep = Array(routeable.routeablePath[0..<prefix.count])
            keep += Array(routeable.routeablePath[(prefix.count + path.count)..<routeable.routeablePath.count])

            print("KEEP: \(keep)")

            // create a new routeable item from the
            // fixed path
            let routeable = BasicRouteable(keep)
            guard let value = router.route(routeable, with: container) else {
                return nil
            }

            // optionally filter the value
            // this is useful for injecting middleware
            return filter(value)
        }

        add(path: template, handler: handler)
    }
}

extension Router: RouteBuilder {
    public typealias Value = Output

    public func add(path: [String], handler: RouteHandler<Value>) {
        register(path: path, output: handler)
        print(self)
    }
}
