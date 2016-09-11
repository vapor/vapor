import Leaf

public final class LeafRenderer: ViewRenderer {
    public let stem: Stem
    
    public convenience init(viewsDir: String, localization: Localization? = nil) {
        self.init(viewsDir: viewsDir)
        localization.flatMap {
            stem.register(LocalizeTag(localization: $0))
        }
    }
    
    public init(viewsDir: String) {
        stem = Stem(workingDirectory: viewsDir)
    }

    public func make(_ path: String, _ context: Node) throws -> View {
        let leaf = try stem.spawnLeaf(named: path)
        let context = Context(context)
        let bytes = try stem.render(leaf, with: context)
        return View(data: bytes)
    }
}
