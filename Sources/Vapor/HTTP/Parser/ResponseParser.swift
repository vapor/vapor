public protocol ResponseParser {
    init(stream: Stream)
    func parse() throws -> Response
}
