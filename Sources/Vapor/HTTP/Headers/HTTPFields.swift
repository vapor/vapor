import HTTPTypes

extension HTTPFields {
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
    
    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can access all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [HTTPMediaTypePreference] {
        self.parseDirectives(name: .accept).compactMap {
            HTTPMediaTypePreference(directives: $0)
        }
    }
}
