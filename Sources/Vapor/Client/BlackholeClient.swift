import NIOCore

/// Type that conforms to `Client` but does nothing ahd throws an error when used. Can be useful for testing
/// Used when the `HTTPClient` package trait is disabled
public struct BlackholeClient: Client {
    public var byteBufferAllocator: ByteBufferAllocator
    public var contentConfiguration: ContentConfiguration
    public func send(_ request: ClientRequest) async throws -> ClientResponse {
        // Do nothing
        throw Abort(.notImplemented)
    }
}
