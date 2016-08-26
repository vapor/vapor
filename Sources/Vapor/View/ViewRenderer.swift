/**
    View renderers power the Droplet's
    `.view` property. 
 
    View renderers are responsible for loading
    the files paths given and caching if needed.
 
    View renderers are also responsible for 
    accepting a Node for templated responses.
*/
public protocol ViewRenderer {
    /**
        Create a re-usable view renderer
        with caching that will be based
        from the supplied directory.
    */
    init(viewsDir: String)

    /**
        Creates a view at the supplied path
        using a Node that is made optional
        by various protocol extensions.
    */
    func make(_ path: String, _ context: Node) throws -> View
}

extension ViewRenderer {
    public func make(_ path: String) throws -> View {
        return try make(path, Node.null)
    }

    public func make(_ path: String, _ context: NodeRepresentable) throws -> View {
        return try make(path, try context.makeNode())
    }
}
