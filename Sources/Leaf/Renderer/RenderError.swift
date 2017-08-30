public struct RenderError: Error {
    let source: Source
    let reason: String
    let error: Error?
    var path: String?

    init(source: Source, reason: String, error: Error? = nil, path: String? = nil) {
        self.source = source
        self.reason = reason
        self.error = error
        self.path = path
    }
}

extension RenderError: CustomStringConvertible {
    public var description: String {
        let file = path ?? "raw bytes"
        return "Leaf Error: \(reason) (source: \(file), line: \(source.line):\(source.column), range: \(source.range))"
    }
}
