public protocol StreamDriver {
    static func make(host: String, port: Int) throws -> Self
    func start(handler: (Stream) throws -> ()) throws
}
