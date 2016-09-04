import Leaf

public final class LeafRenderer: ViewRenderer {
    public let stem: Stem

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
