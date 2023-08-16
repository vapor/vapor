import NIO

extension Request {
    public func serverSentEvents(
        produce: @escaping @Sendable (SSEStreamProducer) async throws -> ()
    ) async throws -> Response {
        let producer = SSEStreamProducer()
        let stream = AsyncThrowingStream { continuation in
            producer.continuation = continuation
        }
        let response = Response(headers: [
            "Content-Type": HTTPMediaType.eventStream.description
        ])
        response.body = Response.Body(managedAsyncStream: { writer in
            for try await event in stream {
                let buffer = event.makeBuffer(allocator: self.byteBufferAllocator)
                try await writer.writeBuffer(buffer)
            }
        })
        
        Task {
            do {
                try await produce(producer)
                producer.continuation?.finish()
            } catch {
                producer.continuation?.finish(throwing: error)
            }
        }
        
        return response
    }
}

public final class SSEStreamProducer {
    fileprivate var continuation: AsyncThrowingStream<SSEvent, Error>.Continuation!
    fileprivate init() {}
    
    @discardableResult
    public func sendEvent(_ event: SSEvent) async throws -> AsyncThrowingStream<SSEvent, Error>.Continuation.YieldResult {
        continuation!.yield(event)
    }
}
