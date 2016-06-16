public protocol HTTPParserProtocol {
    init(stream: Stream)
    func parse<MessageType: HTTP.Message>(_ type: MessageType.Type) throws -> MessageType
}
