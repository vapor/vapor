public protocol HTTPParserProtocol {
    init(stream: Stream)
    func parse<MessageType: HTTPMessage>(_ type: MessageType.Type) throws -> MessageType
}
