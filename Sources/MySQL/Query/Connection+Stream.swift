import Async
import Core

extension Connection {
    /// Collects all resulting rows and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A stream of all resulting rows
    internal func streamRows(in query: Query) -> RowStream {
        let stream = RowStream(mysql41: true)
        let promise = Promise<Void>()
        
        // Set up a parser
        self.packetStream.stream(to: stream)

        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
    
        promise.future.addAwaiter { result in
            if let error = result.error {
                stream.onError(error)
            }
            
            stream.close()
        }
        
        return stream
    }
    
    /// Collects all decoded results and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A stream of all decoded resulting
    public func stream<D: Decodable>(_ type: D.Type, in query: Query) -> ModelStream<D> {
        let stream = ModelStream<D>(mysql41: true)
        let promise = Promise<Void>()
        
        // Set up a parser
        self.packetStream.stream(to: stream)
        stream.finally {
            promise.complete()
        }
        
        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
        
        promise.future.addAwaiter { result in
            if let error = result.error {
                stream.onError(error)
            }
            
            stream.close()
        }
        
        return stream
    }
}


