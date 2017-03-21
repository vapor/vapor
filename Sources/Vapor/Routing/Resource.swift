import Routing
import HTTP
import TypeSafeRouting

public final class Resource<Model: StringInitializable> {
    public typealias Multiple = (Request) throws -> ResponseRepresentable
    public typealias Item = (Request, Model) throws -> ResponseRepresentable

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

extension RouteBuilder {
    public func resource<Resource: ResourceRepresentable>(_ path: String, _ resource: Resource) {
        let resource = resource.makeResource()
        self.resource(path, resource)
    }

    public func resource<Model: StringInitializable>(_ path: String, _ resource: Resource<Model>) {
        var itemMethods: [Method] = []
        var multipleMethods: [Method] = []

        let pathId = path.makeBytes().split(separator: .forwardSlash).joined(separator: [.hyphen]).split(separator: .colon).joined().makeString() + "_id"

        func item(_ method: Method, _ item: Resource<Model>.Item?) {
            guard let item = item else {
                return
            }

            itemMethods.append(method)

            self.add(method, path, ":\(pathId)") { request in
                guard let id = request.parameters["\(pathId)"]?.string else {
                    throw Abort.notFound
                }

                guard let model = try Model(from: id) else {
                    throw Abort.notFound
                }

                return try item(request, model).makeResponse()
            }
        }

        func multiple(_ method: Method, _ multiple: Resource<Model>.Multiple?) {
            guard let multiple = multiple else {
                return
            }

            multipleMethods.append(method)

            self.add(method, path) { request in
                return try multiple(request).makeResponse()
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
                return try JSON(node: [
                    "resource": "\(path)/:\(pathId)",
                    "methods": try JSON(node: itemMethods.map { $0.description })
                ])
            }
        }

        if let about = resource.aboutMultiple {
            multiple(.options, about)
        } else {
            multiple(.options) { request in
                let methods: [String] = multipleMethods.map { $0.description }
                return try JSON(node: [
                    "resource": path,
                    "methods": try JSON(node: methods)
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
