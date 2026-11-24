#if OpenAPI
extension String {
    /// Component keys must match `^[a-zA-Z0-9\.\-_]+$`, so anything else in user-provided
    /// parts (header names, bearer formats, link names) is replaced with `-`
    var componentKeySafe: String {
        String(map { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) ? $0 : "-" })
    }

    /// The string with its first character uppercased.
    var upFirst: String {
        guard !isEmpty else { return "" }
        return self[startIndex].uppercased() + dropFirst()
    }
}
#endif
