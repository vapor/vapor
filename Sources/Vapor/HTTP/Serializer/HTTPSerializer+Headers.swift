extension Headers {
    mutating func appendHost(for uri: URI) {
        // TODO: Should this overwrite, or only if non-existant so user can customize if there's something we're not considering
        guard self["Host"] == nil else { return }
        self["Host"] = uri.host
    }
}
