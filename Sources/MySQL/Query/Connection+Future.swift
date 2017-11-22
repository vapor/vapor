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
        self.packetStream.stream(to: stream)
        
        stream.drain { row in
            rows.append(row)
        }.catch { error in
            promise.fail(error)
        }.finally {
            promise.complete(rows)
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
    /// [Learn More →](https://docs.vapor.codes/3.0/mysql/basics/#futures)
    ///
    /// - parameter query: The query to be executed to receive results from
    /// - returns: A future containing all results
    public func all<D: Decodable>(_ type: D.Type, in query: Query) -> Future<[D]> {
        var results = [D]()
        let promise = Promise<[D]>()

        // Set up a parser
        let resultBuilder = ModelStream<D>(mysql41: self.mysql41)
        self.packetStream.stream(to: resultBuilder)
        
        resultBuilder.drain { result in
            results.append(result)
        }.catch { error in
            promise.fail(error)
        }.finally {
            promise.complete(results)
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
