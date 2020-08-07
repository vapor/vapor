extension HTTPHeaders {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: HTTPMediaType? {
        get {
            self.parseDirectives(name: .contentType).first.flatMap {
                HTTPMediaType(directives: $0)
            }
        }
        set {
            if let new = newValue?.serialize() {
                self.replaceOrAdd(name: .contentType, value: new)
            } else {
                self.remove(name: .contentType)
            }
        }
    }
}
