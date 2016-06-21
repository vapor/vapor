public protocol HTTPSerializerProtocol {
    init(stream: Stream)
    func serialize(_ message: HTTPMessage) throws
}
