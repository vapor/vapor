public protocol RequestParser {
    init(stream: Stream)
    func parse() throws -> Request
}
