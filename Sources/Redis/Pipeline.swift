import Async
import Bits
import Foundation

/// A Redis pipeline. Executes multiple commands in a single batch.
///
/// [For more information, see the documentation](https://docs.vapor.codes/3.0/redis/pipeline/)
public final class Pipeline {
    var isSubscribed: () -> Bool
    var queuePromise: (Promise<RedisData>) -> ()
    
    let serializer: DataSerializer
    
    private var commands = [RedisData]()
    
    init<AnyStream>(_ client: RedisClient<AnyStream>) {
        self.serializer = client.dataSerializer
        
        isSubscribed = {
            return client.isSubscribed
        }
        
        queuePromise = { promise in
            client.dataParser.responseQueue.append(promise)
        }
    }
    
    /// Enqueues a commands.
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/redis/pipeline/#enqueuing-commands)
    @discardableResult
    public func enqueue(command: String, arguments: [RedisData] = []) throws -> Pipeline {
        commands.append(RedisData.array([.bulkString(command)] + arguments))
        return self
    }
    
    /// Executes a series of commands and returns a future for the responses
    ///
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/redis/pipeline/#enqueuing-commands)
    @discardableResult
    public func execute() throws -> Future<[RedisData]> {
        defer {
            commands = []
        }
        
        guard !isSubscribed() else {
             return Future(error: RedisError(.cannotReuseSubscribedClients))
        }
        
        guard commands.count > 0 else {
            return Future(error: RedisError(.pipelineCommandsRequired))
        }
        
        var promises = [Promise<RedisData>]()
        
        for _ in 0..<commands.count {
            let promise = Promise<RedisData>()
            
            queuePromise(promise)
            promises.append(promise)
        }
        
        serializer.inputStream(commands)
        
        return promises
            .map { $0.future }
            .flatten()
    }
}
