import Async
import Core

extension Connection {
    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each `Row`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    internal func forEachRow(in query: Query, _ handler: @escaping ((Row) -> ())) -> Future<Void> {
        let promise = Promise<Void>()
        
        let stream = RowStream(mysql41: self.mysql41)
        self.receivePackets(into: stream.inputStream)
        
        stream.onClose = {
            promise.complete(())
        }
        
        stream.errorStream = { error in
            promise.fail(error)
        }
        
        stream.drain(handler)
        
        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
        
        return promise.future
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D: Decodable>(_ type: D.Type, in query: Query, _ handler: @escaping ((D) -> ())) -> Future<Void> {
        let promise = Promise<Void>()
        
        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: self.mysql41)
        self.receivePackets(into: resultBuilder.inputStream)
        
        resultBuilder.onClose = {
            promise.complete(())
        }
        
        resultBuilder.errorStream = { error in
            promise.fail(error)
        }
        
        resultBuilder.drain(handler)
        
        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
        
        return promise.future
    }
}
