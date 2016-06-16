public protocol HTTPMessage {
    var startLine: String { get }
    var headers: Headers { get }
    var body: HTTP.Body { get }

    init(startLineComponents: (BytesSlice, BytesSlice, BytesSlice), headers: Headers, body: HTTP.Body) throws
}