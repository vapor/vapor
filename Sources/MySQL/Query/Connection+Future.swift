import Core

extension ConnectionPool {
    /// Collects all resulting rows and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A future containing all results
    internal func allRows(in query: Query) throws -> Future<[Row]> {
        var rows = [Row]()
        
        return try retain { connection, complete, fail in
            // Set up a parser
            let resultBuilder = ResultsBuilder(connection: connection)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.complete = {
                complete(rows)
            }
            
            resultBuilder.errorStream = { error in
                fail(error)
            }
            
            resultBuilder.drain { row in
                rows.append(row)
            }
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        }
    }
    
    /// Collects all decoded results and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - throws: Network error
    /// - returns: A future containing all results
    public func all<D: Decodable>(_ type: D.Type, in query: Query) throws -> Future<[D]> {
        var results = [D]()
        
        return try retain { connection, complete, fail in
            // Set up a parser
            let resultBuilder = ModelBuilder<D>(connection: connection)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.complete = {
                complete(results)
            }
            
            resultBuilder.errorStream = { error in
                fail(error)
            }
            
            resultBuilder.drain { result in
                results.append(result)
            }
            
            // Send the query
            do {
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        }
    }
}
