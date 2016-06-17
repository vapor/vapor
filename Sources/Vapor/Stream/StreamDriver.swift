public protocol StreamDriver {
    static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws
}
