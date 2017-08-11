import Service
import Node

/// View renderers power the Droplet's
/// `.view` property.
///
/// View renderers are responsible for loading
/// the files paths given and caching if needed.
///
/// View renderers are also responsible for
/// accepting a Node for templated responses.
public protocol ViewRenderer: class {
    /// For view renderers that use a cache to
    /// optimize view loads, use this variable
    /// to toggle whether or not cache should be 
    /// implemented
    ///
    /// Normally, cache is disabled in development
    /// so views can be tested w/o recompilation.
    /// In production, cache is enabled to optimize 
    /// view serving speed.
    var shouldCache: Bool { get set }

    /// Creates a view at the supplied path
    /// using a Node that is made optional
    /// by various protocol extensions.
    func make(_ path: String, _ data: ViewData) throws -> View

    /// Creates a view at the supplied path
    /// using a Node that is made optional
    /// by various protocol extensions.
    /// DEPRECATED: Now uses ViewData constructor
    func make(_ path: String, _ context: Node) throws -> View
}

extension ViewRenderer {
    @available(
        *,
        deprecated: 2.1,
        message: "See ViewRenderer.swift for more info: Please implement this function in your 'ViewRenderer' and remove the deprecated `make(_ path: String, _ context: Node) throws -> View`"
    )
    public func make(_ path: String, _ data: ViewData) throws -> View {
        let node = Node(data)
        return try make(path, node)
    }

    @available(
        *,
        deprecated: 2.1,
        message: "Use `make(_ path: String, _ data: ViewData)` instead"
    )
    public func make(_ path: String, _ context: Node) throws -> View {
        print("[DEPRECATED] This function is deprecated, please use `make(_ path: String, _ data: ViewData)")
        let viewData = ViewData(context)
        return try make(path, viewData)
    }
}

// MARK: Convenience

extension ViewRenderer {
    public func make(
        _ path: String,
        _ data: NodeRepresentable? = nil,
        from provider: Provider.Type? = nil
    ) throws -> View {
        let viewData = try data.converted(to: ViewData.self, in: ViewData.defaultContext)
        let viewsDir = provider?.viewsDir ?? ""
        return try make(viewsDir + path, viewData)

    }

    public func make(
        _ path: String,
        from provider: Provider.Type? = nil,
        _ data: () throws -> ViewData
    ) throws -> View {
        let data = try data()
        let viewsDir = provider?.viewsDir ?? ""
        return try make(viewsDir + path, data)
    }
}

public struct ViewContext: Context {
    public static let shared = ViewContext()
}

extension Context {
    public var isViewContext: Bool {
        return self is ViewContext
    }
}
