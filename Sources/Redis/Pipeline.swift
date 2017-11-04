import Async
import Bits
import Foundation

final class Pipeline<DuplexByteStream: Async.Stream> where DuplexByteStream.Input == ByteBuffer, DuplexByteStream.Output == ByteBuffer, DuplexByteStream: ClosableStream {
    
    let client: RedisClient<DuplexByteStream>
    private var commands = [RedisData]()
    
    init(_ client:  RedisClient<DuplexByteStream>) {
        self.client = client
    }
    
    /// Enqueues a commands.
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
        
        if client.isSubscribed {
             return Future(error: RedisError(.cannotReuseSubscribedClients))
        }
        
        guard commands.count > 0 else {
            return Future(error: RedisError(.pipelineCommandsRequired))
        }
        
        let promises = commands.map { _ in
            Promise<RedisData>()
        }
        
        client.dataParser.responseQueue.append(contentsOf: promises)
        
        client.dataSerializer.inputStream(commands)
        
        return promises
            .map { $0.future }
            .flatten()
    }
    
}
