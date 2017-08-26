import Foundation
import Core

extension Connection {
    /// Writes a query to the connection
    ///
    /// Doesn't handle anything else
    internal func write(query: String) throws {
        var buffer = Data()
        buffer.reserveCapacity(query.utf8.count + 1)
        
        // SQL Query
        buffer.append(0x03)
        buffer.append(contentsOf: [UInt8](query.utf8))
        
        try self.write(packetFor: buffer)
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each Row
    func forEach(in query: Query, in handler: @escaping ((Row) -> ())) throws {
        // Set up a parser
        let resultBuilder = ResultsBuilder(connection: self)
        try self.reserve(receivingPacketsInto: resultBuilder.inputStream)

        resultBuilder.complete = {
            self.reserved = false
        }

        resultBuilder.errorStream = { error in
            self.reserved = false
        }

        resultBuilder.drain(handler)
        
        // Send the query
        try self.write(query: query.string)
    }
    
    /// Loops over all rows resulting from the query
    ///
    /// - parameter type: Deserializes all rows to the provided `Decodable` `D`
    /// - parameter query: Fetches results using this query
    /// - parameter handler: Executes the handler for each deserialized result
    public func forEach<D: Decodable>(_ type: D.Type, in query: Query, _ handler: @escaping ((D) -> ())) throws {
        // Set up a parser
        let resultBuilder = ModelBuilder<D>(connection: self)
        try self.reserve(receivingPacketsInto: resultBuilder.inputStream)
        
        resultBuilder.complete = {
            self.reserved = false
        }
        
        resultBuilder.errorStream = { error in
            self.reserved = false
        }
        
        resultBuilder.drain(handler)
        
        // Send the query
        try self.write(query: query.string)
    }
}
