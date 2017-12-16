import Async
import Bits
import Dispatch
import Foundation
import TCP

/// A Redis client
///
/// Wraps around the provided Connection/Closable Binary Stream
public final class RedisClient {
    /// Keeps track of whether this client is currently subscribed to a channel
    internal var isSubscribed = false

    /// Underlying redis data stream.
    private let stream: RedisDataStream

    /// Creates a new Redis client on the provided connection
    public init<ByteStream>(byteStream: ByteStream) where
        ByteStream: Async.Stream,
        ByteStream.Input == ByteBuffer,
        ByteStream.Output == ByteBuffer
    {
        stream = .init(byteStream: byteStream)
    }

    /// Runs a Value as a command
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/custom-commands/#usage)
    ///
    /// - returns: A future containing the server's response or the error
    public func run(command: String, arguments: [RedisData]? = nil) -> Future<RedisData> {
        if isSubscribed {
            return Future(error: RedisError(.cannotReuseSubscribedClients))
        }

        let arguments = arguments ?? []
        let command = RedisData.array([.bulkString(command)] + arguments)
        return stream.enqueue(request: command)
    }
}

extension RedisClient {
    /// Connects to `Redis` using on a TCP socket to the provided hostname and port
    ///
    /// Listens to the socket using the provided `DispatchQueue`
    public static func connect(
        hostname: String = "localhost",
        port: UInt16 = 6379,
        on eventLoop: EventLoop
    ) throws -> RedisClient {
        let socket = try TCPSocket(isNonBlocking: true)
        let client = try TCPClient(socket: socket)
        try client.connect(hostname: hostname, port: port)
        return RedisClient(byteStream: client.stream(on: eventLoop))
    }
}
