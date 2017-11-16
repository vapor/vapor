import Async
import Core

extension ConnectionPool {
    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each `Row`
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    internal func forEachRow(in query: Query, _ handler: @escaping ((Row) -> ())) -> Future<Void> {
        return retain { connection, complete, fail in
            // Set up a parser
            let stream = RowStream(mysql41: connection.mysql41)
            connection.receivePackets(into: stream.inputStream)
            
            stream.onClose = {
                complete(())
            }
            
            stream.errorStream = { error in
                fail(error)
            }
            
            stream.drain(handler).catch { error in
                // FIXME: @joannis
                fatalError("\(error)")
            }
            
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
    /// [For more information, see the documentation](https://docs.vapor.codes/3.0/mysql/basics/#foreach)
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D: Decodable>(_ type: D.Type, in query: Query, _ handler: @escaping ((D) -> ())) -> Future<Void> {
        return retain { connection, complete, fail in
            // Set up a parser
            let resultBuilder = ModelStream<D>(mysql41: connection.mysql41)
            connection.receivePackets(into: resultBuilder.inputStream)
            
            resultBuilder.onClose = {
                complete(())
            }
            
            resultBuilder.errorStream = { error in
                fail(error)
            }
            
            resultBuilder.drain(handler).catch { error in
                // FIXME: @joannis
                fatalError("\(error)")
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
