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
}

extension ConnectionPool {
    @discardableResult
    public func query(_ query: Query) throws -> Future<Void> {
        return try self.allRows(in: query).map { _ in
            return ()
        }
    }
}
