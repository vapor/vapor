extension HTTPHeaders {
    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can returns all `MediaType`s in this collection to check membership.
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
