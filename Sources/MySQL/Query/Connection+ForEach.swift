import Async

extension MySQLConnection {
    /// A simple callback closure
    public typealias Callback<T> = (T) throws -> ()

    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each `Row`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    internal func forEachRow(in query: MySQLQuery, _ handler: @escaping Callback<Row>) -> Signal {
        let promise = Promise(Void.self)

        let rowStream = RowStream(mysql41: self.handshake.mysql41)
        
        parser.stream(to: rowStream).drain { connection in
            connection.request()
        }.output { row in
            try handler(row)
            rowStream.request()
        }.catch { error in
            promise.fail(error)
        }.finally {
            rowStream.cancel()
            promise.complete()
        }
        
        // Send the query
        do {
            try self.write(query: query.queryString)
        } catch {
            promise.fail(error)
        }
        
        return promise.future
    }
    
    public func stream<D, Stream>(_ type: D.Type, in query: MySQLQuery, to stream: Stream) throws
        where D: Decodable, Stream: InputStream, Stream.Input == D
    {
        let rowStream = RowStream(mysql41: self.handshake.mysql41)
        
        parser.stream(to: rowStream).map(to: D.self) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            return try D(from: decoder)
        }.output(to: stream)
        
        // Send the query
        try self.write(query: query.queryString)
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result of type `D`
    /// - throws: Network error
    /// - returns: A future that will be completed when all results have been processed by the handler
    @discardableResult
    public func forEach<D>(_ type: D.Type, in query: MySQLQuery, _ handler: @escaping Callback<D>) -> Future<Void>
        where D: Decodable
    {
        return forEachRow(in: query) { row in
            let decoder = try RowDecoder(keyed: row, lossyIntegers: true, lossyStrings: true)
            let d = try D(from: decoder)
            
            try handler(d)
        }
    }
}
