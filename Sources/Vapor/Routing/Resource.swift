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

/// Maintains the desired mapping for resource endpoints and their HTTP methods.
/// - Note: Setting the values with set() will define the behavior for all resources.
public final class ResourceMethodMap {
    private(set) static var index: Method = .get
    private(set) static var store: Method = .post
    private(set) static var show: Method = .get
    private(set) static var replace: Method = .put
    private(set) static var modify: Method = .patch
    private(set) static var destroy: Method = .delete
    private(set) static var clear: Method = .delete

    private init() { }

    /// Updates each endpoint mapping if a value is provided.
    public static func set(
        index: Method? = nil,
        store: Method? = nil,
        show: Method? = nil,
        replace: Method? = nil,
        modify: Method? = nil,
        destroy: Method? = nil,
        clear: Method? = nil
        ) {
        if let index = index { ResourceMethodMap.index = index }
        if let store = store { ResourceMethodMap.store = store }
        if let show = show { ResourceMethodMap.show = show }
        if let replace = replace { ResourceMethodMap.replace = replace }
        if let modify = modify { ResourceMethodMap.modify = modify }
        if let destroy = destroy { ResourceMethodMap.destroy = destroy }
        if let clear = clear { ResourceMethodMap.clear = clear }
    }
}

extension RouteBuilder where Value == Responder {
    public func resource<Resource: ResourceRepresentable>(_ path: String, _ resource: Resource) {
        let resource = resource.makeResource()
        self.resource(path, resource)
    }

    public func resource<Model: StringInitializable>(_ path: String, _ resource: Resource<Model>) {
        var itemMethods: [Method] = []
        var multipleMethods: [Method] = []

        let pathId = path.makeBytes().split(separator: .forwardSlash).joined(separator: [.hyphen]).split(separator: .colon).joined().string + "_id"

        func item(_ method: Method, _ item: Resource<Model>.Item?) {
            guard let item = item else {
                return
            }

            itemMethods += method

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

            multipleMethods += method

            self.add(method, path) { request in
                return try multiple(request).makeResponse()
            }

        }


        multiple(ResourceMethodMap.index, resource.index)
        multiple(ResourceMethodMap.store, resource.store)
        item(ResourceMethodMap.show, resource.show)
        item(ResourceMethodMap.replace, resource.replace)
        item(ResourceMethodMap.modify, resource.modify)
        item(ResourceMethodMap.destroy, resource.destroy)
        multiple(ResourceMethodMap.clear, resource.clear)

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
