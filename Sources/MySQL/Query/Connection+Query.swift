import Async
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
    
    /// Writes a preparation message to the connection
    internal func prepare(query: String) throws {
        var buffer = Data()
        buffer.reserveCapacity(query.utf8.count + 1)
        
        // SQL Query
        buffer.append(0x16)
        buffer.append(contentsOf: [UInt8](query.utf8))
        
        try self.write(packetFor: buffer)
    }
}

extension ConnectionPool {
    @discardableResult
    internal func query(_ query: Query) -> Future<Void> {
        return retain { connection, complete, fail in
            do {
                connection.receivePackets { packet in
                    guard packet.payload.first == 0x00 else {
                        fail(MySQLError(packet: packet))
                        return
                    }
                    
                    complete(())
                }
                
                try connection.write(query: query.string)
            } catch {
                fail(error)
            }
        }
    }
}
