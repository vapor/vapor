public protocol HTTPSerializerProtocol {
    init(stream: Stream)
    func serialize(_ message: HTTP.Message) throws
}
