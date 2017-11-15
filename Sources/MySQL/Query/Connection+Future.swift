import Async
import Core

extension Connection {
    /// Collects all resulting rows and returs them in the future
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    internal func allRows(in query: Query) -> Future<[Row]> {
        var rows = [Row]()
        let promise = Promise<[Row]>()

        // Set up a parser
        let stream = RowStream(mysql41: self.mysql41)
        self.receivePackets(into: stream.inputStream)
        
        stream.onClose = {
            promise.complete(rows)
        }
        
        stream.errorStream = { error in
            promise.fail(error)
        }
        
        stream.drain { row in
            rows.append(row)
        }
        
        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
        
        return promise.future
    }
    
    /// Collects all decoded results and returs them in the future
    ///
    /// http://localhost:8000/mysql/basics/#futures
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    public func all<D: Decodable>(_ type: D.Type, in query: Query) -> Future<[D]> {
        var results = [D]()
        let promise = Promise<[D]>()

        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: self.mysql41)
        self.receivePackets(into: resultBuilder.inputStream)
        
        resultBuilder.onClose = {
            promise.complete(results)
        }
        
        resultBuilder.errorStream = { error in
            promise.fail(error)
        }
        
        resultBuilder.drain { result in
            results.append(result)
        }
        
        // Send the query
        do {
            try self.write(query: query.string)
        } catch {
            promise.fail(error)
        }
        
        return promise.future
    }
}
