import Routing
import HTTP
import TypeSafeRouting

public final class Resource<Model: StringInitializable> {
    public typealias Multiple = (Request) throws -> HTTPResponseRepresentable
    public typealias Item = (Request, Model) throws -> HTTPResponseRepresentable

    public var index: Multiple?
    public var store: Multiple?
    public var show: Item?
    public var replace: Item?
    public var modify: Item?
    public var destroy: Item?
    public var clear: Multiple?
    public var aboutItem: Item?
    public var aboutMultiple: Multiple?

    public init(
        index: Multiple? = nil,
        store: Multiple? = nil,
        show: Item? = nil,
        replace: Item? = nil,
        modify: Item? = nil,
        destroy: Item? = nil,
        clear: Multiple? = nil,
        aboutItem: Item? = nil,
        aboutMultiple: Multiple? = nil
    ) {
        self.index = index
        self.store = store
        self.show = show
        self.replace = replace
        self.modify = modify
        self.destroy = destroy
        self.clear = clear
        self.aboutItem = aboutItem
        self.aboutMultiple = aboutMultiple
    }
}

public protocol ResourceRepresentable {
    associatedtype Model: StringInitializable
    func makeResource() -> Resource<Model>
}

extension RouteBuilder where Value == HTTPResponder {
    public func resource<Resource: ResourceRepresentable>(_ path: String, _ resource: Resource) {
        let resource = resource.makeResource()
        self.resource(path, resource)
    }

    public func resource<Model: StringInitializable>(_ path: String, _ resource: Resource<Model>) {
        var itemMethods: [HTTPMethod] = []
        var multipleMethods: [HTTPMethod] = []

        func item(_ method: HTTPMethod, _ item: Resource<Model>.Item?) {
            guard let item = item else {
                return
            }

            itemMethods += method

            self.add(method, path, ":id") { request in
                guard let id = request.parameters["id"] else {
                    throw Abort.notFound
                }

                guard let model = try Model(from: id) else {
                    throw Abort.notFound
                }

                return try item(request, model).makeResponse(for: request)
            }
        }

        func multiple(_ method: HTTPMethod, _ multiple: Resource<Model>.Multiple?) {
            guard let multiple = multiple else {
                return
            }

            multipleMethods += method

            self.add(method, path) { request in
                return try multiple(request).makeResponse(for: request)
            }

        }


        multiple(.get, resource.index)
        multiple(.post, resource.store)
        item(.get, resource.show)
        item(.put, resource.replace)
        item(.patch, resource.modify)
        item(.delete, resource.destroy)
        multiple(.delete, resource.clear)

        if let about = resource.aboutItem {
            item(.options, about)
        } else {
            item(.options) { request in
                return try JSON([
                    "resource": "\(path)/:id",
                    "methods": try JSON(itemMethods.map { $0.description })
                ])
            }
        }

        if let about = resource.aboutMultiple {
            multiple(.options, about)
        }else {
            multiple(.options) { request in
                return try JSON([
                    "resource": path,
                    "methods": try JSON(multipleMethods.map { $0.description })
                ])
            }
        }
    }

    public func resource<Model: StringInitializable>(
        _ path: String,
        _ type: Model.Type = Model.self,
        closure: (Resource<Model>) -> ()
    ) {
        let resource = Resource<Model>()
        closure(resource)
        self.resource(path, resource)
    }
}
