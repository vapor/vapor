//import Async
//import Bits
//import Foundation
//
///// A Redis pipeline. Executes multiple commands in a single batch.
/////
///// [Learn More →](https://docs.vapor.codes/3.0/redis/pipeline/)
//public final class RedisPipeline {
//    /// The enqueued commands.
//    private var commands = [RedisData]()
//
//    /// The client we are pipelining to.
//    private var client: RedisClient
//
//    /// Creates a redis pipeline.
//    internal init(_ client: RedisClient) {
//        self.client = client
//    }
//
//    /// Enqueues a commands.
//    ///
//    /// [Learn More →](https://docs.vapor.codes/3.0/redis/pipeline/#enqueuing-commands)
//    @discardableResult
//    public func enqueue(command: String, arguments: [RedisData] = []) throws -> RedisPipeline {
//        commands.append(RedisData.array([.bulkString(command)] + arguments))
//        return self
//    }
//
//    /// Executes a series of commands and returns a future for the responses
//    ///
//    /// [Learn More →](https://docs.vapor.codes/3.0/redis/pipeline/#enqueuing-commands)
//    @discardableResult
//    public func execute() throws -> Future<[RedisData]> {
//        return then {
//            defer {
//                self.commands = []
//            }
//
//            guard !self.client.isSubscribed else {
//                throw RedisError(.cannotReuseSubscribedClients)
//            }
//
//            guard self.commands.count > 0 else {
//                throw RedisError(.pipelineCommandsRequired)
//            }
//
//            var promises = [Promise<RedisData>]()
//
//            for _ in 0 ..< self.commands.count {
//                let promise = Promise<RedisData>()
//                self.client.responseQueue.append(promise)
//                promises.append(promise)
//            }
//
//            self.client.dataSerializer.onInput(self.commands)
//
//            return promises.map { $0.future }
//                .flatten()
//        }
//    }

//}

///// Creates a pipeline and returns it.
//public func makePipeline() -> RedisPipeline {
//    return RedisPipeline(self)
//}

