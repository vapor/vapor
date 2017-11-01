import Async
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
            let stream = RowStream(mysql41: connection.mysql41)
            connection.receivePackets(into: stream.inputStream)
            
            stream.onClose = {
                complete(rows)
            }
            
            stream.errorNotification.handleNotification(callback: fail)
            
            stream.drain { row in
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
            let resultBuilder = ModelStream<D>(mysql41: connection.mysql41)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.onClose = {
                complete(results)
            }
            
            resultBuilder.errorNotification.handleNotification(callback: fail)
            
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
