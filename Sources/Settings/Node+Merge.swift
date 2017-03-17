extension Node {
    internal func merged(with sub: Node) -> Node? {
        guard let object = self.object, let value = sub.object else { return nil }
        var mutable = object
        mutable.merge(with: value)
        return .object(mutable)
    }
}
