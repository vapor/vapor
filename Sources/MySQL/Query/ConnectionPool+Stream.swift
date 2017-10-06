import Async
import Core

extension ConnectionPool {
    /// Collects all resulting rows and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A stream of all resulting rows
    internal func streamRows(in query: Query) throws -> RowStream {
        let stream = RowStream(mysql41: true)
        
        let future = try retain { connection, complete, fail in
            // Set up a parser
            connection.receivePackets(into: stream.inputStream)
            
            stream.onClose = {
                complete(())
            }
            
            stream.errorStream = { error in
                fail(error)
            }
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        } as Future<Void>
        
        future.addAwaiter { result in
            switch result {
            case .error(let error):
                stream.errorStream?(error)
            case .expectation(_):
                stream.onClose?()
            }
        }
        
        return stream
    }
    
    /// Collects all decoded results and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A stream of all decoded resulting
    public func stream<D: Decodable>(_ type: D.Type, in query: Query) throws -> ModelStream<D> {
        let stream = ModelStream<D>(mysql41: true)
        
        let future = try retain { connection, complete, fail in
            // Set up a parser
            connection.receivePackets(into: stream.inputStream)
            
            stream.onClose = {
                complete(())
            }
            
            stream.errorStream = { error in
                fail(error)
            }
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        } as Future<Void>
        
        future.addAwaiter { result in
            switch result {
            case .error(let error):
                stream.errorStream?(error)
                stream.onClose?()
            case .expectation(_):
                stream.onClose?()
            }
        }
        
        return stream
    }
}


