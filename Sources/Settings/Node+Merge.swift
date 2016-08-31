extension Node {
    internal func merged(with sub: Node) -> Node? {
        guard let object = self.nodeObject, let value = sub.nodeObject else { return nil }
        var mutable = object
        mutable.merge(with: value)
        return .object(mutable)
    }
}
