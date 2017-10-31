import Async
import Bits
import Foundation

/// A pipeline which wraps a redis client
public final class Pipeline<DuplexByteStream: Async.Stream> where DuplexByteStream.Input == ByteBuffer, DuplexByteStream.Output == ByteBuffer, DuplexByteStream: ClosableStream {
    
    public let client: RedisClient<DuplexByteStream>
    private var commands = [RedisData]()
    
    
    init(client: RedisClient<DuplexByteStream>) {
        self.client = client
    }
    
    /// Enqueues a command to be executed.  The commands will not be executed until execute() is
    /// is called
    @discardableResult
    public func enqueue(command: String, arguments: [RedisData]? = nil) throws -> Pipeline<DuplexByteStream> {
        if client.isSubscribed {
            throw RedisError(.cannotReuseSubscribedClients)
        }
        
        commands.append(RedisData.array([.bulkString(command)] + (arguments ?? [])))
        return self
    }
    
    /// Executes a series of commands and returns a future for the responses
    @discardableResult
    public func execute() throws -> Future<[RedisData]> {
        defer {
            commands = []
        }
        
        guard commands.count > 0 else {
            return Future(error: RedisError(.pipelineCommandsRequired))
        }
        
        let promises = commands.map { _ in
            Promise<RedisData>()
        }
        
        client.dataParser.responseQueue.append(contentsOf: promises)
        
        commands.forEach(client.dataSerializer.inputStream)
        
        return promises
            .map { $0.future }
            .flatten()
    }
    
}
