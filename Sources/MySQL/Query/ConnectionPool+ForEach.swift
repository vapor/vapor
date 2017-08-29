import Core

extension ConnectionPool {
    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each `Row`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    internal func forEachRow(in query: Query, _ handler: @escaping ((Row) -> ())) throws -> Future<Void> {
        return try retain { connection, complete, fail in
            // Set up a parser
            let resultBuilder = ResultsBuilder(connection: connection)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.complete = {
                complete(())
            }
            
            resultBuilder.errorStream = { error in
                complete(())
            }
            
            resultBuilder.drain(handler)
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        }
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D: Decodable>(_ type: D.Type, in query: Query, _ handler: @escaping ((D) -> ())) throws -> Future<Void> {
        return try retain { connection, complete, fail in
            // Set up a parser
            let resultBuilder = ModelBuilder<D>(connection: connection)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.complete = {
                complete(())
            }
            
            resultBuilder.errorStream = { error in
                fail(error)
            }
            
            resultBuilder.drain(handler)
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        }
    }
}
