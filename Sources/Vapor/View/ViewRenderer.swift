/// View renderers power the Droplet's
/// `.view` property.
///
/// View renderers are responsible for loading
/// the files paths given and caching if needed.
///
/// View renderers are also responsible for
/// accepting a Node for templated responses.
public protocol ViewRenderer: class {
    var shouldCache: Bool { get set }
    /// Creates a view at the supplied path
    /// using a Node that is made optional
    /// by various protocol extensions.
    func make(_ path: String, _ context: Node) throws -> View
}

// MARK: Convenience

extension ViewRenderer {
    public func make(
        _ path: String,
        _ context: NodeRepresentable? = nil,
        from provider: Provider.Type? = nil
    ) throws -> View {
        let context = try context?.makeNode(in: ViewContext.shared) ?? Node.null
        let viewsDir = provider?.viewsDir ?? ""
        return try make(viewsDir + path, context)
    }
}

public struct ViewContext: Context {
    public static let shared = ViewContext()
}
