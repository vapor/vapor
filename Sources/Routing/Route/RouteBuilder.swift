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
        var template: [String] = []
        template += prefix
        template += path
        template += ["*"]

        let handler = RouteHandler<Value>.dynamic { routeable, container in
            let router: Router<Value> = Router()
            closure(router)

            var keep = Array(routeable.routeablePath[0..<prefix.count])
            keep += Array(routeable.routeablePath[(prefix.count + path.count)..<routeable.routeablePath.count])

            print(keep)

            let new = StaticRouteable(keep)

            guard let value = router.route(new, with: container) else {
                return nil
            }
            return filter(value)
        }

        add(path: template, handler: handler)
    }
}

extension Router: RouteBuilder {
    public typealias Value = Output

    public func add(path: [String], handler: RouteHandler<Value>) {
        print("Registering: \(path)")
        register(path: path, output: handler)
    }
}
