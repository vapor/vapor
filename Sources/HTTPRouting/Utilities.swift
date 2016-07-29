extension String {
    /**
        Separates a URI path into
        an array by splitting on `/`
    */
    var pathComponents: [String] {
        return characters
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { String($0) }
    }
}
