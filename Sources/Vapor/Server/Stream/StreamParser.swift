public protocol StreamParser {
    init(stream: Stream)
    func parse() throws -> Request
}
