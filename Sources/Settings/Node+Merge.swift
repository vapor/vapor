extension Node {
    internal func merged(with sub: Node) -> Node? {
        guard let object = self.typeObject, let value = sub.typeObject else { return nil }
        var mutable = object
        mutable.merge(with: value)
        return .object(mutable)
    }
}
