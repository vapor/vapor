public protocol StreamDriver {
    @noreturn static func listen(host: String, port: Int, handler: (Stream) throws -> ()) throws
}
