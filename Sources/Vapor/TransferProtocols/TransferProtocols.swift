public protocol TransferMessage: class {}

public protocol TransferParser {
    associatedtype MessageType: TransferMessage
    init(stream: Stream)
    func parse() throws -> MessageType
}

public protocol TransferSerializer {
    associatedtype MessageType: TransferMessage
    init(stream: Stream)
    func serialize(_ message: MessageType) throws
}
